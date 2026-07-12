from datetime import date, datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_serializer, field_validator

from app.models.appointment import AppointmentStatus


class AppointmentCreate(BaseModel):
    customer_name: str = Field(..., min_length=2, max_length=200)
    customer_phone: str = Field(..., min_length=5, max_length=30)
    appointment_date: date
    start_time: time
    customer_note: str | None = Field(None, max_length=1000)

    model_config = ConfigDict(extra="forbid")

    @field_validator("customer_name")
    @classmethod
    def clean_name(cls, v: str) -> str:
        trimmed = v.strip()
        if len(trimmed) < 2:
            raise ValueError("customer_name must have at least 2 non-whitespace characters")
        return trimmed

    @field_validator("customer_phone")
    @classmethod
    def clean_phone(cls, v: str) -> str:
        trimmed = v.strip()
        if len(trimmed) < 5:
            raise ValueError("customer_phone must have at least 5 non-whitespace characters")
        return trimmed


class AppointmentOut(BaseModel):
    id: UUID
    business_id: UUID
    customer_name: str
    customer_phone: str
    customer_note: str | None = None
    appointment_date: date
    start_time: time
    end_time: time
    status: AppointmentStatus
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_serializer("start_time", "end_time")
    def serialize_time(self, value: time) -> str:
        return value.strftime("%H:%M")
