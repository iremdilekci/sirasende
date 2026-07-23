from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class GoogleCalendarConnectionStatusResponse(BaseModel):
    connected: bool
    google_account_email: Optional[str] = None
    connected_at: Optional[datetime] = None
    granted_scopes: Optional[str] = None


class GoogleCalendarConnectResponse(BaseModel):
    authorization_url: str
