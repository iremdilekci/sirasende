from datetime import date, datetime, time
from zoneinfo import ZoneInfo

import pytest

from app.models import Appointment, AppointmentStatus
from app.schemas.slot import SlotOut
from app.services.slot_service import (
    ISTANBUL_TIMEZONE,
    Slot,
    generate_daily_slots,
    mark_booked_slots,
    mark_past_slots,
)


# ==============================================================================
# Slot Üretimi Testleri
# ==============================================================================

def test_generate_daily_slots_30_minutes() -> None:
    slots = generate_daily_slots(time(9, 0), time(11, 0), 30)
    assert len(slots) == 4
    assert slots[0] == Slot(time(9, 0), time(9, 30))
    assert slots[1] == Slot(time(9, 30), time(10, 0))
    assert slots[2] == Slot(time(10, 0), time(10, 30))
    assert slots[3] == Slot(time(10, 30), time(11, 0))


def test_generate_daily_slots_45_minutes() -> None:
    slots = generate_daily_slots(time(9, 0), time(12, 0), 45)
    assert len(slots) == 4
    assert slots[0] == Slot(time(9, 0), time(9, 45))
    assert slots[1] == Slot(time(9, 45), time(10, 30))
    assert slots[2] == Slot(time(10, 30), time(11, 15))
    assert slots[3] == Slot(time(11, 15), time(12, 0))


def test_generate_daily_slots_60_minutes() -> None:
    slots = generate_daily_slots(time(9, 0), time(12, 0), 60)
    assert len(slots) == 3
    assert slots[0] == Slot(time(9, 0), time(10, 0))
    assert slots[1] == Slot(time(10, 0), time(11, 0))
    assert slots[2] == Slot(time(11, 0), time(12, 0))


def test_generate_daily_slots_excludes_exceeding_end_time() -> None:
    # 09:00 to 10:30 with 60 minutes slot duration
    # 09:00 - 10:00 (Fits)
    # 10:00 - 11:00 (Exceeds 10:30, excluded)
    slots = generate_daily_slots(time(9, 0), time(10, 30), 60)
    assert len(slots) == 1
    assert slots[0] == Slot(time(9, 0), time(10, 0))


def test_generate_daily_slots_includes_exact_end_time() -> None:
    slots = generate_daily_slots(time(9, 0), time(10, 0), 60)
    assert len(slots) == 1
    assert slots[0] == Slot(time(9, 0), time(10, 0))


def test_generate_daily_slots_unsupported_duration() -> None:
    with pytest.raises(ValueError, match="Slot duration must be 30, 45, or 60 minutes."):
        generate_daily_slots(time(9, 0), time(12, 0), 15)


def test_generate_daily_slots_invalid_working_hours() -> None:
    with pytest.raises(ValueError, match="Working end time must be after working start time."):
        generate_daily_slots(time(18, 0), time(9, 0), 30)
    with pytest.raises(ValueError, match="Working end time must be after working start time."):
        generate_daily_slots(time(9, 0), time(9, 0), 30)


# ==============================================================================
# Dolu Slot İşaretleme Testleri
# ==============================================================================

def test_mark_booked_slots_pending_appointment() -> None:
    slots = [
        Slot(time(9, 0), time(9, 30)),
        Slot(time(9, 30), time(10, 0)),
    ]
    apps = [
        Appointment(start_time=time(9, 0), end_time=time(9, 30), status=AppointmentStatus.PENDING)
    ]
    marked = mark_booked_slots(slots, apps)
    assert marked[0] == Slot(time(9, 0), time(9, 30), available=False, reason="booked")
    assert marked[1] == Slot(time(9, 30), time(10, 0), available=True, reason=None)


def test_mark_booked_slots_confirmed_appointment() -> None:
    slots = [
        Slot(time(9, 0), time(9, 30)),
        Slot(time(9, 30), time(10, 0)),
    ]
    apps = [
        Appointment(start_time=time(9, 30), end_time=time(10, 0), status=AppointmentStatus.CONFIRMED)
    ]
    marked = mark_booked_slots(slots, apps)
    assert marked[0] == Slot(time(9, 0), time(9, 30), available=True, reason=None)
    assert marked[1] == Slot(time(9, 30), time(10, 0), available=False, reason="booked")


