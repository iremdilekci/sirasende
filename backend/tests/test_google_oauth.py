import hashlib
import json
import os
from datetime import datetime, time, timedelta, timezone
from pathlib import Path
from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models import AdminUser, Business
from app.models.google_calendar_connection import GoogleCalendarConnection, GoogleOAuthState
from app.services.google_encryption import decrypt_token, encrypt_token
from app.services.google_oauth import GoogleOAuthService

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
        description="Demo business description",
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


def test_encryption_decryption_success():
    """Verify refresh token encryption and decryption."""
    token = "ya29.a0AfB_byE5..."
    encrypted = encrypt_token(token)
    assert encrypted != token
    decrypted = decrypt_token(encrypted)
    assert decrypted == token


def test_decryption_invalid_key(monkeypatch):
    """Verify that using an invalid key throws ValueError and does not leak token content."""
    token = "secret-refresh-token"
    # Set an invalid key (must be 32 urlsafe base64-encoded bytes)
    monkeypatch.setattr(settings, "google_token_encryption_key", "invalid-key-length")
    
    with pytest.raises(ValueError) as exc:
        encrypt_token(token)
    assert "Invalid GOOGLE_TOKEN_ENCRYPTION_KEY" in str(exc.value)
    assert token not in str(exc.value)


def test_decryption_corrupted_ciphertext():
    """Verify that decrypting corrupted ciphertext raises ValueError and does not leak info."""
    with pytest.raises(ValueError) as exc:
        decrypt_token("invalid-ciphertext")
    assert "Failed to decrypt token" in str(exc.value)


@pytest.mark.asyncio
async def test_state_creation_and_consumption(db_session):
    """Verify that OAuth state is generated, resolved, and consumed properly."""
    business = await _create_business()

    # Create authorization url
    auth_url = await GoogleOAuthService.create_auth_url(db_session, business.id)
    assert "state=" in auth_url

    # Extract state token
    parts = auth_url.split("state=")
    state_token = parts[1].split("&")[0]

    # Resolve callback
    state_hash = hashlib.sha256(state_token.encode("utf-8")).hexdigest()
    stmt = select(GoogleOAuthState).where(GoogleOAuthState.state_hash == state_hash)
    db_state = (await db_session.execute(stmt)).scalars().first()

    assert db_state is not None
    assert db_state.business_id == business.id
    assert db_state.used_at is None
    assert db_state.expires_at > datetime.now(timezone.utc)

    # Let's mock token exchange and user info request to handle callback
    mock_exchange = AsyncMock(return_value={
        "access_token": "mock-access-token",
        "refresh_token": "mock-refresh-token",
        "expires_in": 3600,
        "scope": "calendar.events",
    })
    mock_email = AsyncMock(return_value="test@example.com")

    with patch.object(GoogleOAuthService, "_exchange_code", mock_exchange), \
         patch.object(GoogleOAuthService, "_fetch_google_email", mock_email):
        
        conn, email = await GoogleOAuthService.handle_callback(
            db_session, state_token=state_token, code="mock-code"
        )
        assert conn.business_id == business.id
        assert email == "test@example.com"
        assert conn.google_account_email == "test@example.com"

        # Check state consumed
        await db_session.refresh(db_state)
        assert db_state.used_at is not None

        # Re-consuming the same state token should fail
        with pytest.raises(ValueError) as exc:
            await GoogleOAuthService.handle_callback(
                db_session, state_token=state_token, code="mock-code-2"
            )
        assert "zaten kullanılmış" in str(exc.value)


@pytest.mark.asyncio
async def test_state_expired(db_session):
    """Verify expired states are rejected."""
    business = await _create_business()
    state_token = "some-expired-token"
    state_hash = hashlib.sha256(state_token.encode("utf-8")).hexdigest()

    expired_state = GoogleOAuthState(
        state_hash=state_hash,
        business_id=business.id,
        expires_at=datetime.now(timezone.utc) - timedelta(seconds=1),
    )
    db_session.add(expired_state)
    await db_session.commit()

    with pytest.raises(ValueError) as exc:
        await GoogleOAuthService.handle_callback(
            db_session, state_token=state_token, code="mock-code"
        )
    assert "süresi doldu" in str(exc.value)


