import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional, Tuple
import urllib.parse

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.google_calendar_connection import GoogleCalendarConnection, GoogleOAuthState
from app.services.google_encryption import decrypt_token, encrypt_token


class GoogleOAuthService:
    @staticmethod
    def _validate_config() -> None:
        """Ensures all required Google settings are set. Throws clear exception otherwise."""
        missing = []
        if not settings.google_client_id:
            missing.append("GOOGLE_CLIENT_ID")
        if not settings.google_client_secret:
            missing.append("GOOGLE_CLIENT_SECRET")
        if not settings.google_oauth_redirect_uri:
            missing.append("GOOGLE_OAUTH_REDIRECT_URI")
        if not settings.google_token_encryption_key:
            missing.append("GOOGLE_TOKEN_ENCRYPTION_KEY")
        if missing:
            raise ValueError(
                f"Missing Google configuration: {', '.join(missing)}. "
                "Please configure these variables in your environment."
            )

    @classmethod
    async def create_auth_url(cls, db: AsyncSession, business_id: Any) -> str:
        """Generates Google authorization URL and stores a secure state."""
        cls._validate_config()

        # Cryptographically secure state
        state_token = secrets.token_urlsafe(32)
        state_hash = hashlib.sha256(state_token.encode("utf-8")).hexdigest()

        # Store in db
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)
        db_state = GoogleOAuthState(
            state_hash=state_hash,
            business_id=business_id,
            expires_at=expires_at,
        )
        db.add(db_state)
        await db.commit()

        # Scopes
        scopes = [
            "https://www.googleapis.com/auth/calendar.events",
            "https://www.googleapis.com/auth/userinfo.email",
            "openid",
        ]
        scope_str = " ".join(scopes)

        # Build url parameters
        params = {
            "client_id": settings.google_client_id,
            "redirect_uri": settings.google_oauth_redirect_uri,
            "response_type": "code",
            "scope": scope_str,
            "state": state_token,
            "access_type": "offline",
            "prompt": "consent",  # Forces Google to return refresh_token on every connection
        }
        encoded_params = urllib.parse.urlencode(params)
        return f"https://accounts.google.com/o/oauth2/v2/auth?{encoded_params}"

    @classmethod
    async def handle_callback(
        cls, db: AsyncSession, state_token: str, code: str
    ) -> Tuple[GoogleCalendarConnection, str]:
        """Validates state, exchanges code for tokens, encrypts refresh_token, gets user profile email and saves connection."""
        cls._validate_config()

        # Resolve state
        state_hash = hashlib.sha256(state_token.encode("utf-8")).hexdigest()
        stmt = select(GoogleOAuthState).where(GoogleOAuthState.state_hash == state_hash)
        result = await db.execute(stmt)
        db_state = result.scalars().first()

        if not db_state:
            raise ValueError("Geçersiz yetkilendirme durumu (state bulunamadı).")

        now = datetime.now(timezone.utc)
        if db_state.expires_at < now:
            raise ValueError("Yetkilendirme süresi doldu. Lütfen tekrar deneyin.")

        if db_state.used_at is not None:
            raise ValueError("Bu yetkilendirme kodu zaten kullanılmış.")

        # Consume state
        db_state.used_at = now
        await db.commit()

        # Exchange code
        tokens = await cls._exchange_code(code)
        access_token = tokens.get("access_token")
        refresh_token = tokens.get("refresh_token")
        expires_in = tokens.get("expires_in", 3600)
        granted_scopes = tokens.get("scope", "")

        if not refresh_token:
            # Check if there is already an existing refresh token for this business to fallback to
            # (In case prompt consent was skipped by user or custom setup)
            stmt = select(GoogleCalendarConnection).where(
                GoogleCalendarConnection.business_id == db_state.business_id
            )
            existing_conn = (await db.execute(stmt)).scalars().first()
            if existing_conn:
                # Decrypt existing refresh token to verify we have it, then keep using it
                refresh_token = decrypt_token(existing_conn.encrypted_refresh_token)
            
            if not refresh_token:
                raise ValueError(
                    "Google offline erişim izni vermedi. "
                    "Lütfen uygulamaya tekrar izin verin ve 'offline_access' veya 'refresh_token' alabildiğinizden emin olun."
                )

        # Get Google email
        google_email = await cls._fetch_google_email(access_token)

        # Encrypt refresh token
        enc_refresh_token = encrypt_token(refresh_token)

        # Save or update connection
        stmt = select(GoogleCalendarConnection).where(
            GoogleCalendarConnection.business_id == db_state.business_id
        )
        result = await db.execute(stmt)
        conn = result.scalars().first()

        token_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in)

        if conn:
            conn.google_account_email = google_email
            conn.encrypted_refresh_token = enc_refresh_token
            conn.granted_scopes = granted_scopes
            conn.is_active = True
            conn.token_expiry = token_expiry
        else:
            conn = GoogleCalendarConnection(
                business_id=db_state.business_id,
                google_account_email=google_email,
                encrypted_refresh_token=enc_refresh_token,
                granted_scopes=granted_scopes,
                is_active=True,
                token_expiry=token_expiry,
            )
            db.add(conn)

        await db.commit()
        await db.refresh(conn)

        return conn, google_email

    @classmethod
    async def disconnect(cls, db: AsyncSession, business_id: Any) -> bool:
        """Revokes token if possible and removes/inactivates Google connection from DB."""
        stmt = select(GoogleCalendarConnection).where(
            GoogleCalendarConnection.business_id == business_id
        )
        result = await db.execute(stmt)
        conn = result.scalars().first()

        if not conn:
            return False

        # Attempt revoke
        try:
            refresh_token = decrypt_token(conn.encrypted_refresh_token)
            await cls._revoke_token(refresh_token)
        except Exception:
            # Resilient disconnect even if token revocation fails
            pass

        # Remove from database
        await db.delete(conn)
        await db.commit()
        return True

    @classmethod
    async def get_connection_status(
        cls, db: AsyncSession, business_id: Any
    ) -> Optional[GoogleCalendarConnection]:
        """Returns active Google connection or None."""
        stmt = select(GoogleCalendarConnection).where(
            GoogleCalendarConnection.business_id == business_id,
            GoogleCalendarConnection.is_active == True,
        )
        result = await db.execute(stmt)
        return result.scalars().first()

    @staticmethod
    async def _exchange_code(code: str) -> Dict[str, Any]:
        """Exchanges authorization code with Google for tokens."""
        url = "https://oauth2.googleapis.com/token"
        data = {
            "code": code,
            "client_id": settings.google_client_id,
            "client_secret": settings.google_client_secret,
            "redirect_uri": settings.google_oauth_redirect_uri,
            "grant_type": "authorization_code",
        }
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(url, data=data)
            if resp.status_code != 200:
                raise ValueError(
                    f"Google yetkilendirme kodu değiştirilemedi: {resp.text}"
                )
            return resp.json()

    @staticmethod
    async def _fetch_google_email(access_token: str) -> str:
        """Fetches connected Google email using access token."""
        url = "https://www.googleapis.com/oauth2/v3/userinfo"
        headers = {"Authorization": f"Bearer {access_token}"}
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url, headers=headers)
            if resp.status_code != 200:
                raise ValueError("Google profil bilgileri alınamadı.")
            data = resp.json()
            email = data.get("email")
            if not email:
                raise ValueError("Google profil yanıtında e-posta adresi bulunamadı.")
            return email

    @staticmethod
    async def _revoke_token(token: str) -> None:
        """Revokes a refresh token at Google API endpoints."""
        url = "https://oauth2.googleapis.com/revoke"
        data = {"token": token}
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(url, data=data)
            # Revocation might return 200 even if already revoked, but we just check status codes
            if resp.status_code not in [200, 400]:
                raise ValueError("Google yetkisi kaldırılamadı.")
