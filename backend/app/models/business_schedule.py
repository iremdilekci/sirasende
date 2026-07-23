from datetime import time
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Integer, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin

if TYPE_CHECKING:
    from app.models.business import Business


class BusinessSchedule(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "business_schedules"
    __table_args__ = (
        UniqueConstraint("business_id", "day_of_week", name="uq_business_schedules_day"),
        CheckConstraint("day_of_week >= 0 AND day_of_week <= 6", name="ck_business_schedules_day_range"),
        CheckConstraint(
            "is_closed = true OR (start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)",
            name="ck_business_schedules_times",
        ),
    )

    business_id: Mapped[UUID] = mapped_column(
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
    )
    day_of_week: Mapped[int] = mapped_column(Integer, nullable=False)
    start_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    end_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    is_closed: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    business: Mapped["Business"] = relationship(back_populates="schedules")