def test_mark_booked_slots_cancelled_appointment_has_no_effect() -> None:
    slots = [Slot(time(9, 0), time(9, 30))]
    apps = [
        Appointment(start_time=time(9, 0), end_time=time(9, 30), status=AppointmentStatus.CANCELLED)
    ]
    marked = mark_booked_slots(slots, apps)
    assert marked[0].available is True


def test_mark_booked_slots_completed_appointment_has_no_effect() -> None:
    slots = [Slot(time(9, 0), time(9, 30))]
    apps = [
        Appointment(start_time=time(9, 0), end_time=time(9, 30), status=AppointmentStatus.COMPLETED)
    ]
    marked = mark_booked_slots(slots, apps)
    assert marked[0].available is True


def test_mark_booked_slots_partial_overlap_fills_multiple_slots() -> None:
    # Slots: 09:00 - 09:30, 09:30 - 10:00, 10:00 - 10:30
    # Appointment: 09:15 - 10:15 (Overlaps all three slots)
    slots = [
        Slot(time(9, 0), time(9, 30)),
        Slot(time(9, 30), time(10, 0)),
        Slot(time(10, 0), time(10, 30)),
    ]
    apps = [
        Appointment(start_time=time(9, 15), end_time=time(10, 15), status=AppointmentStatus.CONFIRMED)
    ]
    marked = mark_booked_slots(slots, apps)
    assert all(s.available is False for s in marked)
    assert all(s.reason == "booked" for s in marked)


def test_mark_booked_slots_boundary_touch_does_not_fill_next_slot() -> None:
    # Appointment: 09:00 - 09:30
    # Slot: 09:30 - 10:00
    slots = [Slot(time(9, 30), time(10, 0))]
    apps = [
        Appointment(start_time=time(9, 0), end_time=time(9, 30), status=AppointmentStatus.CONFIRMED)
    ]
    marked = mark_booked_slots(slots, apps)
    assert marked[0].available is True


def test_mark_booked_slots_does_not_mutate_input() -> None:
    slots = [Slot(time(9, 0), time(9, 30))]
    apps = [
        Appointment(start_time=time(9, 0), end_time=time(9, 30), status=AppointmentStatus.CONFIRMED)
    ]
    marked = mark_booked_slots(slots, apps)
    assert marked is not slots
    assert slots[0].available is True
    assert marked[0].available is False


# ==============================================================================
# Geçmiş Slot İşaretleme Testleri
# ==============================================================================

def test_mark_past_slots_future_date() -> None:
    # Now: 2026-07-12 10:00
    # Selected date: 2026-07-13
    now = datetime(2026, 7, 12, 10, 0, tzinfo=ISTANBUL_TIMEZONE)
    slots = [Slot(time(9, 0), time(9, 30))]
    marked = mark_past_slots(slots, date(2026, 7, 13), now=now)
    assert marked[0].available is True
    assert marked[0].reason is None


def test_mark_past_slots_today_past_hours() -> None:
    # Now: 2026-07-12 10:00
    # Selected date: 2026-07-12 (Today)
    # Slot at 09:00 - 09:30 is past (start_time 09:00 <= 10:00)
    # Slot at 09:30 - 10:00 is past (start_time 09:30 <= 10:00)
    now = datetime(2026, 7, 12, 10, 0, tzinfo=ISTANBUL_TIMEZONE)
    slots = [
        Slot(time(9, 0), time(9, 30)),
        Slot(time(9, 30), time(10, 0)),
    ]
    marked = mark_past_slots(slots, date(2026, 7, 12), now=now)
    assert all(s.available is False for s in marked)
    assert all(s.reason == "past" for s in marked)


def test_mark_past_slots_today_future_hours() -> None:
    # Now: 2026-07-12 10:00
    # Selected date: 2026-07-12 (Today)
    # Slot at 10:30 - 11:00 is future
    now = datetime(2026, 7, 12, 10, 0, tzinfo=ISTANBUL_TIMEZONE)
    slots = [Slot(time(10, 30), time(11, 0))]
    marked = mark_past_slots(slots, date(2026, 7, 12), now=now)
    assert marked[0].available is True
    assert marked[0].reason is None


