from datetime import datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class BusinessListItem(BaseModel):
    id: UUID
    name: str
    slug: str
    address: str | None = None
    phone: str | None = None
    slot_duration_minutes: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class BusinessDetail(BaseModel):
    id: UUID
    name: str
    slug: str
    address: str | None = None
    phone: str | None = None
    working_start_time: time
    working_end_time: time
    slot_duration_minutes: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
