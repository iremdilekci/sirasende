from datetime import date, datetime, time, timezone
import os
from pathlib import Path
from uuid import uuid4

from alembic import command
from alembic.config import Config
from httpx import ASGITransport, AsyncClient
import pytest
from sqlalchemy import select

from app.core.database import async_session_factory
from app.core.security import create_access_token, hash_password
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
    command.upgrade(_alembic_config(), "head")
    yield
    command.downgrade(_alembic_config(), "base")


FIXED_NOW = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)


@pytest.fixture(autouse=True)
def mock_now_istanbul(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.services.admin_appointment_service.get_now_istanbul", lambda: FIXED_NOW)
    monkeypatch.setattr("app.services.slot_service.get_now_istanbul", lambda: FIXED_NOW)


@pytest.fixture
async def client() -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client


async def _create_business(slug: str | None = None, is_active: bool = True) -> Business:
    if slug is None:
        slug = f"biz-{uuid4().hex[:8]}"
    b = Business(
        name=f"Business {slug}",
        slug=slug,
        working_start_time=time(9, 0),
        working_end_time=time(18, 0),
        slot_duration_minutes=30,
        is_active=is_active,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(b)
        await session.refresh(b)
    return b


async def _create_admin(business_id: str, username: str | None = None, is_active: bool = True) -> tuple[AdminUser, str]:
    if username is None:
        username = f"admin_{uuid4().hex[:8]}"
    admin = AdminUser(
        business_id=business_id,
        username=username,
        email=f"{username}@example.com",
        password_hash=hash_password("StrongPassword123!"),
        is_active=is_active,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(admin)
        await session.refresh(admin)

    token = create_access_token(str(admin.id))
    return admin, token


async def _create_appointment(
    business_id: str,
    *,
    customer_name: str = "Jane Doe",
    customer_phone: str = "05551234567",
    customer_note: str | None = None,
    appointment_date: date = date(2026, 7, 12),
    start_time: time = time(9, 0),
    end_time: time = time(9, 30),
    status: AppointmentStatus = AppointmentStatus.PENDING,
) -> Appointment:
    apt = Appointment(
        business_id=business_id,
        customer_name=customer_name,
        customer_phone=customer_phone,
        customer_note=customer_note,
        appointment_date=appointment_date,
        start_time=start_time,
        end_time=end_time,
        status=status,
    )
    async with async_session_factory() as session:
        async with session.begin():
            session.add(apt)
        await session.refresh(apt)
    return apt


# ==============================================================================
# GET /api/v1/admin/appointments TESTS
# ==============================================================================


async def test_get_admin_appointments_success(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)

    apt1 = await _create_appointment(
        b.id,
        customer_name="Alice",
        appointment_date=date(2026, 7, 12),
        start_time=time(9, 0),
        end_time=time(9, 30),
        status=AppointmentStatus.PENDING,
    )
    apt2 = await _create_appointment(
        b.id,
        customer_name="Bob",
        appointment_date=date(2026, 7, 12),
        start_time=time(10, 0),
        end_time=time(10, 30),
        status=AppointmentStatus.CONFIRMED,
    )

    headers = {"Authorization": f"Bearer {token}"}
    response = await client.get("/api/v1/admin/appointments", headers=headers)
    assert response.status_code == 200

    data = response.json()
    assert len(data) == 2
    assert data[0]["id"] == str(apt1.id)
    assert data[0]["customer_name"] == "Alice"
    assert data[0]["start_time"] == "09:00"
    assert data[0]["end_time"] == "09:30"
    assert data[0]["status"] == "pending"
    assert "business_id" not in data[0]

    assert data[1]["id"] == str(apt2.id)
    assert data[1]["customer_name"] == "Bob"
    assert data[1]["status"] == "confirmed"


async def test_get_admin_appointments_isolation_from_other_businesses(client: AsyncClient) -> None:
    b1 = await _create_business()
    b2 = await _create_business()
    _, token1 = await _create_admin(b1.id)

    await _create_appointment(b1.id, customer_name="Biz1 Client")
    await _create_appointment(b2.id, customer_name="Biz2 Client")

    headers = {"Authorization": f"Bearer {token1}"}
    response = await client.get("/api/v1/admin/appointments", headers=headers)
    assert response.status_code == 200

    data = response.json()
    assert len(data) == 1
    assert data[0]["customer_name"] == "Biz1 Client"


async def test_get_admin_appointments_date_filter(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)

    await _create_appointment(b.id, appointment_date=date(2026, 7, 12))
    await _create_appointment(b.id, appointment_date=date(2026, 7, 13))

    headers = {"Authorization": f"Bearer {token}"}
    res = await client.get("/api/v1/admin/appointments?date=2026-07-12", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 1
    assert data[0]["appointment_date"] == "2026-07-12"


async def test_get_admin_appointments_status_filter(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)

    await _create_appointment(b.id, status=AppointmentStatus.PENDING)
    await _create_appointment(b.id, status=AppointmentStatus.CANCELLED)

    headers = {"Authorization": f"Bearer {token}"}
    res = await client.get("/api/v1/admin/appointments?status=cancelled", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 1
    assert data[0]["status"] == "cancelled"


async def test_get_admin_appointments_invalid_query_validation_errors(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    headers = {"Authorization": f"Bearer {token}"}

    res_date = await client.get("/api/v1/admin/appointments?date=invalid-date", headers=headers)
    assert res_date.status_code == 422

    res_status = await client.get("/api/v1/admin/appointments?status=unknown", headers=headers)
    assert res_status.status_code == 422


async def test_get_admin_appointments_auth_errors(client: AsyncClient) -> None:
    # 1. Missing token -> 401
    res1 = await client.get("/api/v1/admin/appointments")
    assert res1.status_code == 401
    assert res1.headers.get("www-authenticate") == "Bearer"

    # 2. Invalid token -> 401
    res2 = await client.get("/api/v1/admin/appointments", headers={"Authorization": "Bearer invalid.token"})
    assert res2.status_code == 401

    # 3. Inactive business -> 403
    b_inactive = await _create_business(is_active=False)
    _, token_inactive = await _create_admin(b_inactive.id)
    res3 = await client.get("/api/v1/admin/appointments", headers={"Authorization": f"Bearer {token_inactive}"})
    assert res3.status_code == 403
    assert res3.json() == {"detail": "Business access is inactive"}


async def test_get_admin_appointments_extra_query_business_id_ignored(client: AsyncClient) -> None:
    b1 = await _create_business()
    b2 = await _create_business()
    _, token1 = await _create_admin(b1.id)

    await _create_appointment(b1.id, customer_name="Biz1 Client")
    await _create_appointment(b2.id, customer_name="Biz2 Client")

    headers = {"Authorization": f"Bearer {token1}"}
    # Passing someone else's business_id in query should have ZERO effect
    res = await client.get(f"/api/v1/admin/appointments?business_id={b2.id}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 1
    assert data[0]["customer_name"] == "Biz1 Client"


# ==============================================================================
# PATCH /api/v1/admin/appointments/{appointment_id}/status TESTS
# ==============================================================================


async def test_patch_status_pending_to_confirmed(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    apt = await _create_appointment(b.id, status=AppointmentStatus.PENDING)

    headers = {"Authorization": f"Bearer {token}"}
    res = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "confirmed"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == str(apt.id)
    assert data["status"] == "confirmed"


async def test_patch_status_pending_to_cancelled(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    apt = await _create_appointment(b.id, status=AppointmentStatus.PENDING)

    headers = {"Authorization": f"Bearer {token}"}
    res = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "cancelled"},
    )
    assert res.status_code == 200
    assert res.json()["status"] == "cancelled"


async def test_patch_status_confirmed_to_completed_after_end_time(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    # end_time 10:00 on 2026-07-12; FIXED_NOW is 10:15
    apt = await _create_appointment(
        b.id,
        appointment_date=date(2026, 7, 12),
        start_time=time(9, 30),
        end_time=time(10, 0),
        status=AppointmentStatus.CONFIRMED,
    )

    headers = {"Authorization": f"Bearer {token}"}
    res = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "completed"},
    )
    assert res.status_code == 200
    assert res.json()["status"] == "completed"


async def test_patch_status_idempotent_returns_200(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    apt = await _create_appointment(b.id, status=AppointmentStatus.CONFIRMED)

    headers = {"Authorization": f"Bearer {token}"}
    res = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "confirmed"},
    )
    assert res.status_code == 200
    assert res.json()["status"] == "confirmed"


async def test_patch_status_not_found_and_isolation_returns_404(client: AsyncClient) -> None:
    b1 = await _create_business()
    b2 = await _create_business()
    _, token1 = await _create_admin(b1.id)

    apt2 = await _create_appointment(b2.id, status=AppointmentStatus.PENDING)

    headers = {"Authorization": f"Bearer {token1}"}

    # 1. Non-existent appointment UUID
    res_random = await client.patch(
        f"/api/v1/admin/appointments/{uuid4()}/status",
        headers=headers,
        json={"status": "confirmed"},
    )
    assert res_random.status_code == 404
    assert res_random.json() == {"detail": "Appointment not found"}

    # 2. Other business appointment UUID -> Same 404 error
    res_other = await client.patch(
        f"/api/v1/admin/appointments/{apt2.id}/status",
        headers=headers,
        json={"status": "confirmed"},
    )
    assert res_other.status_code == 404
    assert res_other.json() == {"detail": "Appointment not found"}


async def test_patch_status_invalid_transition_returns_409(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    apt = await _create_appointment(b.id, status=AppointmentStatus.PENDING)

    headers = {"Authorization": f"Bearer {token}"}
    res = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "completed"},  # PENDING -> COMPLETED is invalid!
    )
    assert res.status_code == 409
    assert res.json() == {"detail": "Invalid appointment status transition"}


async def test_patch_status_completion_before_end_time_returns_409(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    # end_time 11:00 on 2026-07-12; FIXED_NOW is 10:15
    apt = await _create_appointment(
        b.id,
        appointment_date=date(2026, 7, 12),
        start_time=time(10, 30),
        end_time=time(11, 0),
        status=AppointmentStatus.CONFIRMED,
    )

    headers = {"Authorization": f"Bearer {token}"}
    res = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "completed"},
    )
    assert res.status_code == 409
    assert res.json() == {"detail": "Appointment cannot be completed before its end time"}


async def test_patch_status_validation_errors(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    apt = await _create_appointment(b.id)
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Invalid path UUID
    res_uuid = await client.patch(
        "/api/v1/admin/appointments/invalid-uuid/status",
        headers=headers,
        json={"status": "confirmed"},
    )
    assert res_uuid.status_code == 422

    # 2. Invalid status enum
    res_status = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "unknown_status"},
    )
    assert res_status.status_code == 422

    # 3. Empty body
    res_empty = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={},
    )
    assert res_empty.status_code == 422

    # 4. Extra fields in body (extra="forbid")
    res_extra = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "confirmed", "extra_field": "hacked"},
    )
    assert res_extra.status_code == 422


