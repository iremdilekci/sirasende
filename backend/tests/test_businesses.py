from collections.abc import AsyncGenerator
from datetime import time
import os
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete

from app.core.database import async_session_factory, engine
from app.main import app
from app.models import Business

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


@pytest.fixture

async def test_businesses() -> AsyncGenerator[None, None]:
    async with async_session_factory() as session:
        b1 = Business(
            name="Z Kuaför",
            slug="z-kuafor",
            working_start_time=time(9, 0),
            working_end_time=time(18, 0),
            slot_duration_minutes=30,
            is_active=True,
        )
        b2 = Business(
            name="A Kuaför",
            slug="demo-kuafor",
            working_start_time=time(9, 0),
            working_end_time=time(18, 0),
            slot_duration_minutes=45,
            is_active=True,
        )
        b3 = Business(
            name="Pasif Kuaför",
            slug="pasif-kuafor",
            working_start_time=time(9, 0),
            working_end_time=time(18, 0),
            slot_duration_minutes=60,
            is_active=False,
        )
        session.add_all([b1, b2, b3])
        await session.commit()

    yield

    async with async_session_factory() as session:
        await session.execute(delete(Business))
        await session.commit()


async def test_get_businesses_returns_empty_when_no_records(client: AsyncClient) -> None:
    response = await client.get("/api/v1/businesses")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.usefixtures("test_businesses")
async def test_get_businesses_returns_sorted_active_only(client: AsyncClient) -> None:
    response = await client.get("/api/v1/businesses")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 2

    # Order check: "A Kuaför" (demo-kuafor) sorted before "Z Kuaför" (z-kuafor)
    assert data[0]["name"] == "A Kuaför"
    assert data[0]["slug"] == "demo-kuafor"
    assert data[0]["slot_duration_minutes"] == 45
    assert data[0]["is_active"] is True

    assert data[1]["name"] == "Z Kuaför"
    assert data[1]["slug"] == "z-kuafor"
    assert data[1]["slot_duration_minutes"] == 30
    assert data[1]["is_active"] is True


@pytest.mark.usefixtures("test_businesses")
async def test_get_business_by_slug_returns_details(client: AsyncClient) -> None:
    response = await client.get("/api/v1/businesses/demo-kuafor")
    assert response.status_code == 200
    details = response.json()
    assert details["slug"] == "demo-kuafor"
    assert details["name"] == "A Kuaför"
    assert details["working_start_time"] == "09:00:00"
    assert details["working_end_time"] == "18:00:00"
    assert "created_at" in details
    assert "updated_at" in details


@pytest.mark.usefixtures("test_businesses")
async def test_get_business_by_slug_returns_404_for_unknown_slug(client: AsyncClient) -> None:
    response = await client.get("/api/v1/businesses/olmayan-isletme")
    assert response.status_code == 404
    assert response.json() == {"detail": "Business not found"}


@pytest.mark.usefixtures("test_businesses")
async def test_get_business_by_slug_returns_404_for_inactive_slug(client: AsyncClient) -> None:
    response = await client.get("/api/v1/businesses/pasif-kuafor")
    assert response.status_code == 404
    assert response.json() == {"detail": "Business not found"}
