import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Business, BusinessSchedule


async def create_default_schedules_for_business(
    session: AsyncSession,
    business: Business,
) -> None:
    """Create default 7-day schedule (Monday-Sunday, 0-6) for a Business if they don't already exist."""
    # Check if any schedule already exists to prevent duplicates
    existing_exists = await session.scalar(
        select(BusinessSchedule.id)
        .where(BusinessSchedule.business_id == business.id)
        .limit(1)
    )
    if existing_exists is not None:
        return

    schedules = []
    for day in range(7):
        schedules.append(
            BusinessSchedule(
                id=uuid.uuid4(),
                business_id=business.id,
                day_of_week=day,
                start_time=business.working_start_time,
                end_time=business.working_end_time,
                is_closed=False,
            )
        )
    session.add_all(schedules)
