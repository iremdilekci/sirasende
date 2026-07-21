from datetime import date, datetime, time, timezone
from uuid import UUID

import pytest
from pydantic import ValidationError

from app.core.exceptions import (
    BusinessNotFoundError,
    InvalidAppointmentSlotError,
    PastAppointmentError,
)
from app.models import AppointmentStatus, Business
from app.schemas.appointment import AppointmentCreate
from app.services.appointment_service import build_pending_appointment, resolve_appointment_slot
from app.services.slot_service import ISTANBUL_TIMEZONE


FIXED_NOW = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)


@pytest.fixture(autouse=True)
def mock_now_istanbul(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.services.slot_service.get_now_istanbul", lambda: FIXED_NOW)
    monkeypatch.setattr("app.services.appointment_service.get_now_istanbul", lambda: FIXED_NOW)
    monkeypatch.setattr("app.api.v1.businesses.get_now_istanbul", lambda: FIXED_NOW)


# Helper to instantiate transient Business instance
def _make_business(
    id_=None,
    name="Test Business",
    slug="test-business",
    start=time(9, 0),
    end=time(18, 0),
    duration=30,
    is_active=True,
) -> Business:
    return Business(
        id=id_ or UUID("00000000-0000-0000-0000-000000000001"),
        name=name,
        slug=slug,
        working_start_time=start,
        working_end_time=end,
        slot_duration_minutes=duration,
        is_active=is_active,
    )


# ==============================================================================
# RESOLVE SLOT TESTS
# ==============================================================================

def test_resolve_slot_30_minutes() -> None:
    business = _make_business(duration=30)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    start, end = resolve_appointment_slot(
        business=business,
        appointment_date=date(2026, 7, 20),
        requested_start_time=time(9, 0),
        now=fixed_now,
    )
    assert start == time(9, 0)
    assert end == time(9, 30)


def test_resolve_slot_45_minutes() -> None:
    business = _make_business(duration=45)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    start, end = resolve_appointment_slot(
        business=business,
        appointment_date=date(2026, 7, 20),
        requested_start_time=time(9, 0),
        now=fixed_now,
    )
    assert start == time(9, 0)
    assert end == time(9, 45)


def test_resolve_slot_60_minutes() -> None:
    business = _make_business(duration=60)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    start, end = resolve_appointment_slot(
        business=business,
        appointment_date=date(2026, 7, 20),
        requested_start_time=time(9, 0),
        now=fixed_now,
    )
    assert start == time(9, 0)
    assert end == time(10, 0)


def test_resolve_slot_not_aligned_with_duration() -> None:
    business = _make_business(duration=30)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    with pytest.raises(InvalidAppointmentSlotError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(9, 15),  # 09:15 is not a valid 30-min start
            now=fixed_now,
        )


def test_resolve_slot_before_working_hours() -> None:
    business = _make_business(start=time(9, 0), duration=30)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    with pytest.raises(InvalidAppointmentSlotError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(8, 30),
            now=fixed_now,
        )


def test_resolve_slot_after_working_hours() -> None:
    business = _make_business(end=time(18, 0), duration=30)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    with pytest.raises(InvalidAppointmentSlotError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(18, 0),
            now=fixed_now,
        )


def test_resolve_slot_exceeding_closing_hour() -> None:
    business = _make_business(end=time(18, 0), duration=30)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    with pytest.raises(InvalidAppointmentSlotError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(17, 45),  # Starts 17:45, closes 18:00 (needs 30 mins)
            now=fixed_now,
        )


def test_resolve_slot_past_date() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 10, 0, tzinfo=ISTANBUL_TIMEZONE)
    with pytest.raises(PastAppointmentError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 19),
            requested_start_time=time(12, 0),
            now=fixed_now,
        )


def test_resolve_slot_today_past_hour() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    with pytest.raises(PastAppointmentError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(10, 0),  # 10:00 <= 10:15
            now=fixed_now,
        )


def test_resolve_slot_today_exact_current_time() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 10, 00, tzinfo=ISTANBUL_TIMEZONE)
    with pytest.raises(PastAppointmentError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(10, 0),  # 10:00 <= 10:00
            now=fixed_now,
        )


def test_resolve_slot_today_future_hour() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    start, end = resolve_appointment_slot(
        business=business,
        appointment_date=date(2026, 7, 20),
        requested_start_time=time(11, 0),  # 11:00 > 10:15
        now=fixed_now,
    )
    assert start == time(11, 0)
    assert end == time(11, 30)


def test_resolve_slot_future_date() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 10, 15, tzinfo=ISTANBUL_TIMEZONE)
    start, end = resolve_appointment_slot(
        business=business,
        appointment_date=date(2026, 8, 21),
        requested_start_time=time(9, 0),
        now=fixed_now,
    )
    assert start == time(9, 0)


def test_resolve_slot_inactive_business() -> None:
    business = _make_business(is_active=False)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    with pytest.raises(BusinessNotFoundError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(9, 0),
            now=fixed_now,
        )


def test_resolve_slot_timezone_naive_now() -> None:
    business = _make_business()
    naive_now = datetime(2026, 7, 20, 8, 0)
    with pytest.raises(ValueError, match="must be timezone-aware"):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(9, 0),
            now=naive_now,
        )


def test_resolve_slot_different_timezone_now() -> None:
    business = _make_business()
    # 2026-07-20 07:00 UTC is 2026-07-20 10:00 Europe/Istanbul
    utc_now = datetime(2026, 7, 20, 7, 0, tzinfo=timezone.utc)
    
    # 09:30 should be past because 09:30 <= 10:00
    with pytest.raises(PastAppointmentError):
        resolve_appointment_slot(
            business=business,
            appointment_date=date(2026, 7, 20),
            requested_start_time=time(9, 30),
            now=utc_now,
        )


