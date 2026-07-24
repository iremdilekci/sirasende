from datetime import date, datetime, time
from enum import Enum
from typing import TYPE_CHECKING
from uuid import UUID

from sqlalchemy import CheckConstraint, Date, DateTime, Enum as SQLAlchemyEnum, ForeignKey, Index, String, Text, Time, text
from sqlalchemy.dialects.postgresql import UUID as PostgreSQLUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


if TYPE_CHECKING:
    from app.models.business import Business


class AppointmentStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"


class GoogleCalendarSyncStatus(str, Enum):
    NOT_CONNECTED = "not_connected"
    PENDING = "pending"
    SYNCED = "synced"
    FAILED = "failed"
    DELETED = "deleted"


class Appointment(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "appointments"
    __table_args__ = (
        CheckConstraint(
            "end_time > start_time",
            name="ck_appointments_time_range",
        ),
        Index(
            "uq_appointments_active_slot",
            "business_id",
            "appointment_date",
            "start_time",
            unique=True,
            postgresql_where=text("status IN ('pending', 'confirmed')"),
        ),
    )

    business_id: Mapped[UUID] = mapped_column(
        PostgreSQLUUID(as_uuid=True),
        ForeignKey("businesses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    customer_name: Mapped[str] = mapped_column(String(200), nullable=False)
    customer_phone: Mapped[str] = mapped_column(String(30), nullable=False)
    customer_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    appointment_date: Mapped[date] = mapped_column(Date, nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    status: Mapped[AppointmentStatus] = mapped_column(
        SQLAlchemyEnum(
            AppointmentStatus,
            name="appointment_status",
            values_callable=lambda enum_class: [member.value for member in enum_class],
        ),
        nullable=False,
        default=AppointmentStatus.PENDING,
        server_default=AppointmentStatus.PENDING.value,
        index=True,
    )

    # Google Calendar Sync fields
    google_calendar_event_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    google_calendar_sync_status: Mapped[GoogleCalendarSyncStatus] = mapped_column(
        SQLAlchemyEnum(
            GoogleCalendarSyncStatus,
            name="google_calendar_sync_status",
            values_callable=lambda enum_class: [member.value for member in enum_class],
        ),
        nullable=False,
        default=GoogleCalendarSyncStatus.NOT_CONNECTED,
        server_default=GoogleCalendarSyncStatus.NOT_CONNECTED.value,
        index=True,
    )
    google_calendar_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    google_calendar_last_error: Mapped[str | None] = mapped_column(Text, nullable=True)

    @property
    def calendar_sync_status(self) -> str:
        return self.google_calendar_sync_status.value

    @property
    def calendar_event_created(self) -> bool:
        return self.google_calendar_event_id is not None

    @property
    def calendar_sync_error(self) -> str | None:
        return self.google_calendar_last_error

    business: Mapped["Business"] = relationship(back_populates="appointments")
