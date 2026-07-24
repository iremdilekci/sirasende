from collections.abc import Sequence
from datetime import date, datetime, timezone
import logging
from uuid import UUID

logger = logging.getLogger(__name__)

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import (
    AppointmentCompletionNotAllowedError,
    AppointmentNotFoundError,
    InvalidAppointmentStatusTransitionError,
)
from app.models.appointment import Appointment, AppointmentStatus
from app.repositories.appointment_repository import (
    get_appointment_for_business_for_update,
    list_appointments_for_business,
)
from app.services.slot_service import ISTANBUL_TIMEZONE, get_now_istanbul

# Allowed status transition map (excluding self/idempotent transitions)
ALLOWED_TRANSITIONS: dict[AppointmentStatus, set[AppointmentStatus]] = {
    AppointmentStatus.PENDING: {
        AppointmentStatus.CONFIRMED,
        AppointmentStatus.CANCELLED,
    },
    AppointmentStatus.CONFIRMED: {
        AppointmentStatus.CANCELLED,
        AppointmentStatus.COMPLETED,
    },
    AppointmentStatus.CANCELLED: set(),
    AppointmentStatus.COMPLETED: set(),
}


async def list_admin_appointments(
    session: AsyncSession,
    *,
    business_id: UUID,
    appointment_date: date | None = None,
    status: AppointmentStatus | None = None,
) -> Sequence[Appointment]:
    """Retrieve all appointments for a business with optional date and status filters."""
    return await list_appointments_for_business(
        session,
        business_id=business_id,
        appointment_date=appointment_date,
        status=status,
    )


async def change_appointment_status(
    session: AsyncSession,
    *,
    business_id: UUID,
    appointment_id: UUID,
    target_status: AppointmentStatus,
    now: datetime | None = None,
) -> Appointment:
    """Change the status of an appointment in a row-locked transaction.

    Throws:
        AppointmentNotFoundError: If appointment is not found for the business.
        InvalidAppointmentStatusTransitionError: If the transition is prohibited.
        AppointmentCompletionNotAllowedError: If completion is requested before end_time.
    """
    # 1. Resolve time source for both completion check and updated_at
    if now is None:
        resolved_now = get_now_istanbul()
    else:
        if now.tzinfo is None:
            raise ValueError("now datetime must be timezone-aware.")
        resolved_now = now.astimezone(ISTANBUL_TIMEZONE)

    try:
        # 2. Fetch appointment with row lock
        appointment = await get_appointment_for_business_for_update(
            session,
            appointment_id=appointment_id,
            business_id=business_id,
        )
        if appointment is None:
            raise AppointmentNotFoundError("Appointment not found")

        current_status = appointment.status

        # 3. Idempotent check: commit to release row lock and return
        if current_status == target_status:
            await session.commit()
            return appointment

        # 4. Validate status transition matrix
        allowed_targets = ALLOWED_TRANSITIONS.get(current_status, set())
        if target_status not in allowed_targets:
            raise InvalidAppointmentStatusTransitionError(
                current_status=current_status.value,
                target_status=target_status.value,
            )

        # 5. Check completion time rule
        if target_status == AppointmentStatus.COMPLETED:
            appointment_end = datetime.combine(
                appointment.appointment_date,
                appointment.end_time,
                tzinfo=ISTANBUL_TIMEZONE,
            )
            if resolved_now < appointment_end:
                raise AppointmentCompletionNotAllowedError(
                    "Cannot mark appointment as completed before its end time has passed."
                )

        # 6. Mutate status, update timestamp derived from resolved_now, flush, and commit
        appointment.status = target_status
        appointment.updated_at = resolved_now.astimezone(timezone.utc)

        await session.flush()
        await session.commit()
        await session.refresh(appointment)

        try:
            from app.services.google_calendar import GoogleCalendarService
            await GoogleCalendarService.sync_appointment_to_calendar(session, appointment.id)
            await session.refresh(appointment)
        except Exception as e:
            # Resilient to calendar failures, they should not crash the status update
            logger.error(f"Failed to run calendar sync after status update: {e}")

        return appointment

    except Exception:
        await session.rollback()
        raise
