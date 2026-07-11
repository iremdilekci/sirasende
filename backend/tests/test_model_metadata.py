from sqlalchemy import CheckConstraint, UniqueConstraint

from app.models import AdminUser, Appointment, AppointmentStatus, Business


def _check_constraint_names(model: type[object]) -> set[str]:
    return {
        constraint.name
        for constraint in model.__table__.constraints
        if isinstance(constraint, CheckConstraint) and constraint.name is not None
    }


def test_business_constraints_are_declared() -> None:
    assert _check_constraint_names(Business) == {
        "ck_businesses_slot_duration",
        "ck_businesses_working_hours",
    }


def test_appointment_defaults_to_pending() -> None:
    assert Appointment.status.default is not None
    assert Appointment.status.default.arg == AppointmentStatus.PENDING
    assert Appointment.status.server_default is not None
    assert str(Appointment.status.server_default.arg) == "pending"


def test_appointment_time_constraint_is_declared() -> None:
    assert _check_constraint_names(Appointment) == {"ck_appointments_time_range"}


def test_admin_username_and_email_are_unique() -> None:
    unique_columns = {
        tuple(constraint.columns.keys())
        for constraint in AdminUser.__table__.constraints
        if isinstance(constraint, UniqueConstraint)
    }

    assert ("username",) in unique_columns
    assert ("email",) in unique_columns
