import asyncio
import os
from datetime import date, time
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import func, inspect, select
from sqlalchemy.exc import IntegrityError

from app.core.database import async_session_factory, engine
from app.models import AdminUser, Appointment, AppointmentStatus, Business
from app.scripts.seed import (
    DEMO_ADMIN_USERNAME,
    DEMO_BUSINESS_SLUG,
    seed_database,
)


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


async def _add_business(
    *,
    slug: str,
    slot_duration: int = 30,
    start: time = time(9, 0),
    end: time = time(18, 0),
) -> Business:
    business = Business(
        name=f"Test {slug}",
        slug=slug,
        working_start_time=start,
        working_end_time=end,
        slot_duration_minutes=slot_duration,
    )
    return business


@pytest.mark.parametrize("slot_duration", [30, 45, 60])
async def test_valid_business_slot_durations_are_accepted(slot_duration: int) -> None:
    async with async_session_factory() as session:
        session.add(
            await _add_business(
                slug=f"valid-slot-{slot_duration}",
                slot_duration=slot_duration,
            )
        )
        await session.flush()
        await session.rollback()


async def test_invalid_business_slot_duration_is_rejected() -> None:
    async with async_session_factory() as session:
        session.add(await _add_business(slug="invalid-slot", slot_duration=20))
        with pytest.raises(IntegrityError):
            await session.flush()
        await session.rollback()


async def test_business_end_time_must_be_after_start_time() -> None:
    async with async_session_factory() as session:
        session.add(
            await _add_business(
                slug="invalid-hours",
                start=time(18, 0),
                end=time(9, 0),
            )
        )
        with pytest.raises(IntegrityError):
            await session.flush()
        await session.rollback()


async def test_appointment_defaults_to_pending() -> None:
    async with async_session_factory() as session:
        business = await _add_business(slug="appointment-default")
        session.add(business)
        await session.flush()
        appointment = Appointment(
            business_id=business.id,
            customer_name="Test Customer",
            customer_phone="5550000000",
            appointment_date=date.today(),
            start_time=time(10, 0),
            end_time=time(10, 30),
        )
        session.add(appointment)
        await session.flush()

        assert appointment.status == AppointmentStatus.PENDING
        await session.rollback()


async def test_appointment_end_time_must_be_after_start_time() -> None:
    async with async_session_factory() as session:
        business = await _add_business(slug="appointment-invalid-hours")
        session.add(business)
        await session.flush()
        session.add(
            Appointment(
                business_id=business.id,
                customer_name="Test Customer",
                customer_phone="5550000000",
                appointment_date=date.today(),
                start_time=time(11, 0),
                end_time=time(10, 30),
            )
        )
        with pytest.raises(IntegrityError):
            await session.flush()
        await session.rollback()


@pytest.mark.parametrize("duplicate_field", ["username", "email"])
async def test_admin_username_and_email_are_unique(duplicate_field: str) -> None:
    async with async_session_factory() as session:
        business = await _add_business(slug=f"admin-unique-{duplicate_field}")
        session.add(business)
        await session.flush()
        first = AdminUser(
            business_id=business.id,
            username=f"first-{duplicate_field}",
            email=f"first-{duplicate_field}@example.com",
            password_hash="not-a-real-password-hash",
        )
        second = AdminUser(
            business_id=business.id,
            username=(first.username if duplicate_field == "username" else "second-user"),
            email=(first.email if duplicate_field == "email" else "second@example.com"),
            password_hash="not-a-real-password-hash",
        )
        session.add_all([first, second])
        with pytest.raises(IntegrityError):
            await session.flush()
        await session.rollback()


async def _get_table_names() -> list[str]:
    async with engine.connect() as connection:
        return await connection.run_sync(
            lambda sync_connection: inspect(sync_connection).get_table_names()
        )


def test_migration_downgrade_and_upgrade_cycle() -> None:
    config = _alembic_config()
    command.downgrade(config, "base")
    command.upgrade(config, "head")
    table_names = asyncio.run(_get_table_names())

    assert {"alembic_version", "businesses", "admin_users", "appointments"} <= set(
        table_names
    )


