from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_admin, get_db, raise_credentials_exception
from app.core.exceptions import InvalidCredentialsError, RegistrationConflictError
from app.models import AdminUser
from app.schemas.auth import (
    AdminUserOut,
    LoginRequest,
    TokenResponse,
    AdminRegistrationRequest,
    AdminRegistrationResponse,
)
from app.services.auth_service import authenticate_admin, register_business_and_admin

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


@router.post(
    "/register",
    response_model=AdminRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new business and admin user",
    responses={
        201: {"description": "Successful registration."},
        409: {"description": "Conflict: Username or email already exists."},
        422: {"description": "Validation error (invalid format, etc.)."},
    },
)
async def register(
    payload: AdminRegistrationRequest,
    db: AsyncSession = Depends(get_db),
) -> AdminRegistrationResponse:
    """Register a new business and its associated admin user in a single transaction."""
    try:
        return await register_business_and_admin(session=db, payload=payload)
    except RegistrationConflictError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )
