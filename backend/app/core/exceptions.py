class BusinessNotFoundError(Exception):
    """Raised when a business with the specified slug is not found or is inactive."""
    pass


class PastAppointmentError(Exception):
    """Raised when trying to book an appointment in the past (date or time)."""
    pass


class InvalidAppointmentSlotError(Exception):
    """Raised when the requested start time does not match any valid slot for the business."""
    pass


class AppointmentConflictError(Exception):
    """Raised when the requested slot is already booked by another active appointment."""
    pass


class InvalidCredentialsError(Exception):
    """Raised when the username/email or password is incorrect."""
    pass


class InvalidTokenError(Exception):
    """Raised when a JWT token is invalid, expired, or has incorrect claims."""
    pass


class AmbiguousIdentifierError(Exception):
    """Raised when an identifier matches multiple users (e.g. username/email crossover)."""
    pass


class AppointmentNotFoundError(Exception):
    """Raised when an appointment is not found or does not belong to the specified business."""
    pass


class InvalidAppointmentStatusTransitionError(Exception):
    """Raised when an invalid appointment status transition is attempted."""

    def __init__(self, current_status: str, target_status: str, message: str | None = None) -> None:
        self.current_status = current_status
        self.target_status = target_status
        if message is None:
            message = f"Cannot transition appointment status from '{current_status}' to '{target_status}'."
        super().__init__(message)


class AppointmentCompletionNotAllowedError(Exception):
    """Raised when trying to complete an appointment before its end time has passed."""
    pass
