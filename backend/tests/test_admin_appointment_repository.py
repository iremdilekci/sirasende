import os
from datetime import date, time
from pathlib import Path
from uuid import uuid4

import pytest
from alembic import command
from alembic.config import Config

from app.core.database import async_session_factory
from app.models.appointment import Appointment, AppointmentStatus
from app.models.business import Business
from app.repositories.appointment_repository import (
    get_appointment_for_business,
    get_appointment_for_business_for_update,
    list_appointments_for_business,
)

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
    customer_name: str = "Test Customer",
    customer_phone: str = "05551112233",
    appointment_date: date = date(2026, 8, 1),
    start_time: time = time(10, 0),
    end_time: time = time(10, 30),
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


# ---------------------------------------------------------------------------
# LISTING TESTS
# ---------------------------------------------------------------------------


async def test_list_appointments_for_business_only_returns_matching_business() -> None:
    b1 = await _create_test_business()
    b2 = await _create_test_business()

    apt1 = await _create_test_appointment(b1.id, appointment_date=date(2026, 8, 10), start_time=time(10, 0), end_time=time(10, 30))
    apt2 = await _create_test_appointment(b2.id, appointment_date=date(2026, 8, 10), start_time=time(10, 0), end_time=time(10, 30))

    async with async_session_factory() as session:
        res = await list_appointments_for_business(session, business_id=b1.id)
        res_ids = [a.id for a in res]
        assert apt1.id in res_ids
        assert apt2.id not in res_ids


async def test_list_appointments_for_business_hides_other_businesses() -> None:
    b1 = await _create_test_business()
    b2 = await _create_test_business()

    await _create_test_appointment(b2.id, appointment_date=date(2026, 8, 11), start_time=time(9, 0), end_time=time(9, 30))

    async with async_session_factory() as session:
        res = await list_appointments_for_business(session, business_id=b1.id)
        assert len(res) == 0


async def test_list_appointments_for_business_date_filter() -> None:
    b = await _create_test_business()

    apt1 = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 15), start_time=time(10, 0), end_time=time(10, 30))
    apt2 = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 16), start_time=time(10, 0), end_time=time(10, 30))

    async with async_session_factory() as session:
        res = await list_appointments_for_business(session, business_id=b.id, appointment_date=date(2026, 8, 15))
        res_ids = [a.id for a in res]
        assert apt1.id in res_ids
        assert apt2.id not in res_ids


async def test_list_appointments_for_business_status_filter() -> None:
    b = await _create_test_business()

    apt1 = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 20), start_time=time(10, 0), end_time=time(10, 30), status=AppointmentStatus.PENDING)
    apt2 = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 20), start_time=time(11, 0), end_time=time(11, 30), status=AppointmentStatus.CONFIRMED)

    async with async_session_factory() as session:
        res_pending = await list_appointments_for_business(session, business_id=b.id, status=AppointmentStatus.PENDING)
        pending_ids = [a.id for a in res_pending]
        assert apt1.id in pending_ids
        assert apt2.id not in pending_ids

        res_confirmed = await list_appointments_for_business(session, business_id=b.id, status=AppointmentStatus.CONFIRMED)
        confirmed_ids = [a.id for a in res_confirmed]
        assert apt2.id in confirmed_ids
        assert apt1.id not in confirmed_ids


async def test_list_appointments_for_business_date_and_status_filter() -> None:
    b = await _create_test_business()

    apt1 = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 21), start_time=time(10, 0), end_time=time(10, 30), status=AppointmentStatus.PENDING)
    await _create_test_appointment(b.id, appointment_date=date(2026, 8, 21), start_time=time(11, 0), end_time=time(11, 30), status=AppointmentStatus.CONFIRMED)
    await _create_test_appointment(b.id, appointment_date=date(2026, 8, 22), start_time=time(10, 0), end_time=time(10, 30), status=AppointmentStatus.PENDING)

    async with async_session_factory() as session:
        res = await list_appointments_for_business(
            session,
            business_id=b.id,
            appointment_date=date(2026, 8, 21),
            status=AppointmentStatus.PENDING,
        )
        assert len(res) == 1
        assert res[0].id == apt1.id


async def test_list_appointments_for_business_empty_when_no_match() -> None:
    b = await _create_test_business()

    async with async_session_factory() as session:
        res = await list_appointments_for_business(
            session,
            business_id=b.id,
            appointment_date=date(2029, 1, 1),
        )
        assert res == []


