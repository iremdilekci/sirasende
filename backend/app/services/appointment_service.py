from datetime import date, datetime, time

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    AppointmentConflictError,
    BusinessNotFoundError,
    InvalidAppointmentSlotError,
    PastAppointmentError,
)
from app.models.appointment import Appointment, AppointmentStatus
from app.models.business import Business
from app.repositories.appointment_repository import add_appointment, get_active_appointment_for_slot
from app.schemas.appointment import AppointmentCreate
from app.services.slot_service import ISTANBUL_TIMEZONE, generate_daily_slots, get_now_istanbul


from app.models import BusinessSchedule


def resolve_appointment_slot(
    business: Business,
    appointment_date: date,
    requested_start_time: time,
    now: datetime | None = None,
    schedule: BusinessSchedule | None = None,
) -> tuple[time, time]:
    """Validate and resolve start and end times for a requested appointment slot.

    Throws:
        BusinessNotFoundError: If business is inactive.
        PastAppointmentError: If date/time is in the past.
        InvalidAppointmentSlotError: If requested time is not a valid slot start or if day is closed.
    """
    # 1. Validate timezone of now parameter
    if now is None:
        now = get_now_istanbul()
    else:
        if now.tzinfo is None:
            raise ValueError("now datetime must be timezone-aware.")
        now = now.astimezone(ISTANBUL_TIMEZONE)

    # 2. Check business status
    if not business.is_active:
        raise BusinessNotFoundError("Business is inactive.")

    # 3. Check if date is in the past
    today_local = now.date()
    if appointment_date < today_local:
        raise PastAppointmentError("Cannot book appointments for past dates.")

    # 4. Check if time is in the past today
    if appointment_date == today_local:
        if requested_start_time <= now.time():
            raise PastAppointmentError("Cannot book appointments for past hours today.")

    # 5. Check if day is closed in schedule
    if schedule is not None and schedule.is_closed:
        raise InvalidAppointmentSlotError("Cannot book appointments on closed days.")

    # 6. Generate dynamic slots for the business
    start_time = schedule.start_time if (schedule is not None and not schedule.is_closed) else business.working_start_time
    end_time = schedule.end_time if (schedule is not None and not schedule.is_closed) else business.working_end_time

    slots = generate_daily_slots(
        working_start_time=start_time,
        working_end_time=end_time,
        slot_duration_minutes=business.slot_duration_minutes,
    )

    # 7. Verify requested slot exists
    matching_slot = None
    for slot in slots:
        if slot.start_time == requested_start_time:
            matching_slot = slot
            break

    if matching_slot is None:
        raise InvalidAppointmentSlotError("Requested start time does not match any valid slot for the business.")

    return matching_slot.start_time, matching_slot.end_time


def build_pending_appointment(
    business: Business,
    payload: AppointmentCreate,
    now: datetime | None = None,
    schedule: BusinessSchedule | None = None,
) -> Appointment:
    """Validate slot and build a new pending Appointment ORM model instance (not committed)."""
    start_time, end_time = resolve_appointment_slot(
        business=business,
        appointment_date=payload.appointment_date,
        requested_start_time=payload.start_time,
        now=now,
        schedule=schedule,
    )

    appointment = Appointment(
        business_id=business.id,
        customer_name=payload.customer_name,
        customer_phone=payload.customer_phone,
        customer_note=payload.customer_note,
        appointment_date=payload.appointment_date,
        start_time=start_time,
        end_time=end_time,
        status=AppointmentStatus.PENDING,
    )
    return appointment


def _is_unique_slot_violation(exc: IntegrityError) -> bool:
    """Check if the IntegrityError is a unique violation specifically on uq_appointments_active_slot."""
    if hasattr(exc.orig, "constraint_name") and exc.orig.constraint_name == "uq_appointments_active_slot":
        return True

    orig_str = str(exc.orig) if exc.orig else ""
    msg_str = str(exc)

    if "uq_appointments_active_slot" in orig_str or "uq_appointments_active_slot" in msg_str:
        return True

    return False


async def create_appointment(
    session: AsyncSession,
    business: Business,
    payload: AppointmentCreate,
    now: datetime | None = None,
) -> Appointment:
    """Validate, build, check for existing active appointments, and insert a new appointment in a transaction.

    Throws:
        AppointmentConflictError: If slot is already booked (by pre-check or unique constraint violation on commit).
    """
    # 1. Fetch business schedule for the day of week
    from app.repositories.business_repository import get_business_schedule_by_day
    schedule = await get_business_schedule_by_day(
        session,
        business_id=business.id,
        day_of_week=payload.appointment_date.weekday(),
    )

    # 2. Build transient appointment object (resolves times and business status)
    appointment = build_pending_appointment(business, payload, now=now, schedule=schedule)

    # 2. Fast pre-check: query if there's already an active appointment in the slot
    existing = await get_active_appointment_for_slot(
        session,
        business_id=business.id,
        appointment_date=appointment.appointment_date,
        start_time=appointment.start_time,
    )
    if existing is not None:
        raise AppointmentConflictError("Appointment slot is already booked")

    # 3. Add to session and commit transaction
    try:
        await add_appointment(session, appointment)
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        if _is_unique_slot_violation(exc):
            raise AppointmentConflictError("Appointment slot is already booked") from exc
        raise

    # 4. Refresh to populate database-generated fields (id, created_at, updated_at)
    await session.refresh(appointment)
    return appointment
