from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession
import urllib.parse

from app.api.deps import get_current_admin, get_db
from app.core.config import settings
from app.models.admin_user import AdminUser
from app.schemas.google_calendar import (
    GoogleCalendarConnectionStatusResponse,
    GoogleCalendarConnectResponse,
)
from app.services.google_oauth import GoogleOAuthService

router = APIRouter(prefix="/admin/google-calendar", tags=["google_calendar"])


@router.get(
    "/status",
    response_model=GoogleCalendarConnectionStatusResponse,
    summary="Get current business's Google Calendar connection status",
)
async def get_connection_status(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> GoogleCalendarConnectionStatusResponse:
    if not current_admin.business_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin is not associated with any business",
        )

    conn = await GoogleOAuthService.get_connection_status(db, current_admin.business_id)
    if conn:
        return GoogleCalendarConnectionStatusResponse(
            connected=True,
            google_account_email=conn.google_account_email,
            connected_at=conn.created_at,
            granted_scopes=conn.granted_scopes,
        )
    return GoogleCalendarConnectionStatusResponse(connected=False)


@router.post(
    "/connect",
    response_model=GoogleCalendarConnectResponse,
    summary="Generate Google OAuth authorization URL",
)
async def connect(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> GoogleCalendarConnectResponse:
    if not current_admin.business_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin is not associated with any business",
        )

    try:
        auth_url = await GoogleOAuthService.create_auth_url(db, current_admin.business_id)
        return GoogleCalendarConnectResponse(authorization_url=auth_url)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get(
    "/callback",
    summary="Google OAuth callback handler",
)
async def callback(
    code: str = Query(...),
    state: str = Query(...),
    db: AsyncSession = Depends(get_db),
) -> RedirectResponse:
    try:
        await GoogleOAuthService.handle_callback(db, state_token=state, code=code)
        # Success Redirect
        redirect_url = settings.google_oauth_success_redirect_uri or "sirasende://google-calendar/callback?status=success"
        return RedirectResponse(url=redirect_url)
    except ValueError as e:
        # Failure Redirect
        redirect_url = settings.google_oauth_failure_redirect_uri or "sirasende://google-calendar/callback?status=failure"
        # We can append error query parameter to help client understand
        if "?" in redirect_url:
            redirect_url += f"&error={urllib.parse.quote(str(e))}" if "urllib" in globals() else f"&error={str(e)}"
        else:
            redirect_url += f"?error={str(e)}"
        return RedirectResponse(url=redirect_url)
    except Exception as e:
        # Fallback redirect on general errors
        redirect_url = settings.google_oauth_failure_redirect_uri or "sirasende://google-calendar/callback?status=failure"
        return RedirectResponse(url=redirect_url)


@router.delete(
    "/connection",
    summary="Disconnect Google Calendar connection",
)
async def disconnect(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if not current_admin.business_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin is not associated with any business",
        )

    disconnected = await GoogleOAuthService.disconnect(db, current_admin.business_id)
    if not disconnected:
        # Idempotent behavior: if there was no connection, return success anyway
        return {"message": "Google Takvim bağlantısı zaten bulunmamaktadır."}

    return {"message": "Google Takvim bağlantısı başarıyla kaldırıldı."}
