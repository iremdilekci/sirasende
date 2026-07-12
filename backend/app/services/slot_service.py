from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime, timedelta, time
from zoneinfo import ZoneInfo

from app.models import Appointment, AppointmentStatus

ISTANBUL_TIMEZONE = ZoneInfo("Europe/Istanbul")


@dataclass(frozen=True, slots=True)
class Slot:
    start_time: time
    end_time: time
    available: bool = True
    reason: str | None = None


def generate_daily_slots(
    working_start_time: time,
    working_end_time: time,
    slot_duration_minutes: int,
) -> list[Slot]:
    """Generate the initial list of naive daily slots based on business working hours and duration."""
    if slot_duration_minutes not in (30, 45, 60):
        raise ValueError("Slot duration must be 30, 45, or 60 minutes.")

    if working_start_time >= working_end_time:
        raise ValueError("Working end time must be after working start time.")

    ref_date = date(2000, 1, 1)
    start_dt = datetime.combine(ref_date, working_start_time)
    end_dt = datetime.combine(ref_date, working_end_time)
    duration = timedelta(minutes=slot_duration_minutes)

    current_dt = start_dt
    slots = []
    while current_dt + duration <= end_dt:
        slots.append(
            Slot(
                start_time=current_dt.time(),
                end_time=(current_dt + duration).time(),
            )
        )
        current_dt += duration

    return slots


def mark_booked_slots(
    slots: Sequence[Slot],
    appointments: Sequence[Appointment],
) -> list[Slot]:
    """Mark slots as booked (available=False, reason='booked') if they overlap with active appointments."""
    new_slots = []
    for slot in slots:
        if not slot.available:
            new_slots.append(slot)
            continue

        is_booked = False
        for app in appointments:
            if app.status in (AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED):
                # Check overlap: slot.start_time < app.end_time and app.start_time < slot.end_time
                if slot.start_time < app.end_time and app.start_time < slot.end_time:
                    is_booked = True
                    break

        if is_booked:
            new_slots.append(
                Slot(
                    start_time=slot.start_time,
                    end_time=slot.end_time,
                    available=False,
                    reason="booked",
                )
            )
        else:
            new_slots.append(slot)

    return new_slots


def get_now_istanbul() -> datetime:
    return datetime.now(ISTANBUL_TIMEZONE)


def mark_past_slots(
    slots: Sequence[Slot],
    selected_date: date,
    now: datetime | None = None,
) -> list[Slot]:
    """Mark slots in the past as unavailable (available=False, reason='past') based on local Turkey Time (Europe/Istanbul)."""
    if now is None:
        now = get_now_istanbul()
    else:
        if now.tzinfo is None:
            raise ValueError("now datetime must be timezone-aware.")
        now = now.astimezone(ISTANBUL_TIMEZONE)

    now_date = now.date()
    now_time = now.time()

    new_slots = []
    for slot in slots:
        # Check if slot is in the past: either date is past, or today and slot.start_time <= current time
        if selected_date < now_date or (selected_date == now_date and slot.start_time <= now_time):
            new_slots.append(
                Slot(
                    start_time=slot.start_time,
                    end_time=slot.end_time,
                    available=False,
                    reason="past",
                )
            )
        else:
            new_slots.append(slot)

    return new_slots

