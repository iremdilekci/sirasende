from datetime import date, datetime, time, timezone
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from app.core.exceptions import (
    AppointmentCompletionNotAllowedError,
    AppointmentNotFoundError,
    InvalidAppointmentStatusTransitionError,
)
from app.models.appointment import Appointment, AppointmentStatus
from app.services.admin_appointment_service import change_appointment_status, list_admin_appointments
from app.services.slot_service import ISTANBUL_TIMEZONE

FIXED_NOW = datetime(2026, 7, 12, 10, 15, tzinfo=ISTANBUL_TIMEZONE)


@pytest.fixture(autouse=True)
def mock_now_istanbul(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.services.admin_appointment_service.get_now_istanbul", lambda: FIXED_NOW)
    monkeypatch.setattr("app.services.slot_service.get_now_istanbul", lambda: FIXED_NOW)


def _make_appointment(
    business_id=None,
    appointment_id=None,
    appointment_date=date(2026, 7, 10),
    start_time=time(9, 0),
    end_time=time(9, 30),
    status=AppointmentStatus.PENDING,
) -> Appointment:
    apt = Appointment(
        id=appointment_id or uuid4(),
        business_id=business_id or uuid4(),
        customer_name="Test Customer",
        customer_phone="05551112233",
        appointment_date=appointment_date,
        start_time=start_time,
        end_time=end_time,
        status=status,
    )
    return apt


# ---------------------------------------------------------------------------
# LISTING UNIT TESTS
# ---------------------------------------------------------------------------


async def test_list_admin_appointments_delegates_to_repository(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    b_id = uuid4()
    mock_list = AsyncMock(return_value=[])
    monkeypatch.setattr("app.services.admin_appointment_service.list_appointments_for_business", mock_list)

    res = await list_admin_appointments(
        session,
        business_id=b_id,
        appointment_date=date(2026, 7, 12),
        status=AppointmentStatus.PENDING,
    )

    assert res == []
    mock_list.assert_called_once_with(
        session,
        business_id=b_id,
        appointment_date=date(2026, 7, 12),
        status=AppointmentStatus.PENDING,
    )


# ---------------------------------------------------------------------------
# APPOINTMENT NOT FOUND TESTS & ROLLBACK
# ---------------------------------------------------------------------------


async def test_change_status_not_found_raises_exception_and_rolls_back(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    b_id = uuid4()
    apt_id = uuid4()

    mock_get = AsyncMock(return_value=None)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    with pytest.raises(AppointmentNotFoundError):
        await change_appointment_status(
            session,
            business_id=b_id,
            appointment_id=apt_id,
            target_status=AppointmentStatus.CONFIRMED,
        )

    mock_get.assert_called_once_with(session, appointment_id=apt_id, business_id=b_id)
    session.rollback.assert_called_once()


# ---------------------------------------------------------------------------
# IDEMPOTENCY TESTS & COMMIT RELEASE
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "status",
    [
        AppointmentStatus.PENDING,
        AppointmentStatus.CONFIRMED,
        AppointmentStatus.CANCELLED,
        AppointmentStatus.COMPLETED,
    ],
)
async def test_change_status_idempotent_commits_and_returns_existing(monkeypatch: pytest.MonkeyPatch, status: AppointmentStatus) -> None:
    session = AsyncMock()
    b_id = uuid4()
    apt = _make_appointment(business_id=b_id, status=status)

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    result = await change_appointment_status(
        session,
        business_id=b_id,
        appointment_id=apt.id,
        target_status=status,
    )

    assert result == apt
    # Commit must be called to release FOR UPDATE row lock!
    session.commit.assert_called_once()
    session.flush.assert_not_called()
    session.rollback.assert_not_called()


# ---------------------------------------------------------------------------
# VALID TRANSITION TESTS & UPDATED_AT TIMESTAMP SOURCING
# ---------------------------------------------------------------------------


async def test_change_status_pending_to_confirmed_updates_timestamp(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    b_id = uuid4()
    apt = _make_appointment(business_id=b_id, status=AppointmentStatus.PENDING)

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    res = await change_appointment_status(
        session,
        business_id=b_id,
        appointment_id=apt.id,
        target_status=AppointmentStatus.CONFIRMED,
        now=FIXED_NOW,
    )

    assert res.status == AppointmentStatus.CONFIRMED
    assert res.updated_at == FIXED_NOW.astimezone(timezone.utc)
    session.flush.assert_called_once()
    session.commit.assert_called_once()


async def test_change_status_pending_to_cancelled(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    b_id = uuid4()
    apt = _make_appointment(business_id=b_id, status=AppointmentStatus.PENDING)

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    res = await change_appointment_status(
        session,
        business_id=b_id,
        appointment_id=apt.id,
        target_status=AppointmentStatus.CANCELLED,
        now=FIXED_NOW,
    )

    assert res.status == AppointmentStatus.CANCELLED
    assert res.updated_at == FIXED_NOW.astimezone(timezone.utc)


async def test_change_status_confirmed_to_cancelled(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    b_id = uuid4()
    apt = _make_appointment(business_id=b_id, status=AppointmentStatus.CONFIRMED)

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    res = await change_appointment_status(
        session,
        business_id=b_id,
        appointment_id=apt.id,
        target_status=AppointmentStatus.CANCELLED,
        now=FIXED_NOW,
    )

    assert res.status == AppointmentStatus.CANCELLED
    assert res.updated_at == FIXED_NOW.astimezone(timezone.utc)


async def test_change_status_confirmed_to_completed_after_end_time(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    b_id = uuid4()
    # End time 10:00 on 2026-07-12; FIXED_NOW is 10:15 on 2026-07-12
    apt = _make_appointment(
        business_id=b_id,
        appointment_date=date(2026, 7, 12),
        start_time=time(9, 30),
        end_time=time(10, 0),
        status=AppointmentStatus.CONFIRMED,
    )

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    res = await change_appointment_status(
        session,
        business_id=b_id,
        appointment_id=apt.id,
        target_status=AppointmentStatus.COMPLETED,
        now=FIXED_NOW,
    )

    assert res.status == AppointmentStatus.COMPLETED
    assert res.updated_at == FIXED_NOW.astimezone(timezone.utc)


# ---------------------------------------------------------------------------
# INVALID TRANSITION TESTS & ROLLBACK
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("current", "target"),
    [
        (AppointmentStatus.PENDING, AppointmentStatus.COMPLETED),
        (AppointmentStatus.CONFIRMED, AppointmentStatus.PENDING),
        (AppointmentStatus.CANCELLED, AppointmentStatus.PENDING),
        (AppointmentStatus.CANCELLED, AppointmentStatus.CONFIRMED),
        (AppointmentStatus.CANCELLED, AppointmentStatus.COMPLETED),
        (AppointmentStatus.COMPLETED, AppointmentStatus.PENDING),
        (AppointmentStatus.COMPLETED, AppointmentStatus.CONFIRMED),
        (AppointmentStatus.COMPLETED, AppointmentStatus.CANCELLED),
    ],
)
async def test_invalid_status_transitions_raise_exception_and_rollback(monkeypatch: pytest.MonkeyPatch, current: AppointmentStatus, target: AppointmentStatus) -> None:
    session = AsyncMock()
    b_id = uuid4()
    apt = _make_appointment(business_id=b_id, status=current)

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    with pytest.raises(InvalidAppointmentStatusTransitionError) as exc_info:
        await change_appointment_status(
            session,
            business_id=b_id,
            appointment_id=apt.id,
            target_status=target,
        )

    assert exc_info.value.current_status == current.value
    assert exc_info.value.target_status == target.value
    session.rollback.assert_called_once()


# ---------------------------------------------------------------------------
# COMPLETION TIME RULES & ROLLBACK
# ---------------------------------------------------------------------------


async def test_completion_before_end_time_raises_exception_and_rolls_back(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    b_id = uuid4()
    # End time 11:00 on 2026-07-12; now is 10:15 on 2026-07-12
    apt = _make_appointment(
        business_id=b_id,
        appointment_date=date(2026, 7, 12),
        start_time=time(10, 30),
        end_time=time(11, 0),
        status=AppointmentStatus.CONFIRMED,
    )

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    with pytest.raises(AppointmentCompletionNotAllowedError):
        await change_appointment_status(
            session,
            business_id=b_id,
            appointment_id=apt.id,
            target_status=AppointmentStatus.COMPLETED,
            now=FIXED_NOW,
        )

    session.rollback.assert_called_once()


async def test_completion_exact_end_time_allowed(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    b_id = uuid4()
    exact_now = datetime(2026, 7, 12, 11, 0, tzinfo=ISTANBUL_TIMEZONE)
    apt = _make_appointment(
        business_id=b_id,
        appointment_date=date(2026, 7, 12),
        start_time=time(10, 30),
        end_time=time(11, 0),
        status=AppointmentStatus.CONFIRMED,
    )

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    res = await change_appointment_status(
        session,
        business_id=b_id,
        appointment_id=apt.id,
        target_status=AppointmentStatus.COMPLETED,
        now=exact_now,
    )

    assert res.status == AppointmentStatus.COMPLETED
    assert res.updated_at == exact_now.astimezone(timezone.utc)


# ---------------------------------------------------------------------------
# TRANSACTION FLUSH / COMMIT FAILURE TESTS
# ---------------------------------------------------------------------------


async def test_exception_during_flush_triggers_rollback(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    session.flush.side_effect = RuntimeError("DB error during flush")

    b_id = uuid4()
    apt = _make_appointment(business_id=b_id, status=AppointmentStatus.PENDING)

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    with pytest.raises(RuntimeError, match="DB error during flush"):
        await change_appointment_status(
            session,
            business_id=b_id,
            appointment_id=apt.id,
            target_status=AppointmentStatus.CONFIRMED,
        )

    session.rollback.assert_called_once()


async def test_exception_during_commit_triggers_rollback(monkeypatch: pytest.MonkeyPatch) -> None:
    session = AsyncMock()
    session.commit.side_effect = RuntimeError("DB error during commit")

    b_id = uuid4()
    apt = _make_appointment(business_id=b_id, status=AppointmentStatus.PENDING)

    mock_get = AsyncMock(return_value=apt)
    monkeypatch.setattr("app.services.admin_appointment_service.get_appointment_for_business_for_update", mock_get)

    with pytest.raises(RuntimeError, match="DB error during commit"):
        await change_appointment_status(
            session,
            business_id=b_id,
            appointment_id=apt.id,
            target_status=AppointmentStatus.CONFIRMED,
        )

    session.rollback.assert_called_once()
