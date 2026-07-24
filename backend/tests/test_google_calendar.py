import hashlib
import json
import os
from datetime import date, time, datetime, timezone, timedelta
from pathlib import Path
from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
import httpx
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models import AdminUser, Business, Appointment, AppointmentStatus, GoogleCalendarSyncStatus
from app.models.google_calendar_connection import GoogleCalendarConnection
from app.services.google_oauth import GoogleOAuthService
from app.services.google_calendar import GoogleCalendarService

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

@pytest.fixture
async def client() -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client

@pytest.fixture
async def db_session():
    async with async_session_factory() as session:
        yield session

async def _create_business() -> Business:
    slug = f"biz-{uuid4().hex[:8]}"
    b = Business(
        name=f"Business {slug}",
        slug=slug,
        description="Demo business",
        phone="05554443322",
        address="Kadikoy, Istanbul",
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

async def _create_admin(business_id: str) -> tuple[AdminUser, str]:
    username = f"admin_{uuid4().hex[:8]}"
    admin = AdminUser(
        business_id=business_id,
        username=username,
        email=f"{username}@example.com",
        password_hash=hash_password("StrongPassword123!"),
        is_active=True,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(admin)
        await session.refresh(admin)

    token = create_access_token(str(admin.id))
    return admin, token

async def _create_appointment(business_id: str, status: AppointmentStatus = AppointmentStatus.PENDING) -> Appointment:
    app_date = date.today()
    apt = Appointment(
        business_id=business_id,
        customer_name="Test Customer",
        customer_phone="05551112233",
        customer_note="Some note",
        appointment_date=app_date,
        start_time=time(10, 0),
        end_time=time(10, 30),
        status=status,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(apt)
        await session.refresh(apt)
    return apt

async def _create_google_connection(business_id: str) -> GoogleCalendarConnection:
    from app.services.google_encryption import encrypt_token
    conn = GoogleCalendarConnection(
        business_id=business_id,
        google_account_email="owner@example.com",
        encrypted_refresh_token=encrypt_token("mock-refresh-token"),
        granted_scopes="calendar.events",
        is_active=True,
        token_expiry=datetime.now(timezone.utc) + timedelta(hours=1),
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(conn)
        await session.refresh(conn)
    return conn


@pytest.mark.asyncio
async def test_get_fresh_access_token_success(db_session):
    business = await _create_business()
    connection = await _create_google_connection(business.id)
    connection = await db_session.merge(connection)

    mock_resp = AsyncMock()
    mock_resp.status_code = 200
    mock_resp.json = lambda: {"access_token": "new-access-token", "expires_in": 3600}

    with patch("httpx.AsyncClient.post", return_value=mock_resp), \
         patch("app.services.google_calendar.decrypt_token", return_value="decrypted-refresh-token"):
        
        token = await GoogleCalendarService._get_fresh_access_token(db_session, connection)
        assert token == "new-access-token"
        assert connection.is_active is True


@pytest.mark.asyncio
async def test_get_fresh_access_token_revoked(db_session):
    business = await _create_business()
    connection = await _create_google_connection(business.id)
    connection = await db_session.merge(connection)

    mock_resp = AsyncMock()
    mock_resp.status_code = 400
    mock_resp.json = lambda: {"error": "invalid_grant", "error_description": "Token has been expired or revoked."}

    with patch("httpx.AsyncClient.post", return_value=mock_resp), \
         patch("app.services.google_calendar.decrypt_token", return_value="decrypted-refresh-token"):
        
        with pytest.raises(ValueError) as exc:
            await GoogleCalendarService._get_fresh_access_token(db_session, connection)
        
        assert "bağlantı izni iptal edilmiş" in str(exc.value)
        # Check connection is marked inactive in DB
        await db_session.refresh(connection)
        assert connection.is_active is False


@pytest.mark.asyncio
async def test_get_fresh_access_token_timeout(db_session):
    business = await _create_business()
    connection = await _create_google_connection(business.id)
    connection = await db_session.merge(connection)

    with patch("httpx.AsyncClient.post", side_effect=httpx.TimeoutException("Google Timeout")), \
         patch("app.services.google_calendar.decrypt_token", return_value="decrypted-refresh-token"):
        
        with pytest.raises(ValueError) as exc:
            await GoogleCalendarService._get_fresh_access_token(db_session, connection)
        
        assert "Google sunucusuna erişilemedi" in str(exc.value)


@pytest.mark.asyncio
async def test_create_calendar_event_success(db_session):
    business = await _create_business()
    connection = await _create_google_connection(business.id)
    connection = await db_session.merge(connection)
    appointment = await _create_appointment(business.id, AppointmentStatus.CONFIRMED)
    appointment = await db_session.merge(appointment)

    mock_post_resp = AsyncMock()
    mock_post_resp.status_code = 200
    mock_post_resp.json = lambda: {"id": "google-event-123"}

    with patch.object(GoogleCalendarService, "_get_fresh_access_token", return_value="fresh-access-token"), \
         patch("httpx.AsyncClient.post", return_value=mock_post_resp):
        
        event_id = await GoogleCalendarService.create_calendar_event(db_session, connection, appointment)
        assert event_id == "google-event-123"


@pytest.mark.asyncio
async def test_create_calendar_event_failure(db_session):
    business = await _create_business()
    connection = await _create_google_connection(business.id)
    connection = await db_session.merge(connection)
    appointment = await _create_appointment(business.id, AppointmentStatus.CONFIRMED)
    appointment = await db_session.merge(appointment)

    mock_post_resp = AsyncMock()
    mock_post_resp.status_code = 500
    mock_post_resp.text = "Internal Server Error at Google"

    with patch.object(GoogleCalendarService, "_get_fresh_access_token", return_value="fresh-access-token"), \
         patch("httpx.AsyncClient.post", return_value=mock_post_resp):
        
        with pytest.raises(ValueError) as exc:
            await GoogleCalendarService.create_calendar_event(db_session, connection, appointment)
        assert "Google Takvim etkinliği oluşturulamadı" in str(exc.value)
        # Ensure credentials/tokens are not leaked in the error
        assert "fresh-access-token" not in str(exc.value)
        assert "some-encrypted-token" not in str(exc.value)


@pytest.mark.asyncio
async def test_delete_calendar_event_success_and_idempotency(db_session):
    business = await _create_business()
    connection = await _create_google_connection(business.id)
    connection = await db_session.merge(connection)

    # 1. Success delete (HTTP 204 or 200)
    mock_delete_ok = AsyncMock()
    mock_delete_ok.status_code = 204

    with patch.object(GoogleCalendarService, "_get_fresh_access_token", return_value="fresh-access-token"), \
         patch("httpx.AsyncClient.delete", return_value=mock_delete_ok) as mock_delete:
        
        await GoogleCalendarService.delete_calendar_event(db_session, connection, "event-id-123")
        mock_delete.assert_called_once()

    # 2. Idempotent delete (Google returns 404 because event is already deleted)
    mock_delete_404 = AsyncMock()
    mock_delete_404.status_code = 404

    with patch.object(GoogleCalendarService, "_get_fresh_access_token", return_value="fresh-access-token"), \
         patch("httpx.AsyncClient.delete", return_value=mock_delete_404) as mock_delete_2:
        
        # Should not raise exception
        await GoogleCalendarService.delete_calendar_event(db_session, connection, "event-id-123")
        mock_delete_2.assert_called_once()


@pytest.mark.asyncio
async def test_status_transition_confirm_with_google_active(db_session):
    """Transition PENDING -> CONFIRMED with an active connection creates the event."""
    business = await _create_business()
    await _create_google_connection(business.id)
    appointment = await _create_appointment(business.id, AppointmentStatus.PENDING)

    from app.services.admin_appointment_service import change_appointment_status
    
    mock_find = AsyncMock(return_value=None)
    mock_create = AsyncMock(return_value="google-event-123")

    with patch.object(GoogleCalendarService, "find_existing_event_by_extended_property", mock_find), \
         patch.object(GoogleCalendarService, "create_calendar_event", mock_create):
        
        updated = await change_appointment_status(
            db_session, business_id=business.id, appointment_id=appointment.id, target_status=AppointmentStatus.CONFIRMED
        )

        assert updated.status == AppointmentStatus.CONFIRMED
        assert updated.google_calendar_event_id == "google-event-123"
        assert updated.google_calendar_sync_status == GoogleCalendarSyncStatus.SYNCED
        assert updated.calendar_sync_status == "synced"
        assert updated.calendar_event_created is True


@pytest.mark.asyncio
async def test_status_transition_confirm_without_google_connection(db_session):
    """Transition PENDING -> CONFIRMED with no Google Connection succeeds but marks sync as not_connected."""
    business = await _create_business()
    appointment = await _create_appointment(business.id, AppointmentStatus.PENDING)

    from app.services.admin_appointment_service import change_appointment_status

    updated = await change_appointment_status(
        db_session, business_id=business.id, appointment_id=appointment.id, target_status=AppointmentStatus.CONFIRMED
    )

    assert updated.status == AppointmentStatus.CONFIRMED
    assert updated.google_calendar_event_id is None
    assert updated.google_calendar_sync_status == GoogleCalendarSyncStatus.NOT_CONNECTED
    assert updated.calendar_sync_status == "not_connected"
    assert updated.calendar_event_created is False


@pytest.mark.asyncio
async def test_status_transition_confirm_google_fails(db_session):
    """Transition PENDING -> CONFIRMED fails on Google Calendar API, but appointment confirmation is still successful."""
    business = await _create_business()
    await _create_google_connection(business.id)
    appointment = await _create_appointment(business.id, AppointmentStatus.PENDING)

    from app.services.admin_appointment_service import change_appointment_status

    mock_find = AsyncMock(return_value=None)
    mock_create = AsyncMock(side_effect=ValueError("Google Calendar API is offline"))

    with patch.object(GoogleCalendarService, "find_existing_event_by_extended_property", mock_find), \
         patch.object(GoogleCalendarService, "create_calendar_event", mock_create):
        
        updated = await change_appointment_status(
            db_session, business_id=business.id, appointment_id=appointment.id, target_status=AppointmentStatus.CONFIRMED
        )

        # Appointment status transition must succeed
        assert updated.status == AppointmentStatus.CONFIRMED
        # Sync status is failed, error is stored
        assert updated.google_calendar_sync_status == GoogleCalendarSyncStatus.FAILED
        assert "Google Calendar API is offline" in updated.google_calendar_last_error
        assert updated.calendar_sync_status == "failed"


@pytest.mark.asyncio
async def test_status_transition_cancel_success(db_session):
    """Transition CONFIRMED -> CANCELLED deletes the event if it exists."""
    business = await _create_business()
    await _create_google_connection(business.id)
    appointment = await _create_appointment(business.id, AppointmentStatus.CONFIRMED)
    appointment = await db_session.merge(appointment)
    
    # Save dummy event id first
    appointment.google_calendar_event_id = "some-event-id"
    appointment.google_calendar_sync_status = GoogleCalendarSyncStatus.SYNCED
    await db_session.commit()

    from app.services.admin_appointment_service import change_appointment_status

    mock_delete = AsyncMock()
    with patch.object(GoogleCalendarService, "delete_calendar_event", mock_delete):
        updated = await change_appointment_status(
            db_session, business_id=business.id, appointment_id=appointment.id, target_status=AppointmentStatus.CANCELLED
        )

        assert updated.status == AppointmentStatus.CANCELLED
        assert updated.google_calendar_sync_status == GoogleCalendarSyncStatus.DELETED
        mock_delete.assert_called_once()


@pytest.mark.asyncio
async def test_status_transition_cancel_google_fails(db_session):
    """Transition CONFIRMED -> CANCELLED fails on Google API, but DB cancellation still succeeds and marked as failed sync."""
    business = await _create_business()
    await _create_google_connection(business.id)
    appointment = await _create_appointment(business.id, AppointmentStatus.CONFIRMED)
    appointment = await db_session.merge(appointment)
    appointment.google_calendar_event_id = "some-event-id"
    appointment.google_calendar_sync_status = GoogleCalendarSyncStatus.SYNCED
    await db_session.commit()

    from app.services.admin_appointment_service import change_appointment_status

    mock_delete = AsyncMock(side_effect=ValueError("Google Calendar delete timed out"))
    with patch.object(GoogleCalendarService, "delete_calendar_event", mock_delete):
        updated = await change_appointment_status(
            db_session, business_id=business.id, appointment_id=appointment.id, target_status=AppointmentStatus.CANCELLED
        )

        assert updated.status == AppointmentStatus.CANCELLED
        assert updated.google_calendar_sync_status == GoogleCalendarSyncStatus.FAILED
        assert "Google Calendar delete timed out" in updated.google_calendar_last_error


@pytest.mark.asyncio
async def test_manual_sync_endpoint_success(client: AsyncClient, db_session):
    business = await _create_business()
    admin_user, token = await _create_admin(business.id)
    await _create_google_connection(business.id)
    appointment = await _create_appointment(business.id, AppointmentStatus.CONFIRMED)

    headers = {"Authorization": f"Bearer {token}"}

    mock_find = AsyncMock(return_value=None)
    mock_create = AsyncMock(return_value="google-event-new")

    with patch.object(GoogleCalendarService, "find_existing_event_by_extended_property", mock_find), \
         patch.object(GoogleCalendarService, "create_calendar_event", mock_create):
        
        resp = await client.post(
            f"/api/v1/admin/appointments/{appointment.id}/google-calendar/sync",
            headers=headers
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["calendar_sync_status"] == "synced"
        assert data["calendar_event_created"] is True


@pytest.mark.asyncio
async def test_manual_sync_endpoint_unauthorized(client: AsyncClient):
    resp = await client.post(
        f"/api/v1/admin/appointments/{uuid4()}/google-calendar/sync"
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_manual_sync_endpoint_wrong_business(client: AsyncClient, db_session):
    business_1 = await _create_business()
    admin_user_1, token_1 = await _create_admin(business_1.id)

    business_2 = await _create_business()
    appointment_2 = await _create_appointment(business_2.id, AppointmentStatus.CONFIRMED)

    headers = {"Authorization": f"Bearer {token_1}"}

    resp = await client.post(
        f"/api/v1/admin/appointments/{appointment_2.id}/google-calendar/sync",
        headers=headers
    )
    assert resp.status_code == 404  # Cannot find appointment belonging to business_1


@pytest.mark.asyncio
async def test_manual_sync_endpoint_pending_not_allowed(client: AsyncClient, db_session):
    business = await _create_business()
    admin_user, token = await _create_admin(business.id)
    await _create_google_connection(business.id)
    appointment = await _create_appointment(business.id, AppointmentStatus.PENDING)

    headers = {"Authorization": f"Bearer {token}"}

    resp = await client.post(
        f"/api/v1/admin/appointments/{appointment.id}/google-calendar/sync",
        headers=headers
    )
    assert resp.status_code == 400
    assert "Bekleyen randevular" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_manual_sync_endpoint_missing_connection(client: AsyncClient, db_session):
    business = await _create_business()
    admin_user, token = await _create_admin(business.id)
    appointment = await _create_appointment(business.id, AppointmentStatus.CONFIRMED)

    headers = {"Authorization": f"Bearer {token}"}

    resp = await client.post(
        f"/api/v1/admin/appointments/{appointment.id}/google-calendar/sync",
        headers=headers
    )
    assert resp.status_code == 400
    assert "Aktif bir Google Takvim bağlantısı bulunmamaktadır" in resp.json()["detail"]
