import asyncio
from collections.abc import AsyncGenerator
from datetime import date, datetime, time
import os
from pathlib import Path
import uuid

from alembic import command
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
import pytest
from sqlalchemy import select

from app.core.database import async_session_factory
from app.main import app
from app.models import Appointment, AppointmentStatus, Business
from app.services import appointment_service
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


async def _create_business(
    session,
    name: str,
    slug: str,
    duration: int = 30,
    start_time: time = time(9, 0),
    end_time: time = time(18, 0),
    is_active: bool = True,
) -> Business:
    b = Business(
        name=name,
        slug=slug,
        working_start_time=start_time,
        working_end_time=end_time,
        slot_duration_minutes=duration,
        is_active=is_active,
    )
    session.add(b)
    await session.commit()
    await session.refresh(b)
    return b


# ==============================================================================
# CONCURRENCY TESTS
# ==============================================================================

async def test_appointment_concurrency_race_condition(monkeypatch: pytest.MonkeyPatch) -> None:
    # Pin current time
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    # 1. Create a unique business
    slug = f"concurrency-{uuid.uuid4().hex[:8]}"
    async with async_session_factory() as session:
        b = await _create_business(session, "Concurrency Corp", slug)

    # 2. Setup a Barrier to synchronize the two HTTP request transactions
    barrier = asyncio.Barrier(2)
    original_get_active = appointment_service.get_active_appointment_for_slot

    async def mock_get_active(session, business_id, appointment_date, start_time):
        res = await original_get_active(session, business_id, appointment_date, start_time)
        try:
            # Sync the two concurrent tasks here before they proceed to insertion/commit
            await asyncio.wait_for(barrier.wait(), timeout=2.0)
        except asyncio.TimeoutError:
            pass
        return res

    monkeypatch.setattr(
        "app.services.appointment_service.get_active_appointment_for_slot",
        mock_get_active
    )

    # 3. Prepare clients
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client_a:
        async with AsyncClient(transport=transport, base_url="http://test") as client_b:
            payload_a = {
                "customer_name": "Client A",
                "customer_phone": "11111111",
                "appointment_date": "2026-07-20",
                "start_time": "09:30"
            }
            payload_b = {
                "customer_name": "Client B",
                "customer_phone": "22222222",
                "appointment_date": "2026-07-20",
                "start_time": "09:30"
            }

            # Fire concurrently
            responses = await asyncio.gather(
                client_a.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload_a),
                client_b.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload_b),
            )

    # 4. Verify HTTP response codes: exactly one 201 Created and one 409 Conflict
    status_codes = [r.status_code for r in responses]
    assert sorted(status_codes) == [201, 409]

    # Verify response body values
    res_201 = next(r for r in responses if r.status_code == 201).json()
    res_409 = next(r for r in responses if r.status_code == 409).json()

    assert res_201["customer_name"] in ["Client A", "Client B"]
    assert res_201["status"] == "pending"
    assert "id" in res_201

    assert res_409 == {"detail": "Appointment slot is already booked"}

    # 5. Verify database state
    async with async_session_factory() as session:
        stmt = (
            select(Appointment)
            .where(
                Appointment.business_id == b.id,
                Appointment.appointment_date == date(2026, 7, 20),
                Appointment.start_time == time(9, 30),
                Appointment.status.in_([AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED]),
            )
        )
        records = (await session.scalars(stmt)).all()
        assert len(records) == 1
        assert records[0].customer_name in ["Client A", "Client B"]


@pytest.mark.parametrize("round_idx", list(range(10)))
async def test_appointment_concurrency_stability_10_rounds(round_idx: int, monkeypatch: pytest.MonkeyPatch) -> None:
    # Runs 10 rounds using different parameterized round indexes
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    slug = f"stability-r{round_idx}-{uuid.uuid4().hex[:6]}"
    async with async_session_factory() as session:
        b = await _create_business(session, f"Stability Round {round_idx}", slug)

    barrier = asyncio.Barrier(2)
    original_get_active = appointment_service.get_active_appointment_for_slot

    async def mock_get_active(session, business_id, appointment_date, start_time):
        res = await original_get_active(session, business_id, appointment_date, start_time)
        try:
            await asyncio.wait_for(barrier.wait(), timeout=2.0)
        except asyncio.TimeoutError:
            pass
        return res

    monkeypatch.setattr(
        "app.services.appointment_service.get_active_appointment_for_slot",
        mock_get_active
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client_a:
        async with AsyncClient(transport=transport, base_url="http://test") as client_b:
            payload_a = {
                "customer_name": f"Round {round_idx} A",
                "customer_phone": f"0000{round_idx}",
                "appointment_date": "2026-07-20",
                "start_time": "10:00"
            }
            payload_b = {
                "customer_name": f"Round {round_idx} B",
                "customer_phone": f"1111{round_idx}",
                "appointment_date": "2026-07-20",
                "start_time": "10:00"
            }

            responses = await asyncio.gather(
                client_a.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload_a),
                client_b.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload_b),
            )

    status_codes = [r.status_code for r in responses]
    assert sorted(status_codes) == [201, 409]

    # Verify DB has exactly 1 active
    async with async_session_factory() as session:
        stmt = (
            select(Appointment)
            .where(
                Appointment.business_id == b.id,
                Appointment.appointment_date == date(2026, 7, 20),
                Appointment.start_time == time(10, 0),
                Appointment.status.in_([AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED]),
            )
        )
        records = (await session.scalars(stmt)).all()
        assert len(records) == 1


