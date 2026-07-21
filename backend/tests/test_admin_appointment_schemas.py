from datetime import date, datetime, time, timezone
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.models.appointment import AppointmentStatus
from app.schemas.admin_appointment import AdminAppointmentOut, AppointmentStatusUpdate


def test_admin_appointment_out_valid_creation() -> None:
    apt_id = uuid4()
    now = datetime.now(timezone.utc)

    data = {
        "id": apt_id,
        "customer_name": "Ahmet Yılmaz",
        "customer_phone": "05551112233",
        "customer_note": "Saç ve sakal kesimi",
        "appointment_date": date(2026, 7, 25),
        "start_time": time(10, 0),
        "end_time": time(10, 30),
        "status": AppointmentStatus.PENDING,
        "created_at": now,
        "updated_at": now,
    }

    schema = AdminAppointmentOut.model_validate(data)
    assert schema.id == apt_id
    assert schema.customer_name == "Ahmet Yılmaz"
    assert schema.customer_phone == "05551112233"
    assert schema.customer_note == "Saç ve sakal kesimi"
    assert schema.appointment_date == date(2026, 7, 25)
    assert schema.start_time == time(10, 0)
    assert schema.end_time == time(10, 30)
    assert schema.status == AppointmentStatus.PENDING


def test_admin_appointment_out_customer_note_none() -> None:
    apt_id = uuid4()
    now = datetime.now(timezone.utc)

    data = {
        "id": apt_id,
        "customer_name": "Mehmet Demir",
        "customer_phone": "05552223344",
        "customer_note": None,
        "appointment_date": date(2026, 7, 25),
        "start_time": time(11, 0),
        "end_time": time(11, 30),
        "status": AppointmentStatus.CONFIRMED,
        "created_at": now,
        "updated_at": now,
    }

    schema = AdminAppointmentOut.model_validate(data)
    assert schema.customer_note is None


def test_admin_appointment_out_status_enum_serialization() -> None:
    apt_id = uuid4()
    now = datetime.now(timezone.utc)

    data = {
        "id": apt_id,
        "customer_name": "Ayşe Kaya",
        "customer_phone": "05553334455",
        "customer_note": None,
        "appointment_date": date(2026, 7, 25),
        "start_time": time(14, 0),
        "end_time": time(14, 30),
        "status": AppointmentStatus.COMPLETED,
        "created_at": now,
        "updated_at": now,
    }

    schema = AdminAppointmentOut.model_validate(data)
    assert schema.start_time == time(14, 0)
    dump = schema.model_dump()
    assert dump["status"] == AppointmentStatus.COMPLETED
    assert dump["start_time"] == "14:00"

    # Test JSON serialization with custom serializers
    json_dump = schema.model_dump_json()
    assert '"status":"completed"' in json_dump
    assert '"start_time":"14:00"' in json_dump
    assert '"end_time":"14:30"' in json_dump


def test_admin_appointment_out_does_not_contain_business_id() -> None:
    assert "business_id" not in AdminAppointmentOut.model_fields


def test_appointment_status_update_accepts_pending() -> None:
    update = AppointmentStatusUpdate(status=AppointmentStatus.PENDING)
    assert update.status == AppointmentStatus.PENDING


def test_appointment_status_update_accepts_confirmed() -> None:
    update = AppointmentStatusUpdate(status=AppointmentStatus.CONFIRMED)
    assert update.status == AppointmentStatus.CONFIRMED


def test_appointment_status_update_accepts_cancelled() -> None:
    update = AppointmentStatusUpdate(status=AppointmentStatus.CANCELLED)
    assert update.status == AppointmentStatus.CANCELLED


def test_appointment_status_update_accepts_completed() -> None:
    update = AppointmentStatusUpdate(status=AppointmentStatus.COMPLETED)
    assert update.status == AppointmentStatus.COMPLETED


def test_appointment_status_update_invalid_status_raises_validation_error() -> None:
    with pytest.raises(ValidationError):
        AppointmentStatusUpdate.model_validate({"status": "invalid_status_value"})


def test_appointment_status_update_extra_business_id_rejected() -> None:
    with pytest.raises(ValidationError) as exc_info:
        AppointmentStatusUpdate.model_validate({
            "status": "confirmed",
            "business_id": str(uuid4()),
        })
    assert "extra_forbidden" in str(exc_info.value) or "Extra inputs are not permitted" in str(exc_info.value)


def test_appointment_status_update_extra_appointment_id_rejected() -> None:
    with pytest.raises(ValidationError) as exc_info:
        AppointmentStatusUpdate.model_validate({
            "status": "confirmed",
            "appointment_id": str(uuid4()),
        })
    assert "extra_forbidden" in str(exc_info.value) or "Extra inputs are not permitted" in str(exc_info.value)


def test_appointment_status_update_extra_unknown_field_rejected() -> None:
    with pytest.raises(ValidationError) as exc_info:
        AppointmentStatusUpdate.model_validate({
            "status": "cancelled",
            "cancellation_reason": "Customer called to cancel",
        })
    assert "extra_forbidden" in str(exc_info.value) or "Extra inputs are not permitted" in str(exc_info.value)
