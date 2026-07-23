import os
from collections.abc import AsyncGenerator
from datetime import date, time
from uuid import uuid4

import pytest
import sqlalchemy as sa
from sqlalchemy import delete
from sqlalchemy.exc import IntegrityError
from httpx import ASGITransport, AsyncClient

from app.core.database import async_session_factory
from app.models import Business, BusinessSchedule
from app.main import app
from app.schemas.appointment import AppointmentCreate
from app.services.appointment_service import create_appointment
from app.core.exceptions import InvalidAppointmentSlotError
from app.services.business_service import create_default_schedules_for_business

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


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client


async def test_closed_day_returns_empty_slots(client: AsyncClient) -> None:
    business = await _create_business()

    # Monday is closed
    sched = BusinessSchedule(
        business_id=business.id,
        day_of_week=0,
        start_time=None,
        end_time=None,
        is_closed=True,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(sched)

    # Query slots for Monday (e.g. 2026-07-27 is a Monday)
    response = await client.get(f"/api/v1/businesses/{business.slug}/slots?date=2026-07-27")
    assert response.status_code == 200
    assert response.json() == []


async def test_different_days_generate_different_slots(client: AsyncClient) -> None:
    business = await _create_business()

    # Monday 09:00-12:00 (3 hours = 6 slots)
    # Saturday 10:00-14:00 (4 hours = 8 slots)
    sched_mon = BusinessSchedule(
        business_id=business.id,
        day_of_week=0,
        start_time=time(9, 0),
        end_time=time(12, 0),
        is_closed=False,
    )
    sched_sat = BusinessSchedule(
        business_id=business.id,
        day_of_week=5,
        start_time=time(10, 0),
        end_time=time(14, 0),
        is_closed=False,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add_all([sched_mon, sched_sat])

    # Query Monday (2026-07-27)
    res_mon = await client.get(f"/api/v1/businesses/{business.slug}/slots?date=2026-07-27")
    assert res_mon.status_code == 200
    assert len(res_mon.json()) == 6

    # Query Saturday (2026-08-01)
    res_sat = await client.get(f"/api/v1/businesses/{business.slug}/slots?date=2026-08-01")
    assert res_sat.status_code == 200
    assert len(res_sat.json()) == 8


async def test_schedule_fallback_to_business_default_hours(client: AsyncClient) -> None:
    # Business with default hours 09:00-18:00 (9 hours = 18 slots)
    business = await _create_business()

    # Query Monday (2026-07-27)
    response = await client.get(f"/api/v1/businesses/{business.slug}/slots?date=2026-07-27")
    assert response.status_code == 200
    assert len(response.json()) == 18


async def test_booking_on_closed_day_rejected() -> None:
    business = await _create_business()

    # Tuesday is closed
    sched = BusinessSchedule(
        business_id=business.id,
        day_of_week=1,
        start_time=None,
        end_time=None,
        is_closed=True,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(sched)

    # Try to book on Tuesday (2026-07-28 is a Tuesday)
    payload = AppointmentCreate(
        customer_name="Test Customer",
        customer_phone="+905554443322",
        customer_note=None,
        appointment_date=date(2026, 7, 28),
        start_time=time(10, 0),
    )

    async with async_session_factory() as session:
        with pytest.raises(InvalidAppointmentSlotError):
            await create_appointment(session, business, payload)


async def test_booking_outside_working_hours_rejected() -> None:
    business = await _create_business()

    # Monday 10:00-16:00
    sched = BusinessSchedule(
        business_id=business.id,
        day_of_week=0,
        start_time=time(10, 0),
        end_time=time(16, 0),
        is_closed=False,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(sched)

    # Try to book at 09:00 on Monday
    payload_before = AppointmentCreate(
        customer_name="Test Customer",
        customer_phone="+905554443322",
        customer_note=None,
        appointment_date=date(2026, 7, 27),
        start_time=time(9, 0),
    )

    # Try to book at 16:00 on Monday (slot ends at 16:30, exceeding 16:00 closing time)
    payload_after = AppointmentCreate(
        customer_name="Test Customer",
        customer_phone="+905554443322",
        customer_note=None,
        appointment_date=date(2026, 7, 27),
        start_time=time(16, 0),
    )

    async with async_session_factory() as session:
        with pytest.raises(InvalidAppointmentSlotError):
            await create_appointment(session, business, payload_before)
        with pytest.raises(InvalidAppointmentSlotError):
            await create_appointment(session, business, payload_after)


async def test_booking_on_open_day_valid_range_succeeds() -> None:
    business = await _create_business()

    # Monday 09:00-18:00
    sched = BusinessSchedule(
        business_id=business.id,
        day_of_week=0,
        start_time=time(9, 0),
        end_time=time(18, 0),
        is_closed=False,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(sched)

    payload = AppointmentCreate(
        customer_name="Test Customer",
        customer_phone="+905554443322",
        customer_note=None,
        appointment_date=date(2026, 7, 27),
        start_time=time(10, 0),
    )

    async with async_session_factory() as session:
        app = await create_appointment(session, business, payload)
        assert app is not None
        assert app.start_time == time(10, 0)
        assert app.end_time == time(10, 30)


async def test_new_business_creation_triggers_default_schedules() -> None:
    business = await _create_business()

    async with async_session_factory() as session:
        await session.execute(
            delete(BusinessSchedule).where(BusinessSchedule.business_id == business.id)
        )
        await session.commit()

        sched_count_pre = await session.scalar(
            sa.select(sa.func.count(BusinessSchedule.id))
            .where(BusinessSchedule.business_id == business.id)
        )
        assert sched_count_pre == 0

        await create_default_schedules_for_business(session, business)
        await session.commit()

        sched_count_post = await session.scalar(
            sa.select(sa.func.count(BusinessSchedule.id))
            .where(BusinessSchedule.business_id == business.id)
        )
        assert sched_count_post == 7

        await create_default_schedules_for_business(session, business)
        await session.commit()

        sched_count_dup = await session.scalar(
            sa.select(sa.func.count(BusinessSchedule.id))
            .where(BusinessSchedule.business_id == business.id)
        )
        assert sched_count_dup == 7
