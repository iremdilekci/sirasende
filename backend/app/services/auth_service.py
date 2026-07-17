from datetime import timedelta
from typing import TypedDict
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.exceptions import InvalidCredentialsError, AmbiguousIdentifierError
from app.core.security import verify_password, create_access_token, hash_password
from app.repositories.admin_user_repository import get_admin_user_by_identifier
from app.core.config import settings

# Dummy hash generated once at module load to prevent timing attacks when user is not found
DUMMY_PASSWORD_HASH = hash_password("dummy_password_value")


class AuthenticationResult(TypedDict):
    access_token: str
    token_type: str
    expires_in: int


async def authenticate_admin(
    session: AsyncSession,
    identifier: str,
    password: str,
) -> AuthenticationResult:
    """Authenticate an admin user by identifier (username or email) and password, generating a JWT access token.

    Throws:
        InvalidCredentialsError: If credentials do not match, user is inactive, or identifier is ambiguous.
    """
    try:
        user = await get_admin_user_by_identifier(session, identifier)
    except AmbiguousIdentifierError:
        # Run dummy verification to prevent timing analysis on ambiguous identifier crossover
        verify_password(password, DUMMY_PASSWORD_HASH)
        raise InvalidCredentialsError("Invalid username/email or password")

    if user is None:
        # Run dummy verification to prevent timing analysis on non-existent users
        verify_password(password, DUMMY_PASSWORD_HASH)
        raise InvalidCredentialsError("Invalid username/email or password")

    password_valid = verify_password(password, user.password_hash)

    if not password_valid:
        raise InvalidCredentialsError("Invalid username/email or password")

    if not user.is_active:
        raise InvalidCredentialsError("Invalid username/email or password")

    expires_delta = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    access_token = create_access_token(user.id, expires_delta=expires_delta)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "expires_in": settings.jwt_access_token_expire_minutes * 60,
    }

