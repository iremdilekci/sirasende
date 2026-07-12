from collections.abc import AsyncGenerator
from datetime import date, datetime, time
import os
from pathlib import Path

from alembic import command
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
import pytest
from sqlalchemy import select

from app.core.database import async_session_factory
from app.main import app
from app.models import Appointment, AppointmentStatus, Business
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


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client


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
# HTTP ENDPOINT TESTS
# ==============================================================================

async def test_post_appointment_success(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    # Pin current time to 2026-07-12 10:15
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    async with async_session_factory() as session:
        b = await _create_business(session, "Demo Business", "demo-slug")
        
    payload = {
        "customer_name": "İrem Dilekçi",
        "customer_phone": "+905551112233",
        "customer_note": "Saç kesimi",
        "appointment_date": "2026-07-20",
        "start_time": "09:30"
    }
    
    response = await client.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload)
    assert response.status_code == 201
    data = response.json()
    
    # Assert response fields
    assert data["customer_name"] == "İrem Dilekçi"
    assert data["customer_phone"] == "+905551112233"
    assert data["customer_note"] == "Saç kesimi"
    assert data["appointment_date"] == "2026-07-20"
    assert data["start_time"] == "09:30"
    assert data["end_time"] == "10:00"  # Calculated 30 min slot
    assert data["status"] == "pending"
    assert "id" in data
    assert "created_at" in data
    
    # Verify in DB
    async with async_session_factory() as session:
        db_record = await session.scalar(
            select(Appointment).where(Appointment.customer_name == "İrem Dilekçi")
        )
        assert db_record is not None
        assert db_record.customer_phone == "+905551112233"


async def test_post_appointment_slot_durations(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    # 45 min business
    async with async_session_factory() as session:
        b45 = await _create_business(session, "B45", "slug45", duration=45)
    
    response = await client.post(
        f"/api/v1/businesses/{b45.slug}/appointments",
        json={
            "customer_name": "Test User",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "09:00"
        }
    )
    assert response.status_code == 201
    assert response.json()["end_time"] == "09:45"

    # 60 min business
    async with async_session_factory() as session:
        b60 = await _create_business(session, "B60", "slug60", duration=60)
    
    response = await client.post(
        f"/api/v1/businesses/{b60.slug}/appointments",
        json={
            "customer_name": "Test User",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "09:00"
        }
    )
    assert response.status_code == 201
    assert response.json()["end_time"] == "10:00"


async def test_post_appointment_missing_or_inactive_business(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    # 1. Missing business
    response = await client.post(
        "/api/v1/businesses/olmayan/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "09:00"
        }
    )
    assert response.status_code == 404
    assert response.json() == {"detail": "Business not found"}

    # 2. Inactive business
    async with async_session_factory() as session:
        b_inactive = await _create_business(session, "Pasif", "slug-pasif", is_active=False)

    response = await client.post(
        f"/api/v1/businesses/{b_inactive.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "09:00"
        }
    )
    assert response.status_code == 404
    assert response.json() == {"detail": "Business not found"}


async def test_post_appointment_date_time_limits(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    async with async_session_factory() as session:
        b = await _create_business(session, "Time Limits", "slug-time-limits")

    # 1. Past date -> 400
    response = await client.post(
        f"/api/v1/businesses/{b.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-11",
            "start_time": "09:00"
        }
    )
    assert response.status_code == 400
    assert response.json() == {"detail": "Cannot book appointments in the past"}

    # 2. Today's past slot -> 400
    response = await client.post(
        f"/api/v1/businesses/{b.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-12",
            "start_time": "09:30"  # 09:30 <= 10:15
        }
    )
    assert response.status_code == 400
    assert response.json() == {"detail": "Cannot book appointments in the past"}

    # 3. Today's exact slot time -> 400 (Starts 10:00 <= 10:15)
    response = await client.post(
        f"/api/v1/businesses/{b.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-12",
            "start_time": "10:00"
        }
    )
    assert response.status_code == 400
    assert response.json() == {"detail": "Cannot book appointments in the past"}

    # 4. Today's future slot -> 201 (Starts 11:00 > 10:15)
    response = await client.post(
        f"/api/v1/businesses/{b.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-12",
            "start_time": "11:00"
        }
    )
    assert response.status_code == 201


