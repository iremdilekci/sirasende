from unittest.mock import AsyncMock
from uuid import uuid4
import pytest
from fastapi import Depends, FastAPI, HTTPException, status
from httpx import ASGITransport, AsyncClient

from app.api.deps import get_current_active_business_admin, get_current_admin
from app.models.admin_user import AdminUser
from app.models.business import Business


def _make_admin(business_id=None, is_active=True) -> AdminUser:
    return AdminUser(
        id=uuid4(),
        business_id=business_id or uuid4(),
        username="testadmin",
        email="testadmin@example.com",
        password_hash="argon2hash",
        is_active=is_active,
    )


def _make_business(business_id=None, is_active=True) -> Business:
    return Business(
        id=business_id or uuid4(),
        name="Test Business",
        slug="test-business",
        working_start_time="09:00",
        working_end_time="18:00",
        slot_duration_minutes=30,
        is_active=is_active,
    )


# Create a test FastAPI app to execute dependency resolution
app = FastAPI()


@app.get("/test-dependency")
async def read_test_dependency(admin: AdminUser = Depends(get_current_active_business_admin)):
    return {"admin_id": str(admin.id), "business_id": str(admin.business_id)}


async def test_active_admin_and_active_business_succeeds(monkeypatch: pytest.MonkeyPatch) -> None:
    b_id = uuid4()
    admin = _make_admin(business_id=b_id)
    business = _make_business(business_id=b_id, is_active=True)

    app.dependency_overrides[get_current_admin] = lambda: admin
    mock_get_b = AsyncMock(return_value=business)
    monkeypatch.setattr("app.repositories.business_repository.get_business_by_id", mock_get_b)

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.get("/test-dependency")
            assert response.status_code == 200
            assert response.json()["admin_id"] == str(admin.id)
            assert response.json()["business_id"] == str(b_id)
            mock_get_b.assert_called_once()
    finally:
        app.dependency_overrides.clear()


async def test_active_admin_and_inactive_business_returns_403(monkeypatch: pytest.MonkeyPatch) -> None:
    b_id = uuid4()
    admin = _make_admin(business_id=b_id)
    business = _make_business(business_id=b_id, is_active=False)

    app.dependency_overrides[get_current_admin] = lambda: admin
    mock_get_b = AsyncMock(return_value=business)
    monkeypatch.setattr("app.repositories.business_repository.get_business_by_id", mock_get_b)

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.get("/test-dependency")
            assert response.status_code == 403
            assert response.json() == {"detail": "Business access is inactive"}
            assert response.status_code != 401
    finally:
        app.dependency_overrides.clear()


async def test_active_admin_and_missing_business_returns_403(monkeypatch: pytest.MonkeyPatch) -> None:
    b_id = uuid4()
    admin = _make_admin(business_id=b_id)

    app.dependency_overrides[get_current_admin] = lambda: admin
    mock_get_b = AsyncMock(return_value=None)
    monkeypatch.setattr("app.repositories.business_repository.get_business_by_id", mock_get_b)

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.get("/test-dependency")
            assert response.status_code == 403
            assert response.json() == {"detail": "Business access is inactive"}
    finally:
        app.dependency_overrides.clear()


async def test_inactive_admin_raises_401_from_get_current_admin() -> None:
    def raise_401():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    app.dependency_overrides[get_current_admin] = raise_401

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.get("/test-dependency")
            assert response.status_code == 401
            assert response.json() == {"detail": "Could not validate credentials"}
            assert response.headers.get("www-authenticate") == "Bearer"
    finally:
        app.dependency_overrides.clear()


async def test_403_detail_does_not_contain_pii(monkeypatch: pytest.MonkeyPatch) -> None:
    b_id = uuid4()
    admin = _make_admin(business_id=b_id)
    business = _make_business(business_id=b_id, is_active=False)

    app.dependency_overrides[get_current_admin] = lambda: admin
    mock_get_b = AsyncMock(return_value=business)
    monkeypatch.setattr("app.repositories.business_repository.get_business_by_id", mock_get_b)

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            response = await ac.get("/test-dependency")
            detail = response.json().get("detail", "")
            assert str(b_id) not in detail
            assert admin.username not in detail
            assert admin.email not in detail
    finally:
        app.dependency_overrides.clear()
