import os
from datetime import time
from uuid import uuid4

from httpx import ASGITransport, AsyncClient
import pytest

from app.core.database import async_session_factory
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models import AdminUser, Business

from pathlib import Path
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


async def test_get_my_business_success(client: AsyncClient) -> None:
    business = await _create_business()
    _, token = await _create_admin(str(business.id))

    response = await client.get(
        "/api/v1/admin/business",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == str(business.id)
    assert data["name"] == business.name
    assert data["description"] == "Demo business description"
    assert data["phone"] == "05554443322"
    assert data["address"] == "Kadikoy, Istanbul"


async def test_get_my_business_unauthorized(client: AsyncClient) -> None:
    response = await client.get("/api/v1/admin/business")
    assert response.status_code == 401


async def test_patch_my_business_success(client: AsyncClient) -> None:
    business = await _create_business()
    _, token = await _create_admin(str(business.id))

    payload = {
        "name": "Updated Barber Shop",
        "description": "New updated description",
        "phone": "05001112233",
        "address": "Kadikoy, Moda, Istanbul",
        "working_start_time": "08:30:00",
        "working_end_time": "19:00:00",
        "slot_duration_minutes": 45,
    }

    response = await client.patch(
        "/api/v1/admin/business",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Updated Barber Shop"
    assert data["description"] == "New updated description"
    assert data["phone"] == "05001112233"
    assert data["address"] == "Kadikoy, Moda, Istanbul"
    assert data["working_start_time"] == "08:30:00"
    assert data["working_end_time"] == "19:00:00"
    assert data["slot_duration_minutes"] == 45


async def test_patch_my_business_validation_errors(client: AsyncClient) -> None:
    business = await _create_business()
    _, token = await _create_admin(str(business.id))

    # Empty name
    response = await client.patch(
        "/api/v1/admin/business",
        json={"name": "   "},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 400

    # Invalid working hours
    response = await client.patch(
        "/api/v1/admin/business",
        json={"working_start_time": "18:00:00", "working_end_time": "09:00:00"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 400

    # Invalid slot duration
    response = await client.patch(
        "/api/v1/admin/business",
        json={"slot_duration_minutes": 15},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 400
