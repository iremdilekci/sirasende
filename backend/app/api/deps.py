from uuid import UUID
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session as get_db
from app.core.exceptions import InvalidTokenError
from app.core.security import decode_access_token
from app.models import AdminUser
from app.repositories.admin_user_repository import get_admin_user_by_id

security_scheme = HTTPBearer(auto_error=False)


def raise_credentials_exception() -> None:
    """Raise a generic 401 Unauthorized exception to prevent info disclosure."""
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(security_scheme),
    db: AsyncSession = Depends(get_db),
) -> AdminUser:
    """Read Bearer token from header, validate it, and return the authenticated active AdminUser ORM model."""
    if not credentials:
        raise_credentials_exception()

    if credentials.scheme.lower() != "bearer":
        raise_credentials_exception()

    token = credentials.credentials
    if not token or not token.strip():
        raise_credentials_exception()

    try:
        payload = decode_access_token(token)
    except InvalidTokenError:
        raise_credentials_exception()

    sub_str = payload.get("sub")
    try:
        user_id = UUID(sub_str)
    except (ValueError, TypeError):
        raise_credentials_exception()

    user = await get_admin_user_by_id(db, user_id)
    if not user:
        raise_credentials_exception()

    if not user.is_active:
        raise_credentials_exception()

    return user


async def get_current_active_business_admin(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminUser:
    """Verify that the authenticated AdminUser is linked to an active Business.

    Raises a 403 Forbidden if the associated Business does not exist or is inactive.
    """
    from app.repositories.business_repository import get_business_by_id

    business = await get_business_by_id(db, current_admin.business_id)
    if business is None or not business.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Business access is inactive",
        )
    return current_admin


__all__ = ["get_db", "get_current_admin", "get_current_active_business_admin", "raise_credentials_exception"]