@pytest.mark.asyncio
async def test_invalid_state(db_session):
    """Verify invalid state tokens are rejected."""
    with pytest.raises(ValueError) as exc:
        await GoogleOAuthService.handle_callback(
            db_session, state_token="invalid-non-existent-state", code="mock-code"
        )
    assert "Geçersiz yetkilendirme durumu" in str(exc.value)


@pytest.mark.asyncio
async def test_google_oauth_endpoints(client: AsyncClient, db_session):
    """Verify v1 API endpoints for Google Calendar OAuth."""
    business = await _create_business()
    admin_user, token = await _create_admin(business.id)
    admin_headers = {"Authorization": f"Bearer {token}"}

    # 1. Unauthenticated requests should yield 401 Unauthorized
    resp = await client.get("/api/v1/admin/google-calendar/status")
    assert resp.status_code == 401

    resp = await client.post("/api/v1/admin/google-calendar/connect")
    assert resp.status_code == 401

    resp = await client.delete("/api/v1/admin/google-calendar/connection")
    assert resp.status_code == 401

    # 2. Check connection status (should be disconnected initially)
    resp = await client.get("/api/v1/admin/google-calendar/status", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["connected"] is False
    assert data["google_account_email"] is None

    # 3. Request connect link
    resp = await client.post("/api/v1/admin/google-calendar/connect", headers=admin_headers)
    assert resp.status_code == 200
    connect_data = resp.json()
    assert "authorization_url" in connect_data
    assert "accounts.google.com" in connect_data["authorization_url"]

    # Extract state token
    parts = connect_data["authorization_url"].split("state=")
    state_token = parts[1].split("&")[0]

    # 4. Callback redirect handling (Mocked exchange)
    mock_exchange = AsyncMock(return_value={
        "access_token": "mock-access",
        "refresh_token": "mock-refresh",
        "expires_in": 3600,
        "scope": "calendar.events",
    })
    mock_email = AsyncMock(return_value="owner@example.com")

    with patch.object(GoogleOAuthService, "_exchange_code", mock_exchange), \
         patch.object(GoogleOAuthService, "_fetch_google_email", mock_email):
        
        callback_resp = await client.get(
            f"/api/v1/admin/google-calendar/callback?code=mockcode&state={state_token}"
        )
        assert callback_resp.status_code == 307  # Redirect response
        assert "sirasende://google-calendar/callback" in callback_resp.headers["location"]
        assert "status=success" in callback_resp.headers["location"]

    # 5. Connect status should now be connected
    resp = await client.get("/api/v1/admin/google-calendar/status", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["connected"] is True
    assert data["google_account_email"] == "owner@example.com"
    assert "calendar.events" in data["granted_scopes"]

    # 6. Disconnect connection
    mock_revoke = AsyncMock()
    with patch.object(GoogleOAuthService, "_revoke_token", mock_revoke):
        resp = await client.delete("/api/v1/admin/google-calendar/connection", headers=admin_headers)
        assert resp.status_code == 200
        assert "kaldırıldı" in resp.json()["message"]
        mock_revoke.assert_called_once()

    # 7. Disconnect idempotency (should succeed/not error when already disconnected)
    resp = await client.delete("/api/v1/admin/google-calendar/connection", headers=admin_headers)
    assert resp.status_code == 200
    assert "bulunmamaktadır" in resp.json()["message"]

    # 8. Connection status is now false again
    resp = await client.get("/api/v1/admin/google-calendar/status", headers=admin_headers)
    assert resp.status_code == 200
    assert resp.json()["connected"] is False
