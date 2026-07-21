from collections.abc import Sequence
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Business


async def list_active_businesses(session: AsyncSession) -> Sequence[Business]:
    stmt = select(Business).where(Business.is_active == True).order_by(Business.name)
    result = await session.scalars(stmt)
    return result.all()


async def get_active_business_by_slug(
    session: AsyncSession,
    slug: str,
) -> Business | None:
    stmt = select(Business).where(Business.slug == slug, Business.is_active == True)
    return await session.scalar(stmt)


async def get_business_by_id(
    session: AsyncSession,
    business_id: UUID,
) -> Business | None:
    """Retrieve a Business instance by id regardless of active status."""
    stmt = select(Business).where(Business.id == business_id)
    return await session.scalar(stmt)