async def test_seed_is_idempotent_and_hashes_password(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SEED_ADMIN_PASSWORD", "integration-test-only-password")

    await seed_database()
    await seed_database()

    async with async_session_factory() as session:
        business_count = await session.scalar(
            select(func.count()).select_from(Business).where(
                Business.slug == DEMO_BUSINESS_SLUG
            )
        )
        admin_users = (
            await session.scalars(
                select(AdminUser).where(AdminUser.username == DEMO_ADMIN_USERNAME)
            )
        ).all()

    assert business_count == 1
    assert len(admin_users) == 1
    assert admin_users[0].password_hash.startswith("$argon2")


async def test_appointment_active_slot_index_behavior() -> None:
    # Scenario 1: Same business, date, start_time for two pending appointments -> raises IntegrityError
    async with async_session_factory() as session:
        b = await _add_business(slug="active-slot-behav-1")
        session.add(b)
        await session.flush()

        a1 = Appointment(
            business_id=b.id,
            customer_name="Customer 1",
            customer_phone="5550000000",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        a2 = Appointment(
            business_id=b.id,
            customer_name="Customer 2",
            customer_phone="5551111111",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        session.add_all([a1, a2])
        with pytest.raises(IntegrityError):
            await session.flush()
        await session.rollback()

    # Scenario 2: Same slot, pending and confirmed -> raises IntegrityError
    async with async_session_factory() as session:
        b = await _add_business(slug="active-slot-behav-2")
        session.add(b)
        await session.flush()

        a1 = Appointment(
            business_id=b.id,
            customer_name="Customer 1",
            customer_phone="5550000000",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        a2 = Appointment(
            business_id=b.id,
            customer_name="Customer 2",
            customer_phone="5551111111",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.CONFIRMED,
        )
        session.add_all([a1, a2])
        with pytest.raises(IntegrityError):
            await session.flush()
        await session.rollback()

    # Scenario 3: First cancelled, second pending -> success
    async with async_session_factory() as session:
        b = await _add_business(slug="active-slot-behav-3")
        session.add(b)
        await session.flush()

        a1 = Appointment(
            business_id=b.id,
            customer_name="Customer 1",
            customer_phone="5550000000",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.CANCELLED,
        )
        a2 = Appointment(
            business_id=b.id,
            customer_name="Customer 2",
            customer_phone="5551111111",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        session.add_all([a1, a2])
        await session.flush()
        await session.commit()

    # Scenario 4: First completed, second pending -> success
    async with async_session_factory() as session:
        b = await _add_business(slug="active-slot-behav-4")
        session.add(b)
        await session.flush()

        a1 = Appointment(
            business_id=b.id,
            customer_name="Customer 1",
            customer_phone="5550000000",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.COMPLETED,
        )
        a2 = Appointment(
            business_id=b.id,
            customer_name="Customer 2",
            customer_phone="5551111111",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        session.add_all([a1, a2])
        await session.flush()
        await session.commit()

    # Scenario 5: Same slot, different businesses -> success
    async with async_session_factory() as session:
        b1 = await _add_business(slug="active-slot-behav-5a")
        b2 = await _add_business(slug="active-slot-behav-5b")
        session.add_all([b1, b2])
        await session.flush()

        a1 = Appointment(
            business_id=b1.id,
            customer_name="Customer 1",
            customer_phone="5550000000",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        a2 = Appointment(
            business_id=b2.id,
            customer_name="Customer 2",
            customer_phone="5551111111",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        session.add_all([a1, a2])
        await session.flush()
        await session.commit()

    # Scenario 6: Same business and hour, different dates -> success
    async with async_session_factory() as session:
        b = await _add_business(slug="active-slot-behav-6")
        session.add(b)
        await session.flush()

        a1 = Appointment(
            business_id=b.id,
            customer_name="Customer 1",
            customer_phone="5550000000",
            appointment_date=date(2026, 7, 20),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        a2 = Appointment(
            business_id=b.id,
            customer_name="Customer 2",
            customer_phone="5551111111",
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
            end_time=time(9, 30),
            status=AppointmentStatus.PENDING,
        )
        session.add_all([a1, a2])
        await session.flush()
        await session.commit()