async def test_appointment_concurrency_after_cancelled(monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    slug = f"cancelled-{uuid.uuid4().hex[:8]}"
    async with async_session_factory() as session:
        b = await _create_business(session, "Cancelled Concurrency", slug)
        
        # Insert a cancelled appointment
        cancelled_app = Appointment(
            business_id=b.id,
            customer_name="Old Customer",
            customer_phone="99999",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.CANCELLED,
        )
        session.add(cancelled_app)
        await session.commit()

    # Now make two concurrent requests to the same slot
    barrier = asyncio.Barrier(2)
    original_get_active = appointment_service.get_active_appointment_for_slot

    async def mock_get_active(session, business_id, appointment_date, start_time):
        res = await original_get_active(session, business_id, appointment_date, start_time)
        try:
            await asyncio.wait_for(barrier.wait(), timeout=2.0)
        except asyncio.TimeoutError:
            pass
        return res

    monkeypatch.setattr(
        "app.services.appointment_service.get_active_appointment_for_slot",
        mock_get_active
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client_a:
        async with AsyncClient(transport=transport, base_url="http://test") as client_b:
            payload_a = {
                "customer_name": "New Client A",
                "customer_phone": "11111",
                "appointment_date": "2026-07-20",
                "start_time": "09:00"
            }
            payload_b = {
                "customer_name": "New Client B",
                "customer_phone": "22222",
                "appointment_date": "2026-07-20",
                "start_time": "09:00"
            }

            responses = await asyncio.gather(
                client_a.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload_a),
                client_b.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload_b),
            )

    status_codes = [r.status_code for r in responses]
    assert sorted(status_codes) == [201, 409]

    # Verify DB has 1 cancelled and exactly 1 active appointment (total 2 records)
    async with async_session_factory() as session:
        stmt = select(Appointment).where(Appointment.business_id == b.id).order_by(Appointment.status)
        records = (await session.scalars(stmt)).all()
        assert len(records) == 2
        
        # 1 active (pending) and 1 cancelled
        cancelled_list = [r for r in records if r.status == AppointmentStatus.CANCELLED]
        active_list = [r for r in records if r.status == AppointmentStatus.PENDING]
        assert len(cancelled_list) == 1
        assert len(active_list) == 1


async def test_appointment_concurrency_different_businesses(monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    async with async_session_factory() as session:
        b1 = await _create_business(session, "Bus 1", f"b1-{uuid.uuid4().hex[:6]}")
        b2 = await _create_business(session, "Bus 2", f"b2-{uuid.uuid4().hex[:6]}")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client_a:
        async with AsyncClient(transport=transport, base_url="http://test") as client_b:
            payload = {
                "customer_name": "Shared Time Client",
                "customer_phone": "123456",
                "appointment_date": "2026-07-20",
                "start_time": "09:00"
            }

            responses = await asyncio.gather(
                client_a.post(f"/api/v1/businesses/{b1.slug}/appointments", json=payload),
                client_b.post(f"/api/v1/businesses/{b2.slug}/appointments", json=payload),
            )

    # Both must succeed
    assert responses[0].status_code == 201
    assert responses[1].status_code == 201

    # Verify DB state
    async with async_session_factory() as session:
        b1_active = (await session.scalars(select(Appointment).where(Appointment.business_id == b1.id))).all()
        b2_active = (await session.scalars(select(Appointment).where(Appointment.business_id == b2.id))).all()
        assert len(b1_active) == 1
        assert len(b2_active) == 1


async def test_appointment_concurrency_different_dates(monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    async with async_session_factory() as session:
        b = await _create_business(session, "Date Iso", f"date-iso-{uuid.uuid4().hex[:6]}")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client_a:
        async with AsyncClient(transport=transport, base_url="http://test") as client_b:
            responses = await asyncio.gather(
                client_a.post(
                    f"/api/v1/businesses/{b.slug}/appointments",
                    json={
                        "customer_name": "Date A",
                        "customer_phone": "12345",
                        "appointment_date": "2026-07-20",
                        "start_time": "09:00"
                    }
                ),
                client_b.post(
                    f"/api/v1/businesses/{b.slug}/appointments",
                    json={
                        "customer_name": "Date B",
                        "customer_phone": "45678",
                        "appointment_date": "2026-07-21",
                        "start_time": "09:00"
                    }
                ),
            )

    # Both must succeed
    assert responses[0].status_code == 201
    assert responses[1].status_code == 201

    # Verify DB state
    async with async_session_factory() as session:
        records = (await session.scalars(select(Appointment).where(Appointment.business_id == b.id))).all()
        assert len(records) == 2
