import pytest
from datetime import timedelta
from unittest.mock import AsyncMock, MagicMock
from app.core.exceptions import InvalidCredentialsError, AmbiguousIdentifierError
from app.services.auth_service import authenticate_admin, DUMMY_PASSWORD_HASH


@pytest.mark.asyncio
async def test_auth_service_user_not_found(monkeypatch) -> None:
    # 1. User not found -> verify_password called with dummy hash once
    mock_get_identifier = AsyncMock(return_value=None)
    monkeypatch.setattr(
        "app.services.auth_service.get_admin_user_by_identifier",
        mock_get_identifier
    )

    verify_calls = []

    def mock_verify(plain, hashed):
        verify_calls.append((plain, hashed))
        return False

    monkeypatch.setattr("app.services.auth_service.verify_password", mock_verify)

    with pytest.raises(InvalidCredentialsError):
        await authenticate_admin(None, "non_existent_identifier", "password123")

    assert len(verify_calls) == 1
    assert verify_calls[0] == ("password123", DUMMY_PASSWORD_HASH)


@pytest.mark.asyncio
async def test_auth_service_wrong_password(monkeypatch) -> None:
    # 2. User exists, wrong password -> verify_password called with real hash
    user_mock = MagicMock()
    user_mock.password_hash = "real_hash_12345"
    user_mock.is_active = True

    mock_get_identifier = AsyncMock(return_value=user_mock)
    monkeypatch.setattr(
        "app.services.auth_service.get_admin_user_by_identifier",
        mock_get_identifier
    )

    verify_calls = []

    def mock_verify(plain, hashed):
        verify_calls.append((plain, hashed))
        return False

    monkeypatch.setattr("app.services.auth_service.verify_password", mock_verify)

    with pytest.raises(InvalidCredentialsError):
        await authenticate_admin(None, "identifier", "wrong_password")

    assert len(verify_calls) == 1
    assert verify_calls[0] == ("wrong_password", "real_hash_12345")


@pytest.mark.asyncio
async def test_auth_service_inactive_user(monkeypatch) -> None:
    # 3. Inactive user -> password verified first, then raises InvalidCredentialsError
    user_mock = MagicMock()
    user_mock.password_hash = "real_hash_12345"
    user_mock.is_active = False

    mock_get_identifier = AsyncMock(return_value=user_mock)
    monkeypatch.setattr(
        "app.services.auth_service.get_admin_user_by_identifier",
        mock_get_identifier
    )

    verify_calls = []

    def mock_verify(plain, hashed):
        verify_calls.append((plain, hashed))
        return True

    monkeypatch.setattr("app.services.auth_service.verify_password", mock_verify)

    with pytest.raises(InvalidCredentialsError):
        await authenticate_admin(None, "inactive_identifier", "password123")

    # verify_password MUST have been called before checking is_active to avoid timing attack
    assert len(verify_calls) == 1
    assert verify_calls[0] == ("password123", "real_hash_12345")


@pytest.mark.asyncio
async def test_auth_service_success(monkeypatch) -> None:
    # 4. Successful login -> returns access token dict
    user_mock = MagicMock()
    user_mock.id = "user_uuid_val"
    user_mock.password_hash = "real_hash_12345"
    user_mock.is_active = True

    mock_get_identifier = AsyncMock(return_value=user_mock)
    monkeypatch.setattr(
        "app.services.auth_service.get_admin_user_by_identifier",
        mock_get_identifier
    )
    monkeypatch.setattr("app.services.auth_service.verify_password", lambda p, h: True)
    monkeypatch.setattr("app.services.auth_service.create_access_token", lambda sub, expires_delta: "my_token")

    result = await authenticate_admin(None, "identifier", "correct_password")

    assert result["access_token"] == "my_token"
    assert result["token_type"] == "bearer"
    assert "expires_in" in result


@pytest.mark.asyncio
async def test_auth_service_ambiguous_identifier(monkeypatch) -> None:
    # 5. AmbiguousIdentifierError raised -> verify_password called with dummy hash, raises InvalidCredentialsError
    mock_get_identifier = AsyncMock(side_effect=AmbiguousIdentifierError("Ambiguous"))
    monkeypatch.setattr(
        "app.services.auth_service.get_admin_user_by_identifier",
        mock_get_identifier
    )

    verify_calls = []

    def mock_verify(plain, hashed):
        verify_calls.append((plain, hashed))
        return False

    monkeypatch.setattr("app.services.auth_service.verify_password", mock_verify)

    with pytest.raises(InvalidCredentialsError):
        await authenticate_admin(None, "ambiguous_identifier", "password123")

    assert len(verify_calls) == 1
    assert verify_calls[0] == ("password123", DUMMY_PASSWORD_HASH)


@pytest.mark.asyncio
async def test_auth_service_no_http_exceptions(monkeypatch) -> None:
    # 6. Service raises no HTTPExceptions
    mock_get_identifier = AsyncMock(return_value=None)
    monkeypatch.setattr(
        "app.services.auth_service.get_admin_user_by_identifier",
        mock_get_identifier
    )
    monkeypatch.setattr("app.services.auth_service.verify_password", lambda p, h: False)

    try:
        await authenticate_admin(None, "some_id", "password")
    except Exception as exc:
        from fastapi import HTTPException
        assert not isinstance(exc, HTTPException)
        assert isinstance(exc, InvalidCredentialsError)
