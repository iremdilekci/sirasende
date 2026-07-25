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


def generate_slug(text: str) -> str:
    import re
    mapping = {
        "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u",
        "Ç": "c", "Ğ": "g", "İ": "i", "Ö": "o", "Ş": "s", "Ü": "u"
    }
    for search, replace in mapping.items():
        text = text.replace(search, replace)
    text = text.lower()
    text = re.sub(r'[^a-z0-9\s-]', '', text)
    text = re.sub(r'[\s-]+', '-', text).strip('-')
    return text


async def get_unique_slug(session: AsyncSession, name: str) -> str:
    from sqlalchemy import select
    from app.models import Business
    from app.core.exceptions import RegistrationConflictError
    
    base_slug = generate_slug(name)
    if not base_slug:
        base_slug = "isletme"
    
    slug = base_slug
    counter = 1
    for _ in range(100):
        stmt = select(Business.id).where(Business.slug == slug)
        exists = await session.scalar(stmt)
        if exists is None:
            return slug
        slug = f"{base_slug}-{counter}"
        counter += 1
    raise RegistrationConflictError("Unique slug could not be generated.")


async def register_business_and_admin(
    session: AsyncSession,
    payload: "AdminRegistrationRequest",
) -> "AdminRegistrationResponse":
    import uuid
    from datetime import time
    from sqlalchemy import select, func
    from sqlalchemy.exc import IntegrityError
    from app.core.exceptions import RegistrationConflictError
    from app.models import Business, AdminUser
    from app.schemas.auth import AdminRegistrationRequest, AdminRegistrationResponse
    from app.services.business_service import create_default_schedules_for_business

    try:
        username_lower = payload.username.strip().lower()
        email_lower = payload.email.strip().lower()
        
        # Check case-insensitive username duplication
        stmt_username = select(AdminUser).where(func.lower(AdminUser.username) == username_lower)
        existing_username = await session.scalar(stmt_username)
        if existing_username is not None:
            raise RegistrationConflictError("Bu kullanıcı adı zaten alınmış.")
            
        # Check case-insensitive email duplication
        stmt_email = select(AdminUser).where(func.lower(AdminUser.email) == email_lower)
        existing_email = await session.scalar(stmt_email)
        if existing_email is not None:
            raise RegistrationConflictError("Bu e-posta adresi zaten alınmış.")

        # Generate unique slug
        slug = await get_unique_slug(session, payload.business_name)

        business = Business(
            id=uuid.uuid4(),
            name=payload.business_name.strip(),
            slug=slug,
            phone=payload.phone.strip() if payload.phone else None,
            address=payload.address.strip() if payload.address else None,
            description=payload.description.strip() if payload.description else None,
            working_start_time=time(9, 0),
            working_end_time=time(18, 0),
            slot_duration_minutes=payload.slot_duration_minutes,
            is_active=True,
        )
        session.add(business)
        
        # Create schedules
        await create_default_schedules_for_business(session, business)

        # Hash password and create admin user
        password_hash = hash_password(payload.password)
        admin_user = AdminUser(
            id=uuid.uuid4(),
            business_id=business.id,
            username=payload.username.strip(),
            email=payload.email.strip(),
            password_hash=password_hash,
            is_active=True,
        )
        session.add(admin_user)

        await session.flush()
        await session.commit()
        
        return AdminRegistrationResponse(
            admin_id=admin_user.id,
            business_id=business.id,
            username=admin_user.username,
            email=admin_user.email,
            business_name=business.name,
            message="Kayıt işleminiz başarıyla tamamlandı. Giriş yapabilirsiniz."
        )
    except IntegrityError as ie:
        await session.rollback()
        raise RegistrationConflictError("Kullanıcı adı, e-posta veya işletme adı çakışması nedeniyle kayıt başarısız.")
    except Exception:
        await session.rollback()
        raise