async def test_list_appointments_for_business_ordering() -> None:
    b = await _create_test_business()

    apt3 = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 25), start_time=time(14, 0), end_time=time(14, 30))
    apt1 = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 24), start_time=time(11, 0), end_time=time(11, 30))
    apt2 = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 24), start_time=time(15, 0), end_time=time(15, 30))

    async with async_session_factory() as session:
        res = await list_appointments_for_business(session, business_id=b.id)
        # Filter res to only include apt1, apt2, apt3
        target_res = [a for a in res if a.id in (apt1.id, apt2.id, apt3.id)]
        assert [a.id for a in target_res] == [apt1.id, apt2.id, apt3.id]


async def test_list_appointments_for_business_includes_cancelled() -> None:
    b = await _create_test_business()

    apt_cancelled = await _create_test_appointment(
        b.id,
        appointment_date=date(2026, 8, 26),
        start_time=time(10, 0),
        end_time=time(10, 30),
        status=AppointmentStatus.CANCELLED,
    )

    async with async_session_factory() as session:
        res = await list_appointments_for_business(session, business_id=b.id)
        res_ids = [a.id for a in res]
        assert apt_cancelled.id in res_ids


async def test_list_appointments_for_business_includes_completed() -> None:
    b = await _create_test_business()

    apt_completed = await _create_test_appointment(
        b.id,
        appointment_date=date(2026, 8, 27),
        start_time=time(10, 0),
        end_time=time(10, 30),
        status=AppointmentStatus.COMPLETED,
    )

    async with async_session_factory() as session:
        res = await list_appointments_for_business(session, business_id=b.id)
        res_ids = [a.id for a in res]
        assert apt_completed.id in res_ids


# ---------------------------------------------------------------------------
# SINGLE RECORD TESTS
# ---------------------------------------------------------------------------


async def test_get_appointment_for_business_found() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 28), start_time=time(10, 0), end_time=time(10, 30))

    async with async_session_factory() as session:
        res = await get_appointment_for_business(session, appointment_id=apt.id, business_id=b.id)
        assert res is not None
        assert res.id == apt.id
        assert res.business_id == b.id


async def test_get_appointment_for_business_non_existent_returns_none() -> None:
    b = await _create_test_business()

    async with async_session_factory() as session:
        res = await get_appointment_for_business(session, appointment_id=uuid4(), business_id=b.id)
        assert res is None


async def test_get_appointment_for_business_other_business_returns_none() -> None:
    b1 = await _create_test_business()
    b2 = await _create_test_business()
    apt = await _create_test_appointment(b1.id, appointment_date=date(2026, 8, 29), start_time=time(10, 0), end_time=time(10, 30))

    async with async_session_factory() as session:
        # Querying b1's appointment using b2's business_id must return None
        res = await get_appointment_for_business(session, appointment_id=apt.id, business_id=b2.id)
        assert res is None


# ---------------------------------------------------------------------------
# FOR UPDATE TESTS
# ---------------------------------------------------------------------------


async def test_get_appointment_for_business_for_update_found() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, appointment_date=date(2026, 8, 30), start_time=time(10, 0), end_time=time(10, 30))

    async with async_session_factory() as session:
        async with session.begin():
            res = await get_appointment_for_business_for_update(session, appointment_id=apt.id, business_id=b.id)
            assert res is not None
            assert res.id == apt.id


async def test_get_appointment_for_business_for_update_other_business_returns_none() -> None:
    b1 = await _create_test_business()
    b2 = await _create_test_business()
    apt = await _create_test_appointment(b1.id, appointment_date=date(2026, 8, 31), start_time=time(10, 0), end_time=time(10, 30))

    async with async_session_factory() as session:
        async with session.begin():
            res = await get_appointment_for_business_for_update(session, appointment_id=apt.id, business_id=b2.id)
            assert res is None


async def test_get_appointment_for_business_for_update_mutation_in_transaction() -> None:
    b = await _create_test_business()
    apt = await _create_test_appointment(b.id, appointment_date=date(2026, 9, 1), start_time=time(10, 0), end_time=time(10, 30), status=AppointmentStatus.PENDING)

    async with async_session_factory() as session:
        async with session.begin():
            res = await get_appointment_for_business_for_update(session, appointment_id=apt.id, business_id=b.id)
            assert res is not None
            res.status = AppointmentStatus.CONFIRMED
            await session.flush()

    # Verify state was mutated in DB
    async with async_session_factory() as session:
        reloaded = await get_appointment_for_business(session, appointment_id=apt.id, business_id=b.id)
        assert reloaded is not None
        assert reloaded.status == AppointmentStatus.CONFIRMED
