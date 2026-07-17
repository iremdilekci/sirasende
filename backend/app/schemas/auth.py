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