async def test_post_appointment_slot_validity(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    async with async_session_factory() as session:
        b = await _create_business(session, "Slot Validity", "slug-slot-val", start_time=time(9, 0), end_time=time(18, 0))

    # 1. 09:15 is invalid for 30-min duration
    response = await client.post(
        f"/api/v1/businesses/{b.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "09:15"
        }
    )
    assert response.status_code == 400
    assert response.json() == {"detail": "Invalid appointment slot"}

    # 2. Before working hours
    response = await client.post(
        f"/api/v1/businesses/{b.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "08:30"
        }
    )
    assert response.status_code == 400
    assert response.json() == {"detail": "Invalid appointment slot"}

    # 3. After working hours
    response = await client.post(
        f"/api/v1/businesses/{b.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "18:00"
        }
    )
    assert response.status_code == 400
    assert response.json() == {"detail": "Invalid appointment slot"}

    # 4. Overlap closing boundary (Starts 17:45, closes 18:00)
    response = await client.post(
        f"/api/v1/businesses/{b.slug}/appointments",
        json={
            "customer_name": "Test",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "17:45"
        }
    )
    assert response.status_code == 400
    assert response.json() == {"detail": "Invalid appointment slot"}


async def test_post_appointment_conflicts(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    async with async_session_factory() as session:
        b = await _create_business(session, "Conflict Test", "slug-conflict")

    payload = {
        "customer_name": "User 1",
        "customer_phone": "5551234",
        "appointment_date": "2026-07-20",
        "start_time": "09:00"
    }

    # 1. First booking -> success 201
    response = await client.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload)
    assert response.status_code == 201

    # 2. Second booking -> conflict 409
    response2 = await client.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload)
    assert response2.status_code == 409
    assert response2.json() == {"detail": "Appointment slot is already booked"}


async def test_post_appointment_cancelled_completed_allow_booking(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    async with async_session_factory() as session:
        b = await _create_business(session, "Cancel-Complete Test", "slug-cancel-complete")
        
    # Book slot 09:00 (Will update to cancelled via DB directly)
    payload_cancel = {
        "customer_name": "Cancel User",
        "customer_phone": "12345",
        "appointment_date": "2026-07-20",
        "start_time": "09:00"
    }
    response = await client.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload_cancel)
    assert response.status_code == 201
    a_id = response.json()["id"]
    
    async with async_session_factory() as session:
        a_db = await session.get(Appointment, a_id)
        a_db.status = AppointmentStatus.CANCELLED
        await session.commit()
        
    # Query 09:00 slot again -> success
    response2 = await client.post(f"/api/v1/businesses/{b.slug}/appointments", json=payload_cancel)
    assert response2.status_code == 201


async def test_post_appointment_isolation(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: fixed_now)

    async with async_session_factory() as session:
        b1 = await _create_business(session, "Business 1", "slug-iso-1")
        b2 = await _create_business(session, "Business 2", "slug-iso-2")

    payload = {
        "customer_name": "User",
        "customer_phone": "12345",
        "appointment_date": "2026-07-20",
        "start_time": "09:00"
    }

    # Book business 1
    response = await client.post(f"/api/v1/businesses/{b1.slug}/appointments", json=payload)
    assert response.status_code == 201

    # Book business 2 on the same slot -> success (isolation)
    response2 = await client.post(f"/api/v1/businesses/{b2.slug}/appointments", json=payload)
    assert response2.status_code == 201


# ==============================================================================
# SCHEMAS AND EXTRA FIELDS VALIDATION TESTS
# ==============================================================================

async def test_post_appointment_validation(client: AsyncClient) -> None:
    slug = "slug-iso-1"
    
    # 1. Missing name -> 422
    response = await client.post(
        f"/api/v1/businesses/{slug}/appointments",
        json={
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "09:00"
        }
    )
    assert response.status_code == 422

    # 2. Too short name -> 422
    response = await client.post(
        f"/api/v1/businesses/{slug}/appointments",
        json={
            "customer_name": "A",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "09:00"
        }
    )
    assert response.status_code == 422

    # 3. Forbidden extra fields: end_time -> 422
    response = await client.post(
        f"/api/v1/businesses/{slug}/appointments",
        json={
            "customer_name": "Valid User",
            "customer_phone": "123456",
            "appointment_date": "2026-07-20",
            "start_time": "09:00",
            "end_time": "09:30"
        }
    )
    assert response.status_code == 422