# ==============================================================================
# BUILD APPOINTMENT ORM OBJECT TESTS
# ==============================================================================

def test_build_appointment_orm_correct_business_id() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    payload = AppointmentCreate(
        customer_name="John Doe",
        customer_phone="12345678",
        appointment_date=date(2026, 7, 20),
        start_time=time(9, 0),
    )
    appointment = build_pending_appointment(business, payload, now=fixed_now)
    assert appointment.business_id == business.id


def test_build_appointment_customer_details_preserved() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    payload = AppointmentCreate(
        customer_name="John Doe",
        customer_phone="+9055512345",
        appointment_date=date(2026, 7, 20),
        start_time=time(9, 0),
        customer_note="My spec note",
    )
    appointment = build_pending_appointment(business, payload, now=fixed_now)
    assert appointment.customer_name == "John Doe"
    assert appointment.customer_phone == "+9055512345"
    assert appointment.customer_note == "My spec note"


def test_build_appointment_optional_note_omitted() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    payload = AppointmentCreate(
        customer_name="John Doe",
        customer_phone="+9055512345",
        appointment_date=date(2026, 7, 20),
        start_time=time(9, 0),
    )
    appointment = build_pending_appointment(business, payload, now=fixed_now)
    assert appointment.customer_note is None


def test_build_appointment_end_time_calculated() -> None:
    business = _make_business(duration=45)
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    payload = AppointmentCreate(
        customer_name="John Doe",
        customer_phone="12345",
        appointment_date=date(2026, 7, 20),
        start_time=time(9, 0),
    )
    appointment = build_pending_appointment(business, payload, now=fixed_now)
    assert appointment.start_time == time(9, 0)
    assert appointment.end_time == time(9, 45)


def test_build_appointment_status_explicit_pending() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    payload = AppointmentCreate(
        customer_name="John Doe",
        customer_phone="12345",
        appointment_date=date(2026, 7, 20),
        start_time=time(9, 0),
    )
    appointment = build_pending_appointment(business, payload, now=fixed_now)
    assert appointment.status == AppointmentStatus.PENDING


def test_build_appointment_orm_fields_not_set() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    payload = AppointmentCreate(
        customer_name="John Doe",
        customer_phone="12345",
        appointment_date=date(2026, 7, 20),
        start_time=time(9, 0),
    )
    appointment = build_pending_appointment(business, payload, now=fixed_now)
    # These are populated by DB triggers or ORM session unit of work
    assert getattr(appointment, "id", None) is None


def test_build_appointment_inputs_not_mutated() -> None:
    business = _make_business()
    fixed_now = datetime(2026, 7, 20, 8, 0, tzinfo=ISTANBUL_TIMEZONE)
    payload = AppointmentCreate(
        customer_name="John Doe",
        customer_phone="12345",
        appointment_date=date(2026, 7, 20),
        start_time=time(9, 0),
    )
    build_pending_appointment(business, payload, now=fixed_now)
    # Validate no changes made to original arguments
    assert business.working_start_time == time(9, 0)
    assert payload.customer_name == "John Doe"


# ==============================================================================
# SCHEMA VALIDATION TESTS
# ==============================================================================

def test_schema_trim_customer_name() -> None:
    payload = AppointmentCreate(
        customer_name="   John Doe   ",
        customer_phone="123456",
        appointment_date=date(2026, 7, 21),
        start_time=time(9, 0),
    )
    assert payload.customer_name == "John Doe"


def test_schema_reject_empty_customer_name() -> None:
    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="   ",
            customer_phone="123456",
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
        )


def test_schema_reject_too_short_customer_name() -> None:
    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="A",
            customer_phone="123456",
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
        )


def test_schema_reject_too_long_customer_name() -> None:
    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="A" * 201,
            customer_phone="123456",
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
        )


def test_schema_phone_string_types_preserved() -> None:
    payload = AppointmentCreate(
        customer_name="John",
        customer_phone="+9055512345",
        appointment_date=date(2026, 7, 21),
        start_time=time(9, 0),
    )
    assert payload.customer_phone == "+9055512345"
    
    payload2 = AppointmentCreate(
        customer_name="John",
        customer_phone="055512345",
        appointment_date=date(2026, 7, 21),
        start_time=time(9, 0),
    )
    assert payload2.customer_phone == "055512345"


def test_schema_reject_too_short_phone() -> None:
    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="John",
            customer_phone="1234",  # < 5 chars
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
        )


def test_schema_reject_too_long_phone() -> None:
    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="John",
            customer_phone="1" * 31,  # > 30 chars
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
        )


def test_schema_reject_too_long_note() -> None:
    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="John",
            customer_phone="123456",
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
            customer_note="A" * 1001,  # > 1000 chars
        )


def test_schema_forbid_extra_fields() -> None:
    # Test that forbidden keys like end_time or status raise error
    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="John",
            customer_phone="123456",
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
            end_time=time(9, 30),  # extra
        )

    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="John",
            customer_phone="123456",
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
            status="confirmed",  # extra
        )

    with pytest.raises(ValidationError):
        AppointmentCreate(
            customer_name="John",
            customer_phone="123456",
            appointment_date=date(2026, 7, 21),
            start_time=time(9, 0),
            business_id="00000000-0000-0000-0000-000000000001",  # extra
        )
