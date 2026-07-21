from collections.abc import Sequence
from datetime import date, time
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.appointment import Appointment, AppointmentStatus


async def list_active_appointments_by_date(
    session: AsyncSession,
    business_id: UUID,
    appointment_date: date,
) -> Sequence[Appointment]:
    """Retrieve active appointments (pending or confirmed) for a business on a specific date,

    ordered by start_time.
    """
    stmt = (
        select(Appointment)
        .where(
            Appointment.business_id == business_id,
            Appointment.appointment_date == appointment_date,
            Appointment.status.in_([AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED]),
        )
        .order_by(Appointment.start_time)
    )
    result = await session.scalars(stmt)
    return result.all()


async def get_active_appointment_for_slot(
    session: AsyncSession,
    business_id: UUID,
    appointment_date: date,
    start_time: time,
) -> Appointment | None:
    """Retrieve an active appointment (pending or confirmed) for a business at a specific date and start time."""
    stmt = (
        select(Appointment)
        .where(
            Appointment.business_id == business_id,
            Appointment.appointment_date == appointment_date,
            Appointment.start_time == start_time,
            Appointment.status.in_([AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED]),
        )
    )
    result = await session.scalars(stmt)
    return result.first()


async def add_appointment(
    session: AsyncSession,
    appointment: Appointment,
) -> Appointment:
    """Add a transient appointment instance to the database session and flush changes."""
    session.add(appointment)
    await session.flush()
    return appointment


async def list_appointments_for_business(
    session: AsyncSession,
    *,
    business_id: UUID,
    appointment_date: date | None = None,
    status: AppointmentStatus | None = None,
) -> Sequence[Appointment]:
    """Retrieve all appointments for a business with optional date and status filters,

    ordered by appointment_date, start_time, and created_at ascending.
    """
    stmt = select(Appointment).where(Appointment.business_id == business_id)

    if appointment_date is not None:
        stmt = stmt.where(Appointment.appointment_date == appointment_date)

    if status is not None:
        stmt = stmt.where(Appointment.status == status)

    stmt = stmt.order_by(
        Appointment.appointment_date.asc(),
        Appointment.start_time.asc(),
        Appointment.created_at.asc(),
    )
    result = await session.scalars(stmt)
    return result.all()


async def get_appointment_for_business(
    session: AsyncSession,
    *,
    appointment_id: UUID,
    business_id: UUID,
) -> Appointment | None:
    """Retrieve an appointment by id scoped to a specific business."""
    stmt = select(Appointment).where(
        Appointment.id == appointment_id,
        Appointment.business_id == business_id,
    )
    result = await session.scalars(stmt)
    return result.first()


async def get_appointment_for_business_for_update(
    session: AsyncSession,
    *,
    appointment_id: UUID,
    business_id: UUID,
) -> Appointment | None:
    """Retrieve an appointment by id scoped to a specific business with row-level locking (FOR UPDATE)."""
    stmt = (
        select(Appointment)
        .where(
            Appointment.id == appointment_id,
            Appointment.business_id == business_id,
        )
        .with_for_update()
    )
    result = await session.scalars(stmt)
    return result.first()
