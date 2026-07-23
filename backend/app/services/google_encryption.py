from cryptography.fernet import Fernet
from app.core.config import settings


def get_fernet() -> Fernet:
    key = settings.google_token_encryption_key
    if not key:
        raise ValueError("GOOGLE_TOKEN_ENCRYPTION_KEY is not set in environment.")
    try:
        # Check that it's a valid key
        return Fernet(key.encode("utf-8"))
    except Exception as e:
        raise ValueError(f"Invalid GOOGLE_TOKEN_ENCRYPTION_KEY: {str(e)}")


def encrypt_token(token: str) -> str:
    fernet = get_fernet()
    return fernet.encrypt(token.encode("utf-8")).decode("utf-8")


def decrypt_token(encrypted_token: str) -> str:
    fernet = get_fernet()
    try:
        return fernet.decrypt(encrypted_token.encode("utf-8")).decode("utf-8")
    except Exception as e:
        raise ValueError(f"Failed to decrypt token: {str(e)}")
