from datetime import time
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, Integer, String, Text, Time
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


if TYPE_CHECKING:
    from app.models.admin_user import AdminUser
    from app.models.appointment import Appointment
    from app.models.business_schedule import BusinessSchedule
    from app.models.google_calendar_connection import GoogleCalendarConnection


class Business(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "businesses"
    __table_args__ = (
        CheckConstraint(
            "slot_duration_minutes IN (30, 45, 60)",
            name="ck_businesses_slot_duration",
        ),
        CheckConstraint(
            "working_end_time > working_start_time",
            name="ck_businesses_working_hours",
        ),
    )

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    slug: Mapped[str] = mapped_column(String(200), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    working_start_time: Mapped[time] = mapped_column(Time, nullable=False)
    working_end_time: Mapped[time] = mapped_column(Time, nullable=False)
    slot_duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
    )

    appointments: Mapped[list["Appointment"]] = relationship(
        back_populates="business",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    admin_users: Mapped[list["AdminUser"]] = relationship(
        back_populates="business",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    schedules: Mapped[list["BusinessSchedule"]] = relationship(
        back_populates="business",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    google_connection: Mapped["GoogleCalendarConnection"] = relationship(
        back_populates="business",
        cascade="all, delete-orphan",
        passive_deletes=True,
        uselist=False,
    )
