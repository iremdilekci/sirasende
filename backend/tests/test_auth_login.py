from datetime import time
import os
from pathlib import Path
import pytest
from uuid import uuid4
import jwt
from alembic import command
from alembic.config import Config
from httpx import ASGITransport, AsyncClient

from app.core.database import async_session_factory
from app.main import app
from app.models import AdminUser, Business
from app.core.security import hash_password, decode_access_token
from app.core.config import settings


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
async def client() -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client


async def _create_demo_data(session) -> tuple[Business, AdminUser, AdminUser]:
    # 1. Create a business
    b = Business(
        name="Auth Test Business",
        slug=f"auth-test-{uuid4().hex[:8]}",
        working_start_time=time(9, 0),
        working_end_time=time(18, 0),
        slot_duration_minutes=30,
        is_active=True,
    )
    session.add(b)
    await session.flush()

    # 2. Create an active admin user
    active_admin = AdminUser(
        business_id=b.id,
        username=f"act_adm_{uuid4().hex[:6]}",
        email=f"act_adm_{uuid4().hex[:6]}@example.com",
        password_hash=hash_password("SecurePass123!"),
        is_active=True,
    )
    session.add(active_admin)

    # 3. Create an inactive admin user
    inactive_admin = AdminUser(
        business_id=b.id,
        username=f"inact_adm_{uuid4().hex[:6]}",
        email=f"inact_adm_{uuid4().hex[:6]}@example.com",
        password_hash=hash_password("SecurePass123!"),
        is_active=False,
    )
    session.add(inactive_admin)

    await session.commit()
    await session.refresh(active_admin)
    await session.refresh(inactive_admin)
    return b, active_admin, inactive_admin


