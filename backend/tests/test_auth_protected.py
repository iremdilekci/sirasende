from datetime import time
import os
from pathlib import Path
import pytest
import time as time_module
import jwt
from uuid import uuid4
from alembic import command
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete

from app.core.database import async_session_factory
from app.main import app
from app.models import AdminUser, Business
from app.core.security import hash_password, create_access_token
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
        name="Protected Test Business",
        slug=f"protected-test-{uuid4().hex[:8]}",
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
        username=f"act_admin_{uuid4().hex[:6]}",
        email=f"act_admin_{uuid4().hex[:6]}@example.com",
        password_hash=hash_password("SecurePass123!"),
        is_active=True,
    )
    session.add(active_admin)

    # 3. Create an inactive admin user
    inactive_admin = AdminUser(
        business_id=b.id,
        username=f"inact_admin_{uuid4().hex[:6]}",
        email=f"inact_admin_{uuid4().hex[:6]}@example.com",
        password_hash=hash_password("SecurePass123!"),
        is_active=False,
    )
    session.add(inactive_admin)

    await session.commit()
    await session.refresh(active_admin)
    await session.refresh(inactive_admin)
    return b, active_admin, inactive_admin


def _assert_unauthorized(response) -> None:
    """Helper to verify that a response is a standard 401 credentials error."""
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"
    assert response.json() == {"detail": "Could not validate credentials"}


async def test_auth_me_success_with_valid_token(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        b, active_user, _ = await _create_demo_data(session)

    token = create_access_token(active_user.id)
    headers = {"Authorization": f"Bearer {token}"}
    
    response = await client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 200
    data = response.json()

    # Verify exactly the expected fields
    assert set(data) == {
        "id",
        "business_id",
        "username",
        "email",
        "is_active",
    }
    assert data["id"] == str(active_user.id)
    assert data["business_id"] == str(b.id)
    assert data["username"] == active_user.username
    assert data["email"] == active_user.email
    assert data["is_active"] is True
    assert "password_hash" not in data


async def test_auth_me_no_header_returns_401(client: AsyncClient) -> None:
    response = await client.get("/api/v1/auth/me")
    _assert_unauthorized(response)


async def test_auth_me_basic_auth_returns_401(client: AsyncClient) -> None:
    headers = {"Authorization": "Basic dGVzdDp0ZXN0"}
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_empty_bearer_returns_401(client: AsyncClient) -> None:
    headers = {"Authorization": "Bearer "}
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_malformed_token_returns_401(client: AsyncClient) -> None:
    headers = {"Authorization": "Bearer malformed.jwt.token"}
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_expired_token_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    # 10 seconds in past
    to_encode = {
        "sub": str(active_user.id),
        "iat": int(time_module.time()) - 30,
        "exp": int(time_module.time()) - 10,
        "type": "access",
    }
    expired_token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    headers = {"Authorization": f"Bearer {expired_token}"}
    
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_inactive_user_token_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, _, inactive_user = await _create_demo_data(session)

    token = create_access_token(inactive_user.id)
    headers = {"Authorization": f"Bearer {token}"}
    
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_deleted_user_token_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)
        # Delete user
        await session.execute(delete(AdminUser).where(AdminUser.id == active_user.id))
        await session.commit()

    token = create_access_token(active_user.id)
    headers = {"Authorization": f"Bearer {token}"}
    
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_token_sub_missing_returns_401(client: AsyncClient) -> None:
    to_encode = {
        "exp": int(time_module.time()) + 60,
        "type": "access",
    }
    invalid_token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    headers = {"Authorization": f"Bearer {invalid_token}"}

    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_token_sub_empty_string_returns_401(client: AsyncClient) -> None:
    to_encode = {
        "sub": "   ",
        "exp": int(time_module.time()) + 60,
        "type": "access",
    }
    invalid_token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    headers = {"Authorization": f"Bearer {invalid_token}"}

    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_token_sub_not_uuid_returns_401(client: AsyncClient) -> None:
    to_encode = {
        "sub": "some-non-uuid-string",
        "exp": int(time_module.time()) + 60,
        "type": "access",
    }
    invalid_token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    headers = {"Authorization": f"Bearer {invalid_token}"}

    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_token_type_missing_returns_401(client: AsyncClient) -> None:
    to_encode = {
        "sub": str(uuid4()),
        "exp": int(time_module.time()) + 60,
    }
    invalid_token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    headers = {"Authorization": f"Bearer {invalid_token}"}

    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_token_wrong_algorithm_returns_401(client: AsyncClient) -> None:
    to_encode = {
        "sub": str(uuid4()),
        "exp": int(time_module.time()) + 60,
        "type": "access",
    }
    invalid_token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm="HS384")
    headers = {"Authorization": f"Bearer {invalid_token}"}

    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_wrong_secret_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    token = jwt.encode(
        {
            "sub": str(active_user.id),
            "type": "access",
            "exp": int(time_module.time()) + 60,
        },
        "completely-different-wrong-secret-key-123456789",
        algorithm=settings.jwt_algorithm
    )
    headers = {"Authorization": f"Bearer {token}"}
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_missing_exp_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    token = jwt.encode(
        {
            "sub": str(active_user.id),
            "type": "access",
        },
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm
    )
    headers = {"Authorization": f"Bearer {token}"}
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_wrong_token_type_returns_401(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    token = jwt.encode(
        {
            "sub": str(active_user.id),
            "type": "refresh",
            "exp": int(time_module.time()) + 60,
        },
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm
    )
    headers = {"Authorization": f"Bearer {token}"}
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_lowercase_bearer_returns_200(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    token = create_access_token(active_user.id)
    headers = {"Authorization": f"bearer {token}"}
    response = await client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 200


async def test_auth_me_uppercase_bearer_returns_200(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, _ = await _create_demo_data(session)

    token = create_access_token(active_user.id)
    headers = {"Authorization": f"BEARER {token}"}
    response = await client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 200


async def test_auth_me_multipart_token_header_returns_401(client: AsyncClient) -> None:
    headers = {"Authorization": "Bearer token extra parts"}
    response = await client.get("/api/v1/auth/me", headers=headers)
    _assert_unauthorized(response)


async def test_auth_me_failed_responses_are_completely_identical(client: AsyncClient) -> None:
    async with async_session_factory() as session:
        _, active_user, inactive_user = await _create_demo_data(session)
        # Delete active user to simulate deleted state
        await session.execute(delete(AdminUser).where(AdminUser.id == active_user.id))
        await session.commit()

    # 1. Inactive user token
    token_inactive = create_access_token(inactive_user.id)
    r1 = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token_inactive}"})

    # 2. Deleted user token
    token_deleted = create_access_token(active_user.id)
    r2 = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token_deleted}"})

    # 3. Malformed token
    r3 = await client.get("/api/v1/auth/me", headers={"Authorization": "Bearer malformed.jwt.token"})

    for r in [r1, r2, r3]:
        _assert_unauthorized(r)