def test_mark_past_slots_currently_started_slot_becomes_past() -> None:
    # Now: 2026-07-12 09:15
    # Selected date: 2026-07-12
    # Slot 09:00 - 09:30 has started (09:00 <= 09:15) -> past
    now = datetime(2026, 7, 12, 9, 15, tzinfo=ISTANBUL_TIMEZONE)
    slots = [Slot(time(9, 0), time(9, 30))]
    marked = mark_past_slots(slots, date(2026, 7, 12), now=now)
    assert marked[0].available is False
    assert marked[0].reason == "past"


def test_mark_past_slots_past_date() -> None:
    # Now: 2026-07-12 10:00
    # Selected date: 2026-07-11
    now = datetime(2026, 7, 12, 10, 0, tzinfo=ISTANBUL_TIMEZONE)
    slots = [Slot(time(15, 0), time(15, 30))]
    marked = mark_past_slots(slots, date(2026, 7, 11), now=now)
    assert marked[0].available is False
    assert marked[0].reason == "past"


def test_mark_past_slots_booked_slot_overrides_to_past() -> None:
    # Now: 2026-07-12 10:00
    # Selected date: 2026-07-12
    # Slot 09:00 - 09:30 is booked AND past. Priority should be "past".
    now = datetime(2026, 7, 12, 10, 0, tzinfo=ISTANBUL_TIMEZONE)
    slots = [Slot(time(9, 0), time(9, 30), available=False, reason="booked")]
    marked = mark_past_slots(slots, date(2026, 7, 12), now=now)
    assert marked[0].available is False
    assert marked[0].reason == "past"


def test_mark_past_slots_naive_datetime_raises_value_error() -> None:
    now = datetime(2026, 7, 12, 10, 0)  # Naive
    slots = [Slot(time(9, 0), time(9, 30))]
    with pytest.raises(ValueError, match="now datetime must be timezone-aware."):
        mark_past_slots(slots, date(2026, 7, 12), now=now)


def test_mark_past_slots_converts_other_timezone_to_istanbul() -> None:
    # UTC 07:00 is equal to Istanbul 10:00
    # Selected date: 2026-07-12
    # Slot 09:30 - 10:00 starts at 09:30 <= 10:00 -> past
    # Slot 10:00 - 10:30 starts at 10:00 <= 10:00 -> past
    # Slot 10:30 - 11:00 starts at 10:30 > 10:00 -> future/available
    utc_tz = ZoneInfo("UTC")
    now = datetime(2026, 7, 12, 7, 0, tzinfo=utc_tz)  # UTC 07:00
    slots = [
        Slot(time(9, 30), time(10, 0)),
        Slot(time(10, 0), time(10, 30)),
        Slot(time(10, 30), time(11, 0)),
    ]
    marked = mark_past_slots(slots, date(2026, 7, 12), now=now)
    assert marked[0].available is False
    assert marked[0].reason == "past"
    assert marked[1].available is False
    assert marked[1].reason == "past"
    assert marked[2].available is True


def test_mark_past_slots_does_not_mutate_input() -> None:
    slots = [Slot(time(9, 0), time(9, 30))]
    now = datetime(2026, 7, 12, 10, 0, tzinfo=ISTANBUL_TIMEZONE)
    marked = mark_past_slots(slots, date(2026, 7, 11), now=now)
    assert marked is not slots
    assert slots[0].available is True
    assert marked[0].available is False


# ==============================================================================
# Şema Uyumluluk Testleri
# ==============================================================================

def test_schema_serialization_compat() -> None:
    slot = Slot(time(9, 0), time(9, 30), available=True, reason=None)
    schema = SlotOut.model_validate(slot)
    
    assert schema.start_time == time(9, 0)
    assert schema.end_time == time(9, 30)
    assert schema.available is True
    assert schema.reason is None
    
    # Verify exact JSON formatting
    json_data = schema.model_dump_json()
    import json
    parsed = json.loads(json_data)
    assert parsed["start_time"] == "09:00"
    assert parsed["end_time"] == "09:30"
    assert parsed["available"] is True
    assert parsed["reason"] is None
