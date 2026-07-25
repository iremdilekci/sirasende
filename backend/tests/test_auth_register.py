from datetime import time
import os
from pathlib import Path
import pytest
from uuid import uuid4, UUID
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.core.database import async_session_factory
from app.main import app
from app.models import AdminUser, Business, BusinessSchedule
from app.core.security import verify_password
from app.core.exceptions import RegistrationConflictError
from app.services.auth_service import register_business_and_admin
from app.schemas.auth import AdminRegistrationRequest

pytestmark = [
    pytest.mark.postgres,
    pytest.mark.skipif(
        os.getenv("RUN_POSTGRES_TESTS") != "1",
        reason="Set RUN_POSTGRES_TESTS=1 with a disposable PostgreSQL database",
    ),
]

BACKEND_DIR = Path(__file__).resolve().parents[1]


def _alembic_config() -> "Config":
    from alembic.config import Config
    return Config(str(BACKEND_DIR / "alembic.ini"))


@pytest.fixture(scope="module", autouse=True)
def migrated_database() -> None:
    from alembic import command
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


async def test_register_success(client: AsyncClient) -> None:
    payload = {
        "username": "test_merchant",
        "email": "test@merchant.com",
        "password": "SecurePassword123",
        "business_name": "Test Kuafor",
        "phone": "5551234567",
        "address": "Istanbul, TR",
        "description": "Premium Hair Salon",
        "slot_duration_minutes": 30,
    }

    response = await client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()

    assert "admin_id" in data
    assert "business_id" in data
    assert data["username"] == "test_merchant"
    assert data["email"] == "test@merchant.com"
    assert data["business_name"] == "Test Kuafor"
    assert "message" in data
    assert "password" not in data
    assert "password_hash" not in data
    assert "access_token" not in data

    # Verify database persistence
    async with async_session_factory() as session:
        # Check AdminUser
        admin = await session.scalar(
            select(AdminUser).where(AdminUser.id == UUID(data["admin_id"]))
        )
        assert admin is not None
        assert admin.username == "test_merchant"
        assert verify_password("SecurePassword123", admin.password_hash)

        # Check Business
        business = await session.scalar(
            select(Business).where(Business.id == UUID(data["business_id"]))
        )
        assert business is not None
        assert business.name == "Test Kuafor"
        assert business.slug == "test-kuafor"
        assert business.phone == "5551234567"

        # Check BusinessSchedules
        schedules = (
            await session.scalars(
                select(BusinessSchedule).where(BusinessSchedule.business_id == business.id)
            )
        ).all()
        assert len(schedules) == 7
        for s in schedules:
            assert s.start_time == time(9, 0)
            assert s.end_time == time(18, 0)
            assert s.is_closed is False


async def test_register_normalization(client: AsyncClient) -> None:
    payload = {
        "username": "  New_Merchant  ",
        "email": "  NEW@MERCHANT.COM  ",
        "password": "SecurePassword123",
        "business_name": "  Normalizing Business  ",
        "slot_duration_minutes": 45,
    }

    response = await client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()

    assert data["username"] == "new_merchant"
    assert data["email"] == "new@merchant.com"
    assert data["business_name"] == "Normalizing Business"


async def test_register_duplicate_username_case_insensitive(client: AsyncClient) -> None:
    # Setup initial merchant
    payload1 = {
        "username": "duplicate_user",
        "email": "unique1@mail.com",
        "password": "SecurePassword123",
        "business_name": "Business 1",
        "slot_duration_minutes": 30,
    }
    await client.post("/api/v1/auth/register", json=payload1)

    # Attempt registration with duplicate username differing only by case
    payload2 = {
        "username": "DUPLICATE_USER",
        "email": "unique2@mail.com",
        "password": "SecurePassword123",
        "business_name": "Business 2",
        "slot_duration_minutes": 30,
    }
    response = await client.post("/api/v1/auth/register", json=payload2)
    assert response.status_code == 409
    assert "zaten alınmış" in response.json()["detail"]


async def test_register_duplicate_email_case_insensitive(client: AsyncClient) -> None:
    # Setup initial merchant
    payload1 = {
        "username": "user1",
        "email": "dup@mail.com",
        "password": "SecurePassword123",
        "business_name": "Business 1",
        "slot_duration_minutes": 30,
    }
    await client.post("/api/v1/auth/register", json=payload1)

    # Attempt registration with duplicate email differing only by case
    payload2 = {
        "username": "user2",
        "email": "DUP@MAIL.COM",
        "password": "SecurePassword123",
        "business_name": "Business 2",
        "slot_duration_minutes": 30,
    }
    response = await client.post("/api/v1/auth/register", json=payload2)
    assert response.status_code == 409
    assert "zaten alınmış" in response.json()["detail"]


async def test_register_validation_errors(client: AsyncClient) -> None:
    # Invalid username (special characters)
    payload = {
        "username": "invalid-user!",
        "email": "valid@email.com",
        "password": "SecurePassword123",
        "business_name": "Name",
        "slot_duration_minutes": 30,
    }
    response = await client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 422

    # Weak password (no digit)
    payload = {
        "username": "validuser",
        "email": "valid@email.com",
        "password": "NoDigitPassword",
        "business_name": "Name",
        "slot_duration_minutes": 30,
    }
    response = await client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 422


async def test_slug_collision_handling(client: AsyncClient) -> None:
    # First shop
    payload1 = {
        "username": "shopowner1",
        "email": "shop1@owner.com",
        "password": "SecurePassword123",
        "business_name": "Kuafor Salonu",
        "slot_duration_minutes": 30,
    }
    res1 = await client.post("/api/v1/auth/register", json=payload1)
    assert res1.status_code == 201
    business_id1 = UUID(res1.json()["business_id"])

    # Second shop with same name
    payload2 = {
        "username": "shopowner2",
        "email": "shop2@owner.com",
        "password": "SecurePassword123",
        "business_name": "Kuafor Salonu",
        "slot_duration_minutes": 30,
    }
    res2 = await client.post("/api/v1/auth/register", json=payload2)
    assert res2.status_code == 201
    business_id2 = UUID(res2.json()["business_id"])

    async with async_session_factory() as session:
        b1 = await session.scalar(select(Business).where(Business.id == business_id1))
        b2 = await session.scalar(select(Business).where(Business.id == business_id2))
        
        assert b1.slug == "kuafor-salonu"
        assert b2.slug == "kuafor-salonu-1"


async def test_transaction_rollback_on_failure() -> None:
    async with async_session_factory() as session:
        # Register first
        req1 = AdminRegistrationRequest(
            username="rollback_user1",
            email="rollback@test.com",
            password="SecurePassword123",
            business_name="Rollback Salon 1",
            slot_duration_minutes=30,
        )
        await register_business_and_admin(session, req1)
        
        # Second registration with same email
        req2 = AdminRegistrationRequest(
            username="rollback_user2",
            email="rollback@test.com",
            password="SecurePassword123",
            business_name="Rollback Salon 2",
            slot_duration_minutes=30,
        )
        
        with pytest.raises(RegistrationConflictError):
            await register_business_and_admin(session, req2)
            
        # Verify that "Rollback Salon 2" was NOT created in Business table due to rollback
        result = await session.scalar(
            select(Business).where(Business.name == "Rollback Salon 2")
        )
        assert result is None
