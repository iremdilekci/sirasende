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
