import os
from datetime import date, datetime, time, timezone
from pathlib import Path
from uuid import uuid4

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import select

from app.core.database import async_session_factory
from app.core.exceptions import (
    AppointmentCompletionNotAllowedError,
    AppointmentNotFoundError,
    InvalidAppointmentStatusTransitionError,
)
from app.models.appointment import Appointment, AppointmentStatus
from app.models.business import Business
from app.services.admin_appointment_service import change_appointment_status, list_admin_appointments
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
    command.upgrade(_alembic_config(), "head")
    yield
    command.downgrade(_alembic_config(), "base")


FIXED_NOW = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)


@pytest.fixture(autouse=True)
def mock_now_istanbul(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.services.admin_appointment_service.get_now_istanbul", lambda: FIXED_NOW)
    monkeypatch.setattr("app.services.slot_service.get_now_istanbul", lambda: FIXED_NOW)


async def _create_test_business(slug: str | None = None) -> Business:
    if slug is None:
        slug = f"business-{uuid4().hex[:8]}"
    business = Business(
        name=f"Business {slug}",
        slug=slug,
        working_start_time=time(9, 0),
        working_end_time=time(18, 0),
        slot_duration_minutes=30,
        is_active=True,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(business)
        await session.refresh(business)
    return business


async def _create_test_appointment(
    business_id: str,
    *,
    customer_name: str = "Integration Customer",
    customer_phone: str = "05559998877",
    appointment_date: date = date(2026, 7, 12),
    start_time: time = time(9, 0),
    end_time: time = time(9, 30),
    status: AppointmentStatus = AppointmentStatus.PENDING,
) -> Appointment:
    apt = Appointment(
        business_id=business_id,
        customer_name=customer_name,
        customer_phone=customer_phone,
        appointment_date=appointment_date,
        start_time=start_time,
        end_time=end_time,
        status=status,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(apt)
        await session.refresh(apt)
    return apt


async def test_service_pending_to_confirmed_persisted_in_db() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, status=AppointmentStatus.PENDING)

    async with async_session_factory() as session:
        updated = await change_appointment_status(
            session,
            business_id=b.id,
            appointment_id=apt.id,
            target_status=AppointmentStatus.CONFIRMED,
        )
        assert updated.status == AppointmentStatus.CONFIRMED

    # Verify persistence in clean session
    async with async_session_factory() as session:
        reloaded = await session.get(Appointment, apt.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.CONFIRMED


async def test_service_pending_to_cancelled_persisted_in_db() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, status=AppointmentStatus.PENDING)

    async with async_session_factory() as session:
        updated = await change_appointment_status(
            session,
            business_id=b.id,
            appointment_id=apt.id,
            target_status=AppointmentStatus.CANCELLED,
        )
        assert updated.status == AppointmentStatus.CANCELLED

    async with async_session_factory() as session:
        reloaded = await session.get(Appointment, apt.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.CANCELLED


async def test_service_confirmed_to_completed_past_appointment_persisted() -> None:
    b = await _create_test_business()
    # end_time 10:00 on 2026-07-12; FIXED_NOW is 10:15
    apt = await _create_test_appointment(
        b.id,
        appointment_date=date(2026, 7, 12),
        start_time=time(9, 30),
        end_time=time(10, 0),
        status=AppointmentStatus.CONFIRMED,
    )

    async with async_session_factory() as session:
        updated = await change_appointment_status(
            session,
            business_id=b.id,
            appointment_id=apt.id,
            target_status=AppointmentStatus.COMPLETED,
            now=FIXED_NOW,
        )
        assert updated.status == AppointmentStatus.COMPLETED

    async with async_session_factory() as session:
        reloaded = await session.get(Appointment, apt.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.COMPLETED


async def test_service_completed_before_end_time_rejected_db_unchanged() -> None:
    b = await _create_test_business()
    # end_time 11:00 on 2026-07-12; FIXED_NOW is 10:15
    apt = await _create_test_appointment(
        b.id,
        appointment_date=date(2026, 7, 12),
        start_time=time(10, 30),
        end_time=time(11, 0),
        status=AppointmentStatus.CONFIRMED,
    )

    async with async_session_factory() as session:
        with pytest.raises(AppointmentCompletionNotAllowedError):
            await change_appointment_status(
                session,
                business_id=b.id,
                appointment_id=apt.id,
                target_status=AppointmentStatus.COMPLETED,
                now=FIXED_NOW,
            )

    async with async_session_factory() as session:
        reloaded = await session.get(Appointment, apt.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.CONFIRMED


async def test_service_invalid_transition_rejected_db_unchanged() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, status=AppointmentStatus.PENDING)

    async with async_session_factory() as session:
        with pytest.raises(InvalidAppointmentStatusTransitionError):
            await change_appointment_status(
                session,
                business_id=b.id,
                appointment_id=apt.id,
                target_status=AppointmentStatus.COMPLETED,
            )

    async with async_session_factory() as session:
        reloaded = await session.get(Appointment, apt.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.PENDING


async def test_service_other_business_raises_not_found() -> None:
    b1 = await _create_test_business()
    b2 = await _create_test_business()
    apt = await _create_test_appointment(b1.id, status=AppointmentStatus.PENDING)

    async with async_session_factory() as session:
        with pytest.raises(AppointmentNotFoundError):
            await change_appointment_status(
                session,
                business_id=b2.id,
                appointment_id=apt.id,
                target_status=AppointmentStatus.CONFIRMED,
            )


async def test_service_non_existent_appointment_raises_not_found() -> None:
    b = await _create_test_business()

    async with async_session_factory() as session:
        with pytest.raises(AppointmentNotFoundError):
            await change_appointment_status(
                session,
                business_id=b.id,
                appointment_id=uuid4(),
                target_status=AppointmentStatus.CONFIRMED,
            )


async def test_service_idempotent_same_status_preserves_db_state_and_allows_subsequent_queries() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, status=AppointmentStatus.CONFIRMED)

    async with async_session_factory() as session:
        res = await change_appointment_status(
            session,
            business_id=b.id,
            appointment_id=apt.id,
            target_status=AppointmentStatus.CONFIRMED,
        )
        assert res.status == AppointmentStatus.CONFIRMED

        # Execute subsequent query in SAME session to prove transaction/lock was closed cleanly
        reloaded = await session.scalar(
            select(Appointment).where(Appointment.id == apt.id)
        )
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.CONFIRMED

    async with async_session_factory() as session:
        reloaded = await session.get(Appointment, apt.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.CONFIRMED


async def test_service_updated_at_matches_injected_now_utc() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, status=AppointmentStatus.PENDING)

    async with async_session_factory() as session:
        res = await change_appointment_status(
            session,
            business_id=b.id,
            appointment_id=apt.id,
            target_status=AppointmentStatus.CONFIRMED,
            now=FIXED_NOW,
        )
        assert res.updated_at == FIXED_NOW.astimezone(timezone.utc)


async def test_service_cancelled_remains_terminal_in_db() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, status=AppointmentStatus.CANCELLED)

    async with async_session_factory() as session:
        with pytest.raises(InvalidAppointmentStatusTransitionError):
            await change_appointment_status(
                session,
                business_id=b.id,
                appointment_id=apt.id,
                target_status=AppointmentStatus.CONFIRMED,
            )

    async with async_session_factory() as session:
        reloaded = await session.get(Appointment, apt.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.CANCELLED


async def test_service_completed_remains_terminal_in_db() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, status=AppointmentStatus.COMPLETED)

    async with async_session_factory() as session:
        with pytest.raises(InvalidAppointmentStatusTransitionError):
            await change_appointment_status(
                session,
                business_id=b.id,
                appointment_id=apt.id,
                target_status=AppointmentStatus.CANCELLED,
            )

    async with async_session_factory() as session:
        reloaded = await session.get(Appointment, apt.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.COMPLETED
