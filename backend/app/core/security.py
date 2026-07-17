from datetime import datetime, timedelta, timezone
from uuid import UUID
import jwt
from pwdlib import PasswordHash
from pwdlib.exceptions import PwdlibError
from app.core.config import settings
from app.core.exceptions import InvalidTokenError

password_hash_helper = PasswordHash.recommended()


def hash_password(password: str) -> str:
    """Hash a plaintext password using Argon2."""
    return password_hash_helper.hash(password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    """Verify a plaintext password against an Argon2 hash."""
    try:
        return password_hash_helper.verify(plain_password, password_hash)
    except PwdlibError:
        return False


def create_access_token(subject: UUID | str, expires_delta: timedelta | None = None) -> str:
    """Create a signed JWT access token with timezone-aware UTC datetime."""
    now_utc = datetime.now(timezone.utc)
    if expires_delta is not None:
        expire = now_utc + expires_delta
    else:
        expire = now_utc + timedelta(minutes=settings.jwt_access_token_expire_minutes)

    to_encode = {
        "sub": str(subject),
        "iat": now_utc,
        "exp": expire,
        "type": "access",
    }

    encoded_jwt = jwt.encode(
        to_encode,
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )
    return encoded_jwt


def decode_access_token(token: str, secret: str | None = None) -> dict:
    """Decode and validate a JWT access token, converting JWT exceptions to InvalidTokenError.

    Note:
        We use an optional secret parameter here instead of monkeypatching settings.jwt_secret_key
        in tests to prevent side effects, cache pollution, or race conditions in parallel test
        execution environments.
    """
    key = secret if secret is not None else settings.jwt_secret_key
    try:
        payload = jwt.decode(
            token,
            key,
            algorithms=[settings.jwt_algorithm],
            options={"require": ["exp", "sub"]},
        )

        if not isinstance(payload, dict):
            raise InvalidTokenError("Invalid token payload structure")

        if payload.get("type") != "access":
            raise InvalidTokenError("Invalid token type")

        sub = payload.get("sub")
        if not sub or not isinstance(sub, str) or not sub.strip():
            raise InvalidTokenError("Invalid or empty subject claim")

        try:
            UUID(sub)
        except ValueError as e:
            raise InvalidTokenError("Subject claim is not a valid UUID") from e

        return payload
    except jwt.ExpiredSignatureError as e:
        raise InvalidTokenError("Token has expired") from e
    except jwt.InvalidTokenError as e:
        # jwt.InvalidTokenError subclasses caught here include:
        # - jwt.DecodeError: for malformed signatures or structures
        # - jwt.InvalidAlgorithmError: for unsupported algorithms
        # - jwt.InvalidSignatureError: for incorrect signature keys
        # - jwt.InvalidKeyError: for key format issues
        # - jwt.MissingRequiredClaimError: for missing exp or sub claims
        raise InvalidTokenError("Invalid token") from e
