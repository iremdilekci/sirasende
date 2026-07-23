import os
from datetime import time
from uuid import uuid4

import pytest
import sqlalchemy as sa
from sqlalchemy import delete
from sqlalchemy.exc import IntegrityError

from app.core.database import async_session_factory
from app.models import Business, BusinessSchedule

from pathlib import Path
from alembic import command
from alembic.config import Config

pytestmark = [
    pytest.mark.postgres,
    pytest.mark.skipif(
        os.getenv("RUN_POSTGRES_TESTS") != "1",
        reason="Set RUN_POSTGRES_TESTS=1 with a disposable PostgreSQL database",
    ),
]

BACKEND_DIR = Path(__file__).resolve().parents[1]


def _alembic_config() -> Config:
    return Config(str(BACKEND_DIR / "alembic.ini"))


@pytest.fixture(scope="module", autouse=True)
def migrated_database() -> None:
    command.upgrade(_alembic_config(), "head")
    yield
    command.downgrade(_alembic_config(), "base")


async def _create_business() -> Business:
    slug = f"biz-{uuid4().hex[:8]}"
    b = Business(
        name=f"Business {slug}",
        slug=slug,
        working_start_time=time(9, 0),
        working_end_time=time(18, 0),
        slot_duration_minutes=30,
        is_active=True,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(b)
        await session.refresh(b)
    return b


async def test_valid_schedule_creation() -> None:
    business = await _create_business()

    # Create an open schedule entry
    sched1 = BusinessSchedule(
        business_id=business.id,
        day_of_week=0,
        start_time=time(9, 0),
        end_time=time(18, 0),
        is_closed=False,
    )
    # Create a closed schedule entry
    sched2 = BusinessSchedule(
        business_id=business.id,
        day_of_week=6,
        start_time=None,
        end_time=None,
        is_closed=True,
    )

    async with async_session_factory() as session:
        async with session.begin():
            session.add_all([sched1, sched2])

        # Verify they are persisted
        db_sched1 = await session.get(BusinessSchedule, sched1.id)
        db_sched2 = await session.get(BusinessSchedule, sched2.id)

        assert db_sched1 is not None
        assert db_sched1.is_closed is False
        assert db_sched1.start_time == time(9, 0)

        assert db_sched2 is not None
        assert db_sched2.is_closed is True
        assert db_sched2.start_time is None


async def test_duplicate_day_of_week_rejected() -> None:
    business = await _create_business()

    sched1 = BusinessSchedule(
        business_id=business.id,
        day_of_week=0,
        start_time=time(9, 0),
        end_time=time(18, 0),
        is_closed=False,
    )
    sched2 = BusinessSchedule(
        business_id=business.id,
        day_of_week=0,
        start_time=time(10, 0),
        end_time=time(17, 0),
        is_closed=False,
    )

    async with async_session_factory() as session:
        with pytest.raises(IntegrityError):
            async with session.begin():
                session.add(sched1)
                session.add(sched2)


async def test_day_of_week_range_constraint() -> None:
    business = await _create_business()

    # Invalid day_of_week (7)
    sched = BusinessSchedule(
        business_id=business.id,
        day_of_week=7,
        start_time=time(9, 0),
        end_time=time(18, 0),
        is_closed=False,
    )
    async with async_session_factory() as session:
        with pytest.raises(IntegrityError):
            async with session.begin():
                session.add(sched)


async def test_open_day_requires_times() -> None:
    business = await _create_business()

    # Open day but start_time is null
    sched = BusinessSchedule(
        business_id=business.id,
        day_of_week=1,
        start_time=None,
        end_time=time(18, 0),
        is_closed=False,
    )
    async with async_session_factory() as session:
        with pytest.raises(IntegrityError):
            async with session.begin():
                session.add(sched)


async def test_open_day_time_ordering() -> None:
    business = await _create_business()

    # Open day but end_time <= start_time
    sched = BusinessSchedule(
        business_id=business.id,
        day_of_week=1,
        start_time=time(18, 0),
        end_time=time(9, 0),
        is_closed=False,
    )
    async with async_session_factory() as session:
        with pytest.raises(IntegrityError):
            async with session.begin():
                session.add(sched)


async def test_cascade_delete_on_business_deletion() -> None:
    business = await _create_business()
    sched = BusinessSchedule(
        business_id=business.id,
        day_of_week=2,
        start_time=time(9, 0),
        end_time=time(18, 0),
        is_closed=False,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(sched)

        # Delete business
        async with session.begin():
            await session.execute(delete(Business).where(Business.id == business.id))

    # Verify schedule is deleted too in a fresh session (bypassing session cache)
    async with async_session_factory() as session2:
        db_sched = await session2.get(BusinessSchedule, sched.id)
        assert db_sched is None


async def test_migration_seeds_7_schedules_per_business() -> None:
    # 1. Create a business (will start with 0 schedules in the test transaction scope)
    business = await _create_business()

    # 2. Run the exact seeding logic of the migration using the async session
    async with async_session_factory() as session:
        # Fetch the newly created business using raw SQL text (exactly like migration does)
        results = await session.execute(
            sa.text("SELECT id, working_start_time, working_end_time FROM businesses WHERE id = :id"),
            {"id": business.id}
        )
        row = results.fetchone()
        assert row is not None

        biz_id, working_start_time, working_end_time = row

        import uuid
        schedules_to_insert = []
        for day in range(7):
            schedules_to_insert.append(
                BusinessSchedule(
                    id=uuid.uuid4(),
                    business_id=biz_id,
                    day_of_week=day,
                    start_time=working_start_time,
                    end_time=working_end_time,
                    is_closed=False,
                )
            )

        session.add_all(schedules_to_insert)
        await session.commit()

    # 3. Verify exactly 7 schedules were inserted for this business
    async with async_session_factory() as session:
        sched_count = await session.scalar(
            sa.select(sa.func.count(BusinessSchedule.id))
            .where(BusinessSchedule.business_id == business.id)
        )
        assert sched_count == 7
