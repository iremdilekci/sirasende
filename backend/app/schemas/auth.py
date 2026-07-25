from typing import Literal
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field, field_validator


class LoginRequest(BaseModel):
    identifier: str = Field(..., min_length=1, max_length=320)
    password: str = Field(..., min_length=1, repr=False)

    model_config = ConfigDict(extra="forbid")

    @field_validator("identifier")
    @classmethod
    def validate_identifier(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("identifier must not be empty or whitespace only")
        return stripped

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if not v:
            raise ValueError("password must not be empty")
        return v


class TokenResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int


class AdminUserOut(BaseModel):
    id: UUID
    business_id: UUID
    username: str
    email: str
    is_active: bool

    model_config = ConfigDict(from_attributes=True)


class AdminRegistrationRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=30)
    email: str = Field(..., min_length=3, max_length=320)
    password: str = Field(..., min_length=8, repr=False)
    business_name: str = Field(..., min_length=1, max_length=200)
    phone: str | None = Field(None, max_length=30)
    address: str | None = Field(None, max_length=500)
    description: str | None = None
    slot_duration_minutes: Literal[30, 45, 60]

    model_config = ConfigDict(extra="forbid")

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        import re
        v = v.strip().lower()
        if not re.match(r"^[a-z0-9_]{3,30}$", v):
            raise ValueError(
                "Kullanıcı adı yalnızca küçük harf, rakam ve alt çizgi içermeli, 3-30 karakter olmalıdır."
            )
        return v

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        import re
        v = v.strip().lower()
        if not re.match(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$", v):
            raise ValueError("Geçersiz e-posta formatı.")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Şifre en az 8 karakter olmalıdır.")
        if not any(c.isalpha() for c in v):
            raise ValueError("Şifre en az bir harf içermelidir.")
        if not any(c.isdigit() for c in v):
            raise ValueError("Şifre en az bir rakam içermelidir.")
        return v

    @field_validator("business_name")
    @classmethod
    def validate_business_name(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("İşletme adı boş olamaz.")
        return stripped


class AdminRegistrationResponse(BaseModel):
    admin_id: UUID
    business_id: UUID
    username: str
    email: str
    business_name: str
    message: str

    model_config = ConfigDict(from_attributes=True)
