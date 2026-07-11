from unittest.mock import MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.exc import OperationalError

from app.main import app


@pytest.fixture
async def client() -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client


async def test_health_returns_ok(client: AsyncClient) -> None:
    response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


async def test_database_health_returns_503_when_database_is_unavailable(
    client: AsyncClient,
) -> None:
    error = OperationalError("SELECT 1", {}, Exception("connection failed"))
    unavailable_engine = MagicMock()
    unavailable_engine.connect.side_effect = error

    with patch("app.main.engine", unavailable_engine):
        response = await client.get("/health/database")

    assert response.status_code == 503
    assert response.json() == {"detail": "Database unavailable"}
