from datetime import date, datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_serializer

from app.models.appointment import AppointmentStatus


class AdminAppointmentOut(BaseModel):
    id: UUID
    customer_name: str
    customer_phone: str
    customer_note: str | None = None
    appointment_date: date
    start_time: time
    end_time: time
    status: AppointmentStatus
    created_at: datetime
    updated_at: datetime
    calendar_sync_status: str = "not_connected"
    calendar_event_created: bool = False
    calendar_sync_error: str | None = None

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("start_time", "end_time")
    def serialize_time(self, value: time) -> str:
        return value.strftime("%H:%M")


class AppointmentStatusUpdate(BaseModel):
    status: AppointmentStatus

    model_config = ConfigDict(extra="forbid")