async def test_login_success_by_username(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    payload = {
        "identifier": active_user.username,
        "password": "SecurePass123!"
    }
    
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 200
    data = response.json()

    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["expires_in"] == settings.jwt_access_token_expire_minutes * 60

    # Decode and verify the JWT access token content
    payload_decoded = decode_access_token(data["access_token"])
    assert payload_decoded["sub"] == str(active_user.id)
    assert payload_decoded["type"] == "access"
    assert "exp" in payload_decoded
    assert "iat" in payload_decoded


async def test_login_success_by_email(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    payload = {
        "identifier": active_user.email,
        "password": "SecurePass123!"
    }
    
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 200
    data = response.json()

    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["expires_in"] == settings.jwt_access_token_expire_minutes * 60

    # Verify the token can be decoded correctly
    payload_decoded = decode_access_token(data["access_token"])
    assert payload_decoded["sub"] == str(active_user.id)


async def test_login_identifier_strips_whitespace(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    payload = {
        "identifier": f"   {active_user.email}   ",
        "password": "SecurePass123!"
    }
    
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data


async def test_login_password_preserves_spaces(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        # Create a business
        b = Business(
            name="Spaces Business",
            slug=f"spaces-{uuid4().hex[:8]}",
            working_start_time=time(9, 0),
            working_end_time=time(18, 0),
            slot_duration_minutes=30,
            is_active=True,
        )
        session.add(b)
        await session.flush()

        # Create user with leading and trailing spaces in password
        spaced_user = AdminUser(
            business_id=b.id,
            username=f"spaced_{uuid4().hex[:6]}",
            email=f"spaced_{uuid4().hex[:6]}@example.com",
            password_hash=hash_password("  SpacedPass123!  "),
            is_active=True,
        )
        session.add(spaced_user)
        await session.commit()
        await session.refresh(spaced_user)

    # 1. Login with correct password preserving spaces -> should succeed
    payload_correct = {
        "identifier": spaced_user.username,
        "password": "  SpacedPass123!  "
    }
    response_correct = await client.post("/api/v1/auth/login", json=payload_correct)
    assert response_correct.status_code == 200
    assert "access_token" in response_correct.json()

    # 2. Login with stripped password -> should fail
    payload_stripped = {
        "identifier": spaced_user.username,
        "password": "SpacedPass123!"
    }
    response_stripped = await client.post("/api/v1/auth/login", json=payload_stripped)
    assert response_stripped.status_code == 401
    assert "access_token" not in response_stripped.json()


async def test_login_wrong_username_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    payload = {
        "identifier": "non_existent_username",
        "password": "SecurePass123!"
    }
    
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.json()["detail"] == "Could not validate credentials"
    assert "access_token" not in response.json()


async def test_login_wrong_email_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    payload = {
        "identifier": "wrong_email@example.com",
        "password": "SecurePass123!"
    }
    
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.json()["detail"] == "Could not validate credentials"
    assert "access_token" not in response.json()


async def test_login_wrong_password_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    payload = {
        "identifier": active_user.username,
        "password": "WrongPassword123!"
    }
    
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.json()["detail"] == "Could not validate credentials"
    assert "access_token" not in response.json()


async def test_login_inactive_user_returns_401_mitigates_enumeration(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, _, inactive_user = await _create_demo_data(session)

    payload = {
        "identifier": inactive_user.username,
        "password": "SecurePass123!"
    }
    
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.json()["detail"] == "Could not validate credentials"
    assert "access_token" not in response.json()


async def test_login_empty_identifier_whitespace_only_returns_422(client: AsyncClient) -> None:
    payload = {
        "identifier": "    ",
        "password": "SecurePass123!"
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 422


async def test_login_empty_password_returns_422(client: AsyncClient) -> None:
    payload = {
        "identifier": "active_admin_user",
        "password": ""
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 422


async def test_login_whitespace_only_password_returns_401(client: AsyncClient) -> None:
    payload = {
        "identifier": "active_admin_user",
        "password": "    "
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 401
    assert response.json()["detail"] == "Could not validate credentials"


async def test_login_missing_identifier_field_returns_422(client: AsyncClient) -> None:
    payload = {
        "password": "SecurePass123!"
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 422


async def test_login_missing_password_field_returns_422(client: AsyncClient) -> None:
    payload = {
        "identifier": "active_admin_user"
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 422


async def test_login_empty_string_identifier_returns_422(client: AsyncClient) -> None:
    payload = {
        "identifier": "",
        "password": "SecurePass123!"
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 422


async def test_login_extra_fields_returns_422(client: AsyncClient) -> None:
    payload = {
        "identifier": "active_admin_user",
        "password": "SecurePass123!",
        "extra_field": "not_allowed"
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 422


async def test_login_very_long_identifier_returns_422(client: AsyncClient) -> None:
    payload = {
        "identifier": "a" * 1000,
        "password": "SecurePass123!"
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 422


async def test_login_invalid_data_type_returns_422(client: AsyncClient) -> None:
    payload = {
        "identifier": ["invalid_type_list"],
        "password": "SecurePass123!"
    }
    response = await client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 422


async def test_login_failed_credential_responses_are_identical(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, inactive_user = await _create_demo_data(session)

    # 1. Non-existent username
    r1 = await client.post("/api/v1/auth/login", json={"identifier": "doesnotexist", "password": "SecurePass123!"})
    # 2. Non-existent email
    r2 = await client.post("/api/v1/auth/login", json={"identifier": "notexist@example.com", "password": "SecurePass123!"})
    # 3. Wrong password
    r3 = await client.post("/api/v1/auth/login", json={"identifier": active_user.username, "password": "WrongPassword!"})
    # 4. Inactive user
    r4 = await client.post("/api/v1/auth/login", json={"identifier": inactive_user.username, "password": "SecurePass123!"})

    for r in [r1, r2, r3, r4]:
        assert r.status_code == 401
        assert r.headers["WWW-Authenticate"] == "Bearer"
        assert r.json() == {"detail": "Could not validate credentials"}


async def test_login_cross_identifier_collision(client: AsyncClient) -> None:
    collision_identifier = "collision@example.com"
    
    async with async_session_factory() as session:
        # Create business
        b = Business(
            name="Collision Business",
            slug=f"collision-{uuid4().hex[:8]}",
            working_start_time=time(9, 0),
            working_end_time=time(18, 0),
            slot_duration_minutes=30,
            is_active=True,
        )
        session.add(b)
        await session.flush()

        # User A has username = collision_identifier
        user_a = AdminUser(
            business_id=b.id,
            username=collision_identifier,
            email=f"usera_{uuid4().hex[:6]}@example.com",
            password_hash=hash_password("PasswordA123!"),
            is_active=True,
        )
        session.add(user_a)

        # User B has email = collision_identifier
        user_b = AdminUser(
            business_id=b.id,
            username=f"userb_{uuid4().hex[:6]}",
            email=collision_identifier,
            password_hash=hash_password("PasswordB123!"),
            is_active=True,
        )
        session.add(user_b)
        await session.commit()

    # Try logging in with the collision identifier and PasswordA123! -> must fail with 401
    payload_a = {"identifier": collision_identifier, "password": "PasswordA123!"}
    res_a = await client.post("/api/v1/auth/login", json=payload_a)
    assert res_a.status_code == 401
    assert res_a.json() == {"detail": "Could not validate credentials"}
    assert "access_token" not in res_a.json()

    # Try logging in with the collision identifier and PasswordB123! -> must fail with 401
    payload_b = {"identifier": collision_identifier, "password": "PasswordB123!"}
    res_b = await client.post("/api/v1/auth/login", json=payload_b)
    assert res_b.status_code == 401
    assert res_b.json() == {"detail": "Could not validate credentials"}
    assert "access_token" not in res_b.json()