# ==============================================================================
# ROUTE & OPENAPI SCHEMAS VERIFICATION
# ==============================================================================


async def test_openapi_schema_contains_admin_appointment_routes(client: AsyncClient) -> None:
    res = await client.get("/openapi.json")
    assert res.status_code == 200
    schema = res.json()
    paths = schema.get("paths", {})

    assert "/api/v1/admin/appointments" in paths
    assert "get" in paths["/api/v1/admin/appointments"]

    assert "/api/v1/admin/appointments/{appointment_id}/status" in paths
    assert "patch" in paths["/api/v1/admin/appointments/{appointment_id}/status"]


async def test_patch_status_idempotent_updated_at_unchanged(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    apt = await _create_appointment(b.id, status=AppointmentStatus.CONFIRMED)
    headers = {"Authorization": f"Bearer {token}"}

    res1 = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "confirmed"},
    )
    assert res1.status_code == 200
    updated_at_1 = res1.json()["updated_at"]

    res2 = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "confirmed"},
    )
    assert res2.status_code == 200
    updated_at_2 = res2.json()["updated_at"]

    assert updated_at_1 == updated_at_2


async def test_patch_status_mutation_reflected_in_get_list(client: AsyncClient) -> None:
    b = await _create_business()
    _, token = await _create_admin(b.id)
    apt = await _create_appointment(b.id, status=AppointmentStatus.PENDING)
    headers = {"Authorization": f"Bearer {token}"}

    res_patch = await client.patch(
        f"/api/v1/admin/appointments/{apt.id}/status",
        headers=headers,
        json={"status": "confirmed"},
    )
    assert res_patch.status_code == 200

    res_get = await client.get("/api/v1/admin/appointments", headers=headers)
    assert res_get.status_code == 200
    data = res_get.json()
    assert len(data) == 1
    assert data[0]["id"] == str(apt.id)
    assert data[0]["status"] == "confirmed"
