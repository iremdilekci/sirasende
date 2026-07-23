from datetime import datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator, model_validator


class BusinessListItem(BaseModel):
    id: UUID
    name: str
    slug: str
    address: str | None = None
    phone: str | None = None
    slot_duration_minutes: int
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class BusinessScheduleOut(BaseModel):
    day_of_week: int
    start_time: time | None = None
    end_time: time | None = None
    is_closed: bool

    model_config = ConfigDict(from_attributes=True)


class BusinessScheduleUpdate(BaseModel):
    day_of_week: int
    start_time: time | None = None
    end_time: time | None = None
    is_closed: bool

    model_config = ConfigDict(from_attributes=True)

    @field_validator("day_of_week")
    @classmethod
    def validate_day_of_week(cls, v: int) -> int:
        if not (0 <= v <= 6):
            raise ValueError("day_of_week must be between 0 and 6")
        return v

    @model_validator(mode="after")
    def validate_schedule_times(self) -> "BusinessScheduleUpdate":
        if not self.is_closed:
            if self.start_time is None or self.end_time is None:
                raise ValueError("start_time and end_time are required for open days")
            if self.end_time <= self.start_time:
                raise ValueError("end_time must be strictly after start_time")
        return self


class BusinessDetail(BaseModel):
    id: UUID
    name: str
    slug: str
    address: str | None = None
    phone: str | None = None
    description: str | None = None
    working_start_time: time
    working_end_time: time
    slot_duration_minutes: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
    schedules: list[BusinessScheduleOut] | None = None

    model_config = ConfigDict(from_attributes=True)

    @field_validator("schedules", mode="after")
    @classmethod
    def sort_schedules(cls, v: list[BusinessScheduleOut] | None) -> list[BusinessScheduleOut] | None:
        if v is not None:
            return sorted(v, key=lambda x: x.day_of_week)
        return v


class BusinessUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    phone: str | None = None
    address: str | None = None
    working_start_time: time | None = None
    working_end_time: time | None = None
    slot_duration_minutes: int | None = None
    schedules: list[BusinessScheduleUpdate] | None = None

    model_config = ConfigDict(from_attributes=True)

    @field_validator("schedules")
    @classmethod
    def validate_schedules_list(cls, v: list[BusinessScheduleUpdate] | None) -> list[BusinessScheduleUpdate] | None:
        if v is not None:
            if len(v) != 7:
                raise ValueError("Schedules list must contain exactly 7 days")
            days = [item.day_of_week for item in v]
            if len(set(days)) != 7 or not all(day in days for day in range(7)):
                raise ValueError("Schedules must cover all days from 0 to 6 with no duplicates")
        return v
