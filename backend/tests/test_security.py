from datetime import timedelta
import time
import pytest
import jwt
from uuid import uuid4

from app.core.exceptions import InvalidTokenError
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    decode_access_token,
)
from app.core.config import settings


def test_password_hash_not_equal_to_plaintext() -> None:
    plaintext = "MySecurePassword123!"
    hashed = hash_password(plaintext)
    assert hashed != plaintext
    assert "$argon2" in hashed


def test_verify_correct_password() -> None:
    plaintext = "MySecurePassword123!"
    hashed = hash_password(plaintext)
    assert verify_password(plaintext, hashed) is True


def test_verify_incorrect_password() -> None:
    plaintext = "MySecurePassword123!"
    hashed = hash_password(plaintext)
    assert verify_password("WrongPassword123!", hashed) is False


def test_access_token_creation_and_decoding() -> None:
    subject = uuid4()
    token = create_access_token(subject)
    payload = decode_access_token(token)

    assert payload["sub"] == str(subject)
    assert payload["type"] == "access"
    assert "exp" in payload
    assert "iat" in payload


def test_access_token_expired_rejected() -> None:
    subject = uuid4()
    # Create token with past expiration delta
    token = create_access_token(subject, expires_delta=timedelta(seconds=-10))
    
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(token)
    assert "expired" in str(exc_info.value).lower()


def test_access_token_wrong_secret_rejected() -> None:
    subject = uuid4()
    token = create_access_token(subject)
    
    # Attempt to decode with a different secret key
    wrong_secret = "completely-different-and-wrong-secret-key-123456"
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(token, secret=wrong_secret)
    assert "invalid" in str(exc_info.value).lower()


def test_access_token_wrong_algorithm_rejected() -> None:
    # Build token manually using HS384 algorithm instead of settings.jwt_algorithm (which is HS256)
    subject = str(uuid4())
    to_encode = {
        "sub": subject,
        "type": "access",
        "exp": int(time.time()) + 60,
    }
    wrong_algo_token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm="HS384")
    
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(wrong_algo_token)
    # Algorithms mismatch raises InvalidTokenError because settings.jwt_algorithm is "HS256"
    assert "invalid" in str(exc_info.value).lower()


def test_access_token_wrong_type_rejected() -> None:
    subject = str(uuid4())
    to_encode = {
        "sub": subject,
        "type": "refresh", # not access
        "exp": int(time.time()) + 60,
    }
    wrong_type_token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(wrong_type_token)
    assert "type" in str(exc_info.value).lower()


def test_verify_password_invalid_hash_format() -> None:
    assert verify_password("plaintext", "invalid_hash_string") is False
    assert verify_password("plaintext", "$argon2id$v=19$m=65536,t=3,p=4$invalid_salt$invalid_hash") is False


def test_default_token_expiration_matches_settings() -> None:
    subject = uuid4()
    before = time.time()
    token = create_access_token(subject)
    after = time.time()
    payload = decode_access_token(token)

    expected_expire_seconds = settings.jwt_access_token_expire_minutes * 60
    actual_expire = payload["exp"]

    assert before + expected_expire_seconds - 5 <= actual_expire <= after + expected_expire_seconds + 5


def test_zero_timedelta_expiration() -> None:
    subject = uuid4()
    token = create_access_token(subject, expires_delta=timedelta(0))
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(token)
    assert "expired" in str(exc_info.value).lower()


def test_missing_exp_claim_rejected() -> None:
    to_encode = {
        "sub": str(uuid4()),
        "type": "access",
    }
    token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(token)
    assert "invalid" in str(exc_info.value).lower()


def test_missing_sub_claim_rejected() -> None:
    to_encode = {
        "type": "access",
        "exp": int(time.time()) + 60,
    }
    token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(token)
    assert "invalid" in str(exc_info.value).lower()


def test_empty_sub_claim_rejected() -> None:
    to_encode = {
        "sub": "   ",
        "type": "access",
        "exp": int(time.time()) + 60,
    }
    token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(token)
    assert "subject" in str(exc_info.value).lower()


def test_non_uuid_sub_claim_rejected() -> None:
    to_encode = {
        "sub": "not-a-uuid",
        "type": "access",
        "exp": int(time.time()) + 60,
    }
    token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(token)
    assert "uuid" in str(exc_info.value).lower()


def test_missing_type_claim_rejected() -> None:
    to_encode = {
        "sub": str(uuid4()),
        "exp": int(time.time()) + 60,
    }
    token = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token(token)
    assert "type" in str(exc_info.value).lower()


def test_malformed_token_rejected() -> None:
    with pytest.raises(InvalidTokenError) as exc_info:
        decode_access_token("malformed.jwt.token")
    assert "invalid" in str(exc_info.value).lower()

