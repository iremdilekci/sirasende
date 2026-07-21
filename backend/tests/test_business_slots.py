from collections.abc import AsyncGenerator
from datetime import date, datetime, time
import os
from pathlib import Path
from typing import Any

from alembic import command
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
import pytest
from sqlalchemy import select

from app.core.database import async_session_factory
from app.main import app
from app.models import AdminUser, Appointment, AppointmentStatus, Business
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


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client


async def _create_business(
    session,
    name: str,
    slug: str,
    start_time: time,
    end_time: time,
    duration: int,
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


async def _create_appointment(
    session,
    business_id,
    appointment_date: date,
    start_time: time,
    end_time: time,
    status: AppointmentStatus,
) -> Appointment:
    a = Appointment(
        business_id=business_id,
        customer_name="Test Customer",
        customer_phone="555-1234",
        appointment_date=appointment_date,
        start_time=start_time,
        end_time=end_time,
        status=status,
    )
    session.add(a)
    await session.commit()
    return a


# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

async def test_get_slots_empty_day_30_minutes(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test empty 30", "test-empty-30", time(9, 0), time(11, 0), 30
        )
    
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date=2026-07-20")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 4
    
    # Check formats and values
    assert data[0] == {"start_time": "09:00", "end_time": "09:30", "available": True, "reason": None}
    assert data[1] == {"start_time": "09:30", "end_time": "10:00", "available": True, "reason": None}
    assert data[2] == {"start_time": "10:00", "end_time": "10:30", "available": True, "reason": None}
    assert data[3] == {"start_time": "10:30", "end_time": "11:00", "available": True, "reason": None}


async def test_get_slots_with_pending_appointment(client: AsyncClient) -> None:
    query_date = date(2026, 7, 20)
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test pending", "test-pending", time(9, 0), time(11, 0), 30
        )
        await _create_appointment(
            session, b.id, query_date, time(9, 30), time(10, 0), AppointmentStatus.PENDING
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date={query_date}")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 4
    
    assert data[0]["available"] is True
    assert data[1] == {"start_time": "09:30", "end_time": "10:00", "available": False, "reason": "booked"}
    assert data[2]["available"] is True
    assert data[3]["available"] is True


async def test_get_slots_with_confirmed_appointment(client: AsyncClient) -> None:
    query_date = date(2026, 7, 20)
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test confirmed", "test-confirmed", time(9, 0), time(11, 0), 30
        )
        await _create_appointment(
            session, b.id, query_date, time(10, 0), time(10, 30), AppointmentStatus.CONFIRMED
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date={query_date}")
    assert response.status_code == 200
    data = response.json()
    
    assert data[2] == {"start_time": "10:00", "end_time": "10:30", "available": False, "reason": "booked"}


async def test_get_slots_with_cancelled_appointment(client: AsyncClient) -> None:
    query_date = date(2026, 7, 20)
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test cancelled", "test-cancelled", time(9, 0), time(11, 0), 30
        )
        await _create_appointment(
            session, b.id, query_date, time(9, 30), time(10, 0), AppointmentStatus.CANCELLED
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date={query_date}")
    assert response.status_code == 200
    data = response.json()
    
    assert data[1]["available"] is True
    assert data[1]["reason"] is None


async def test_get_slots_with_completed_appointment(client: AsyncClient) -> None:
    query_date = date(2026, 7, 20)
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test completed", "test-completed", time(9, 0), time(11, 0), 30
        )
        await _create_appointment(
            session, b.id, query_date, time(9, 30), time(10, 0), AppointmentStatus.COMPLETED
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date={query_date}")
    assert response.status_code == 200
    data = response.json()
    
    assert data[1]["available"] is True


async def test_get_slots_partial_overlap(client: AsyncClient) -> None:
    query_date = date(2026, 7, 20)
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test overlap", "test-overlap", time(9, 0), time(11, 0), 30
        )
        # Appointment overlaps: 09:00 - 09:30, 09:30 - 10:00, 10:00 - 10:30
        await _create_appointment(
            session, b.id, query_date, time(9, 15), time(10, 15), AppointmentStatus.CONFIRMED
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date={query_date}")
    assert response.status_code == 200
    data = response.json()
    
    assert data[0]["available"] is False
    assert data[0]["reason"] == "booked"
    assert data[1]["available"] is False
    assert data[1]["reason"] == "booked"
    assert data[2]["available"] is False
    assert data[2]["reason"] == "booked"
    assert data[3]["available"] is True


async def test_get_slots_today_past_filtering(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    # Fix local time to 2026-07-12 10:15
    fixed_now = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.slot_service.get_now_istanbul", lambda: fixed_now)
    monkeypatch.setattr("app.api.v1.businesses.get_now_istanbul", lambda: fixed_now)
    
    query_date = date(2026, 7, 12)
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test past slots", "test-past-slots", time(9, 0), time(12, 0), 30
        )
        # Book a future slot today: 11:00 - 11:30
        await _create_appointment(
            session, b.id, query_date, time(11, 0), time(11, 30), AppointmentStatus.CONFIRMED
        )
        # Book a past slot today: 09:30 - 10:00 (Should override booked to past)
        await _create_appointment(
            session, b.id, query_date, time(9, 30), time(10, 0), AppointmentStatus.CONFIRMED
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date={query_date}")
    assert response.status_code == 200
    data = response.json()
    
    # 09:00 - 09:30 -> starts 09:00 <= 10:15 (past)
    assert data[0] == {"start_time": "09:00", "end_time": "09:30", "available": False, "reason": "past"}
    # 09:30 - 10:00 -> starts 09:30 <= 10:15 (past - overrides booked)
    assert data[1] == {"start_time": "09:30", "end_time": "10:00", "available": False, "reason": "past"}
    # 10:00 - 10:30 -> starts 10:00 <= 10:15 (past)
    assert data[2] == {"start_time": "10:00", "end_time": "10:30", "available": False, "reason": "past"}
    # 10:30 - 11:00 -> starts 10:30 > 10:15 (available)
    assert data[3] == {"start_time": "10:30", "end_time": "11:00", "available": True, "reason": None}
    # 11:00 - 11:30 -> starts 11:00 > 10:15 (booked)
    assert data[4] == {"start_time": "11:00", "end_time": "11:30", "available": False, "reason": "booked"}


async def test_get_slots_past_date(client: AsyncClient, monkeypatch: pytest.MonkeyPatch) -> None:
    fixed_now = datetime(2026, 7, 12, 10, 0, tzinfo=ISTANBUL_TIMEZONE)
    monkeypatch.setattr("app.services.slot_service.get_now_istanbul", lambda: fixed_now)
    monkeypatch.setattr("app.api.v1.businesses.get_now_istanbul", lambda: fixed_now)
    
    response = await client.get("/api/v1/businesses/test-past-slots/slots?date=2026-07-11")
    assert response.status_code == 400
    assert response.json() == {"detail": "Cannot query slots for past dates"}


async def test_get_slots_missing_business(client: AsyncClient) -> None:
    response = await client.get("/api/v1/businesses/olmayan-isletme/slots?date=2026-07-20")
    assert response.status_code == 404
    assert response.json() == {"detail": "Business not found"}


async def test_get_slots_inactive_business(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Pasif", "pasif-kuafor-slots", time(9, 0), time(11, 0), 30, is_active=False
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date=2026-07-20")
    assert response.status_code == 404
    assert response.json() == {"detail": "Business not found"}


async def test_get_slots_invalid_date_format(client: AsyncClient) -> None:
    response = await client.get("/api/v1/businesses/any/slots?date=12-07-2026")
    assert response.status_code == 422


async def test_get_slots_missing_date_parameter(client: AsyncClient) -> None:
    response = await client.get("/api/v1/businesses/any/slots")
    assert response.status_code == 422


async def test_get_slots_45_minutes_duration(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test 45 min", "test-45-min", time(9, 0), time(11, 0), 45
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date=2026-07-20")
    assert response.status_code == 200
    data = response.json()
    
    assert len(data) == 2
    assert data[0] == {"start_time": "09:00", "end_time": "09:45", "available": True, "reason": None}
    assert data[1] == {"start_time": "09:45", "end_time": "10:30", "available": True, "reason": None}


async def test_get_slots_60_minutes_duration(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        b = await _create_business(
            session, "Test 60 min", "test-60-min", time(9, 0), time(12, 0), 60
        )
        
    response = await client.get(f"/api/v1/businesses/{b.slug}/slots?date=2026-07-20")
    assert response.status_code == 200
    data = response.json()
    
    assert len(data) == 3
    assert data[0]["start_time"] == "09:00"
    assert data[1]["start_time"] == "10:00"
    assert data[2]["start_time"] == "11:00"


# ==============================================================================
# REPOSITORY ISOLATION TESTS
# ==============================================================================

async def test_get_slots_repository_isolation(client: AsyncClient) -> None:
    query_date = date(2026, 7, 20)
    async with async_session_factory() as session:
        # Create Business 1 and Business 2
        b1 = await _create_business(
            session, "Business 1", "business-1", time(9, 0), time(11, 0), 30
        )
        b2 = await _create_business(
            session, "Business 2", "business-2", time(9, 0), time(11, 0), 30
        )
        
        # 1. Book a slot for Business 2 at 09:00 - 09:30 on query_date
        # (Should NOT affect Business 1 slots)
        await _create_appointment(
            session, b2.id, query_date, time(9, 0), time(9, 30), AppointmentStatus.CONFIRMED
        )
        
        # 2. Book a slot for Business 1 at 09:30 - 10:00 on a DIFFERENT date (2026-07-21)
        # (Should NOT affect Business 1 slots on query_date)
        await _create_appointment(
            session, b1.id, date(2026, 7, 21), time(9, 30), time(10, 0), AppointmentStatus.CONFIRMED
        )
        
    # Query Business 1 slots on query_date
    response = await client.get(f"/api/v1/businesses/{b1.slug}/slots?date={query_date}")
    assert response.status_code == 200
    data = response.json()
    
    # Both slots must remain available on query_date for Business 1
    assert data[0] == {"start_time": "09:00", "end_time": "09:30", "available": True, "reason": None}
    assert data[1] == {"start_time": "09:30", "end_time": "10:00", "available": True, "reason": None}
