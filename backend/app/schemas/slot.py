from datetime import time
from typing import Literal

from pydantic import BaseModel, ConfigDict, field_serializer


class SlotOut(BaseModel):
    start_time: time
    end_time: time
    available: bool
    reason: Literal["booked", "past"] | None = None

    model_config = ConfigDict(from_attributes=True)


    @field_serializer("start_time", "end_time")
    def serialize_time(self, value: time) -> str:
        return value.strftime("%H:%M")
