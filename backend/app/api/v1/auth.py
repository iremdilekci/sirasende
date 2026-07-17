from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_admin, get_db, raise_credentials_exception
from app.core.exceptions import InvalidCredentialsError
from app.models import AdminUser
from app.schemas.auth import AdminUserOut, LoginRequest, TokenResponse
from app.services.auth_service import authenticate_admin

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Login to obtain a JWT access token",
    responses={
        200: {"description": "Successful login."},
        401: {"description": "Invalid credentials or inactive user."},
        422: {"description": "Validation error (invalid format, etc.)."},
    },
)
async def login(
    payload: LoginRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Authenticate admin and return JWT access token."""
    try:
        result = await authenticate_admin(
            session=db,
            identifier=payload.identifier,
            password=payload.password,
        )
        return TokenResponse(**result)
    except InvalidCredentialsError:
        raise_credentials_exception()


@router.get(
    "/me",
    response_model=AdminUserOut,
    summary="Get current admin user details",
    responses={
        200: {"description": "Success returning current user profile."},
        401: {"description": "Not authenticated or invalid token."},
    },
)
async def get_me(
    current_admin: AdminUser = Depends(get_current_admin),
) -> AdminUserOut:
    """Return the profile of the currently authenticated admin user."""
    return current_admin
