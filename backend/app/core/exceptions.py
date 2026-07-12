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
