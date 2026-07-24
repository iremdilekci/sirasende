from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_business_admin, get_db
from app.core.exceptions import (
    AppointmentCompletionNotAllowedError,
    AppointmentNotFoundError,
    InvalidAppointmentStatusTransitionError,
)
from app.models import AdminUser, Appointment, AppointmentStatus
from app.schemas.admin_appointment import AdminAppointmentOut, AppointmentStatusUpdate
from app.services.admin_appointment_service import (
    change_appointment_status,
    list_admin_appointments,
)

router = APIRouter(prefix="/admin/appointments", tags=["admin-appointments"])


@router.get("", response_model=list[AdminAppointmentOut])
async def get_admin_appointments(
    appointment_date: date | None = Query(default=None, alias="date"),
    status_filter: AppointmentStatus | None = Query(default=None, alias="status"),
    session: AsyncSession = Depends(get_db),
    current_admin: AdminUser = Depends(get_current_active_business_admin),
) -> list[Appointment]:
    """List all appointments for the authenticated admin's business.

    Supports optional `date` and `status` query filters.
    """
    appointments = await list_admin_appointments(
        session,
        business_id=current_admin.business_id,
        appointment_date=appointment_date,
        status=status_filter,
    )
    return list(appointments)


@router.patch("/{appointment_id}/status", response_model=AdminAppointmentOut)
async def update_appointment_status(
    appointment_id: UUID,
    payload: AppointmentStatusUpdate,
    session: AsyncSession = Depends(get_db),
    current_admin: AdminUser = Depends(get_current_active_business_admin),
) -> Appointment:
    """Update the status of an appointment belonging to the admin's business.

    Status transitions follow domain state-machine rules and completion time limits.
    """
    try:
        return await change_appointment_status(
            session,
            business_id=current_admin.business_id,
            appointment_id=appointment_id,
            target_status=payload.status,
        )
    except AppointmentNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appointment not found",
        ) from None
    except InvalidAppointmentStatusTransitionError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Invalid appointment status transition",
        ) from None
    except AppointmentCompletionNotAllowedError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Appointment cannot be completed before its end time",
        ) from None


@router.post("/{appointment_id}/google-calendar/sync", response_model=AdminAppointmentOut)
async def sync_appointment_google_calendar(
    appointment_id: UUID,
    session: AsyncSession = Depends(get_db),
    current_admin: AdminUser = Depends(get_current_active_business_admin),
) -> Appointment:
    """Manually synchronize an appointment to Google Calendar.

    Only confirmed or cancelled appointments belonging to the admin's business can be synchronized.
    Requires an active Google Calendar connection.
    """
    from sqlalchemy import select
    from app.models.appointment import Appointment, AppointmentStatus
    from app.models.google_calendar_connection import GoogleCalendarConnection
    from app.services.google_calendar import GoogleCalendarService

    # 1. Fetch appointment
    stmt = select(Appointment).where(
        Appointment.id == appointment_id,
        Appointment.business_id == current_admin.business_id
    )
    result = await session.execute(stmt)
    appointment = result.scalars().first()

    if not appointment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appointment not found",
        )

    # 2. Validate status: pending cannot be manually synced
    if appointment.status == AppointmentStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bekleyen randevular Google Takvim ile senkronize edilemez.",
        )

    # 3. Check Google connection
    conn_stmt = select(GoogleCalendarConnection).where(
        GoogleCalendarConnection.business_id == current_admin.business_id,
        GoogleCalendarConnection.is_active == True
    )
    conn_result = await session.execute(conn_stmt)
    connection = conn_result.scalars().first()

    if not connection:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aktif bir Google Takvim bağlantısı bulunmamaktadır.",
        )

    # 4. Trigger sync
    await GoogleCalendarService.sync_appointment_to_calendar(session, appointment.id)
    await session.refresh(appointment)

    if appointment.google_calendar_sync_status == "failed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=appointment.google_calendar_last_error or "Senkronizasyon başarısız oldu.",
        )

    return appointment
