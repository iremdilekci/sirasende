from uuid import UUID
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import AdminUser
from app.core.exceptions import AmbiguousIdentifierError


async def get_admin_user_by_id(session: AsyncSession, user_id: UUID) -> AdminUser | None:
    """Retrieve an AdminUser by database UUID primary key."""
    stmt = select(AdminUser).where(AdminUser.id == user_id)
    return await session.scalar(stmt)


async def get_admin_user_by_username(session: AsyncSession, username: str) -> AdminUser | None:
    """Retrieve an AdminUser by username (exact case-sensitive match)."""
    stmt = select(AdminUser).where(AdminUser.username == username)
    return await session.scalar(stmt)


async def get_admin_user_by_email(session: AsyncSession, email: str) -> AdminUser | None:
    """Retrieve an AdminUser by email (exact case-sensitive match)."""
    stmt = select(AdminUser).where(AdminUser.email == email)
    return await session.scalar(stmt)


async def get_admin_user_by_identifier(session: AsyncSession, identifier: str) -> AdminUser | None:
    """Retrieve an AdminUser matching either username or email exactly.

    If multiple matches are found, AmbiguousIdentifierError is raised.
    """
    stmt = (
        select(AdminUser)
        .where(
            or_(
                AdminUser.username == identifier,
                AdminUser.email == identifier,
            )
        )
        .limit(2)
    )
    result = await session.execute(stmt)
    users = result.scalars().all()

    if len(users) > 1:
        raise AmbiguousIdentifierError("Multiple matches found for the given identifier.")

    return users[0] if users else None

