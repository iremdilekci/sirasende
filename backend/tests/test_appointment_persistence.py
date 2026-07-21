from datetime import date, datetime, time
import os
from pathlib import Path
from typing import Any
from uuid import UUID

from alembic import command
from alembic.config import Config
import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.core.database import async_session_factory
from app.core.exceptions import AppointmentConflictError
from app.models import Appointment, AppointmentStatus, Business
from app.repositories.appointment_repository import (
    add_appointment,
    get_active_appointment_for_slot,
)
from app.schemas.appointment import AppointmentCreate
from app.services.appointment_service import create_appointment
from app.services.slot_service import ISTANBUL_TIMEZONE


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
    try:
        command.downgrade(_alembic_config(), "base")
    except Exception:
        pass
    command.upgrade(_alembic_config(), "head")
    yield
    command.downgrade(_alembic_config(), "base")


FIXED_NOW = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)


@pytest.fixture(autouse=True)
def mock_now_istanbul(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.services.slot_service.get_now_istanbul", lambda: FIXED_NOW)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: FIXED_NOW)
    monkeypatch.setattr("app.api.v1.businesses.get_now_istanbul", lambda: FIXED_NOW)


async def _add_business(session, slug: str) -> Business:
    b = Business(
        name=f"Test {slug}",
        slug=slug,
        working_start_time=time(9, 0),
        working_end_time=time(18, 0),
        slot_duration_minutes=30,
        is_active=True,
    )
    session.add(b)
    await session.flush()
    return b


async def _add_appointment(
    session,
    business_id,
    appointment_date: date,
    start_time: time,
    status: AppointmentStatus,
) -> Appointment:
    a = Appointment(
        business_id=business_id,
        customer_name="Test Customer",
        customer_phone="12345678",
        appointment_date=appointment_date,
        start_time=start_time,
        end_time=time(start_time.hour, start_time.minute + 30) if start_time.minute < 30 else time(start_time.hour + 1, start_time.minute - 30),
        status=status,
    )
    session.add(a)
    await session.flush()
    return a


# ==============================================================================
# REPOSITORY PERSISTENCE TESTS
# ==============================================================================

async def test_get_active_appointment_for_slot_logic() -> None:
    async with async_session_factory() as session:
        b = await _add_business(session, "repo-slot-check")
        
        # 1. Pending found
        a1 = await _add_appointment(session, b.id, date(2026, 7, 20), time(9, 0), AppointmentStatus.PENDING)
        found = await get_active_appointment_for_slot(session, b.id, date(2026, 7, 20), time(9, 0))
        assert found is not None
        assert found.id == a1.id
        
        # 2. Confirmed found
        a2 = await _add_appointment(session, b.id, date(2026, 7, 20), time(9, 30), AppointmentStatus.CONFIRMED)
        found = await get_active_appointment_for_slot(session, b.id, date(2026, 7, 20), time(9, 30))
        assert found is not None
        assert found.id == a2.id
        
        # 3. Cancelled NOT found
        await _add_appointment(session, b.id, date(2026, 7, 20), time(10, 0), AppointmentStatus.CANCELLED)
        found = await get_active_appointment_for_slot(session, b.id, date(2026, 7, 20), time(10, 0))
        assert found is None
        
        # 4. Completed NOT found
        await _add_appointment(session, b.id, date(2026, 7, 20), time(10, 30), AppointmentStatus.COMPLETED)
        found = await get_active_appointment_for_slot(session, b.id, date(2026, 7, 20), time(10, 30))
        assert found is None
        
        # 5. Different business NOT found
        b2 = await _add_business(session, "repo-slot-check-other")
        found = await get_active_appointment_for_slot(session, b2.id, date(2026, 7, 20), time(9, 0))
        assert found is None
        
        # 6. Different date NOT found
        found = await get_active_appointment_for_slot(session, b.id, date(2026, 7, 21), time(9, 0))
        assert found is None
        
        await session.rollback()


async def test_add_appointment_flushes_id() -> None:
    async with async_session_factory() as session:
        b = await _add_business(session, "repo-add-flush")
        a = Appointment(
            business_id=b.id,
            customer_name="Test Customer",
            customer_phone="12345678",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        
        # Call repository add function
        returned_a = await add_appointment(session, a)
        assert returned_a.id is not None  # Generates UUID on flush
        
        # Verify repository did NOT commit
        await session.rollback()
        # Querying it again should return None since rollback wiped the flush
        db_record = await session.get(Appointment, returned_a.id)
        assert db_record is None


# ==============================================================================
# SERVICE TRANSACTION SUCCESS TESTS
# ==============================================================================

async def test_create_appointment_success_path() -> None:
    async with async_session_factory() as session:
        b = await _add_business(session, "service-success")
        payload = AppointmentCreate(
            customer_name="Alice Smith",
            customer_phone="55512345",
            appointment_date=date(2026, 7, 20),
            start_time=time(10, 0),
        )
        
        # Run service function
        appointment = await create_appointment(session, b, payload)
        
        assert appointment.status == AppointmentStatus.PENDING
        assert appointment.end_time == time(10, 30)
        assert appointment.id is not None
        assert appointment.created_at is not None
        
        # Check actual database state
        db_record = await session.get(Appointment, appointment.id)
        assert db_record is not None
        assert db_record.customer_name == "Alice Smith"


# ==============================================================================
# CONFLICT AND EXCEPTION TRANSLATION TESTS
# ==============================================================================

async def test_create_appointment_precheck_conflict() -> None:
    async with async_session_factory() as session:
        b = await _add_business(session, "service-precheck")
        
        # Book a slot
        await _add_appointment(session, b.id, date(2026, 7, 20), time(9, 0), AppointmentStatus.PENDING)
        await session.commit()
        
    async with async_session_factory() as session:
        # Re-fetch business in new session
        b_db = (await session.scalars(select(Business).where(Business.slug == "service-precheck"))).one()
        payload = AppointmentCreate(
            customer_name="Bob Jones",
            customer_phone="55500000",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
        )
        
        # Service should trigger pre-check and raise ConflictError before writing
        with pytest.raises(AppointmentConflictError):
            await create_appointment(session, b_db, payload)


async def test_create_appointment_cancelled_completed_override() -> None:
    async with async_session_factory() as session:
        b = await _add_business(session, "service-override")
        # 1. Cancelled slot
        await _add_appointment(session, b.id, date(2026, 7, 20), time(9, 0), AppointmentStatus.CANCELLED)
        # 2. Completed slot
        await _add_appointment(session, b.id, date(2026, 7, 20), time(10, 0), AppointmentStatus.COMPLETED)
        await session.commit()
        
    async with async_session_factory() as session:
        b_db = (await session.scalars(select(Business).where(Business.slug == "service-override"))).one()
        
        # Create new on cancelled slot
        payload1 = AppointmentCreate(
            customer_name="User A",
            customer_phone="55500001",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
        )
        a1 = await create_appointment(session, b_db, payload1)
        assert a1.id is not None
        
        # Create new on completed slot
        payload2 = AppointmentCreate(
            customer_name="User B",
            customer_phone="55500002",
            appointment_date=date(2026, 7, 20),
            start_time=time(10, 0),
        )
        a2 = await create_appointment(session, b_db, payload2)
        assert a2.id is not None


async def test_create_appointment_db_constraint_race_condition(monkeypatch: pytest.MonkeyPatch) -> None:
    async with async_session_factory() as session:
        b = await _add_business(session, "service-race-cond")
        await session.commit()

    async with async_session_factory() as session:
        b_db = (await session.scalars(select(Business).where(Business.slug == "service-race-cond"))).one()
        
        # Create first record
        payload1 = AppointmentCreate(
            customer_name="Fast Client",
            customer_phone="5551234",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
        )
        await create_appointment(session, b_db, payload1)
        
        # Monkeypatch get_active_appointment_for_slot to return None
        # This bypasses the pre-check to simulate a concurrent request race condition
        async def mock_get(*args, **kwargs):
            return None

        monkeypatch.setattr(
            "app.services.appointment_service.get_active_appointment_for_slot",
            mock_get
        )
        
        payload2 = AppointmentCreate(
            customer_name="Slow Client",
            customer_phone="5559876",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
        )
        
        # Database partial unique index should catch it on commit, and service converts to ConflictError
        with pytest.raises(AppointmentConflictError):
            await create_appointment(session, b_db, payload2)
            
        # Verify the session is still active and can execute queries after rollback
        test_query = await session.scalar(select(Business).where(Business.slug == "service-race-cond"))
        assert test_query is not None
        assert test_query.slug == "service-race-cond"


async def test_create_appointment_unexpected_integrity_error() -> None:
    async with async_session_factory() as session:
        # Create a transient Business object NOT added to the database
        b_transient = Business(
            id=UUID("99999999-9999-9999-9999-999999999999"),
            name="Transient Business",
            slug="transient-slug-err",
            working_start_time=time(9, 0),
            working_end_time=time(18, 0),
            slot_duration_minutes=30,
            is_active=True,
        )

        payload = AppointmentCreate(
            customer_name="Test Unexpected",
            customer_phone="55500000",
            appointment_date=date(2026, 8, 20),
            start_time=time(9, 0),
        )

        # When create_appointment tries to commit, it raises ForeignKey IntegrityError
        # Verify it raises IntegrityError and NOT AppointmentConflictError
        with pytest.raises(IntegrityError):
            await create_appointment(session, b_transient, payload)

        await session.rollback()
