import logging
from datetime import datetime, timezone, timedelta
import urllib.parse
from typing import Any, Dict, Optional
import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.appointment import Appointment, GoogleCalendarSyncStatus, AppointmentStatus
from app.models.google_calendar_connection import GoogleCalendarConnection
from app.services.google_encryption import decrypt_token
from app.services.google_oauth import GoogleOAuthService

logger = logging.getLogger(__name__)

class GoogleCalendarService:
    @staticmethod
    async def _get_fresh_access_token(db: AsyncSession, connection: GoogleCalendarConnection) -> str:
        """Decrypts refresh token, requests a new access token from Google OAuth API,
        updates the connection expiry in database, and returns the token.
        If refresh token is invalid/revoked, marks the connection as inactive.
        """
        # Ensure config is valid
        GoogleOAuthService._validate_config()

        try:
            refresh_token = decrypt_token(connection.encrypted_refresh_token)
        except Exception as e:
            logger.error(f"Failed to decrypt refresh token for business {connection.business_id}: {e}")
            connection.is_active = False
            await db.commit()
            raise ValueError("Google bağlantı yetkilendirme anahtarı çözülemedi.")

        url = "https://oauth2.googleapis.com/token"
        data = {
            "client_id": settings.google_client_id,
            "client_secret": settings.google_client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(url, data=data)
                
                # Check for token revocation / invalid grant
                if resp.status_code == 400:
                    err_data = resp.json()
                    error_code = err_data.get("error", "")
                    if error_code in ["invalid_grant", "invalid_request", "unauthorized_client"]:
                        logger.warning(f"Google refresh token is invalid/revoked for business {connection.business_id}. Deactivating connection.")
                        connection.is_active = False
                        await db.commit()
                        raise ValueError("Google bağlantı izni iptal edilmiş veya süresi dolmuş.")

                if resp.status_code != 200:
                    raise ValueError(f"Google access token yenilenemedi (HTTP {resp.status_code})")

                token_data = resp.json()
                access_token = token_data.get("access_token")
                expires_in = token_data.get("expires_in", 3600)

                if not access_token:
                    raise ValueError("Google yanıtında access_token bulunamadı.")

                # Update expiry
                connection.token_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
                await db.commit()
                return access_token

        except httpx.RequestError as exc:
            logger.error(f"HTTP request error during token refresh: {exc}")
            raise ValueError("Google sunucusuna erişilemedi, lütfen tekrar deneyin.")

    @classmethod
    async def create_calendar_event(cls, db: AsyncSession, connection: GoogleCalendarConnection, appointment: Appointment) -> str:
        """Creates a Google Calendar event for the given appointment."""
        access_token = await cls._get_fresh_access_token(db, connection)

        # Get business name
        business_name = "SıraSende İşletmesi"
        if appointment.business_id:
            from app.models.business import Business
            stmt = select(Business.name).where(Business.id == appointment.business_id)
            biz_res = await db.execute(stmt)
            biz_name = biz_res.scalar()
            if biz_name:
                business_name = biz_name

        # Parse start and end datetimes
        date_str = appointment.appointment_date.isoformat()
        start_time_str = appointment.start_time.isoformat()
        end_time_str = appointment.end_time.isoformat()

        # Build timezone-aware ISO strings for Europe/Istanbul
        start_datetime = f"{date_str}T{start_time_str}"
        end_datetime = f"{date_str}T{end_time_str}"

        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }

        description = (
            f"İşletme Adı: {business_name}\n"
            f"Müşteri Adı: {appointment.customer_name}\n"
            f"Müşteri Telefon: {appointment.customer_phone}\n"
            f"Randevu Durumu: Onaylandı\n"
        )
        if appointment.customer_note:
            description += f"Müşteri Notu: {appointment.customer_note}\n"
        description += "\nBu randevu SıraSende uygulaması üzerinden otomatik olarak senkronize edilmiştir."

        body = {
            "summary": f"SıraSende - {appointment.customer_name}",
            "description": description,
            "start": {
                "dateTime": start_datetime,
                "timeZone": "Europe/Istanbul"
            },
            "end": {
                "dateTime": end_datetime,
                "timeZone": "Europe/Istanbul"
            },
            "extendedProperties": {
                "private": {
                    "sirasende_appointment_id": str(appointment.id),
                    "sirasende_business_id": str(appointment.business_id)
                }
            }
        }

        url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(url, headers=headers, json=body)
            if resp.status_code != 200:
                logger.error(f"Failed to create Google Calendar event (HTTP {resp.status_code}): {resp.text}")
                raise ValueError(f"Google Takvim etkinliği oluşturulamadı: {resp.text}")
            
            event_data = resp.json()
            return event_data["id"]

    @classmethod
    async def delete_calendar_event(cls, db: AsyncSession, connection: GoogleCalendarConnection, event_id: str) -> None:
        """Deletes a Google Calendar event by ID."""
        access_token = await cls._get_fresh_access_token(db, connection)

        headers = {
            "Authorization": f"Bearer {access_token}"
        }

        url = f"https://www.googleapis.com/calendar/v3/calendars/primary/events/{event_id}"
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.delete(url, headers=headers)
            # Idempotent handling: if 404 is returned, we consider it deleted successfully
            if resp.status_code == 404:
                logger.info(f"Google Calendar event {event_id} already deleted (404). Proceeding.")
                return
            if resp.status_code not in [200, 204]:
                logger.error(f"Failed to delete Google Calendar event (HTTP {resp.status_code}): {resp.text}")
                raise ValueError(f"Google Takvim etkinliği silinemedi: {resp.text}")

    @classmethod
    async def find_existing_event_by_extended_property(
        cls, db: AsyncSession, connection: GoogleCalendarConnection, appointment_id: Any
    ) -> Optional[str]:
        """Searches Google Calendar for an event with private extended property 'sirasende_appointment_id'."""
        access_token = await cls._get_fresh_access_token(db, connection)

        headers = {
            "Authorization": f"Bearer {access_token}"
        }

        query_param = f"sirasende_appointment_id={appointment_id}"
        url = f"https://www.googleapis.com/calendar/v3/calendars/primary/events?privateExtendedProperty={urllib.parse.quote(query_param)}"

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url, headers=headers)
            if resp.status_code != 200:
                logger.error(f"Failed to list Google Calendar events (HTTP {resp.status_code}): {resp.text}")
                return None
            
            data = resp.json()
            items = data.get("items", [])
            if items:
                return items[0].get("id")
            return None

    @classmethod
    async def sync_appointment_to_calendar(cls, db: AsyncSession, appointment_id: Any) -> None:
        """Orchestrates Google Calendar sync for an appointment outside database locks."""
        # 1. Fetch appointment
        stmt = select(Appointment).where(Appointment.id == appointment_id)
        result = await db.execute(stmt)
        appointment = result.scalars().first()

        if not appointment:
            logger.error(f"Appointment {appointment_id} not found for sync.")
            return

        # 2. Get active Google Connection
        connection_stmt = select(GoogleCalendarConnection).where(
            GoogleCalendarConnection.business_id == appointment.business_id,
            GoogleCalendarConnection.is_active == True
        )
        conn_result = await db.execute(connection_stmt)
        connection = conn_result.scalars().first()

        if not connection:
            appointment.google_calendar_sync_status = GoogleCalendarSyncStatus.NOT_CONNECTED
            await db.commit()
            return

        # 3. Synchronize based on current appointment status
        status = appointment.status
        event_id = appointment.google_calendar_event_id

        try:
            if status == AppointmentStatus.CONFIRMED:
                # Concurrency-safe check to prevent duplicate creation
                if not event_id:
                    event_id = await cls.find_existing_event_by_extended_property(db, connection, appointment.id)

                if not event_id:
                    # Create the event
                    event_id = await cls.create_calendar_event(db, connection, appointment)

                appointment.google_calendar_event_id = event_id
                appointment.google_calendar_sync_status = GoogleCalendarSyncStatus.SYNCED
                appointment.google_calendar_synced_at = datetime.now(timezone.utc)
                appointment.google_calendar_last_error = None

            elif status == AppointmentStatus.CANCELLED:
                if not event_id:
                    event_id = await cls.find_existing_event_by_extended_property(db, connection, appointment.id)

                if event_id:
                    await cls.delete_calendar_event(db, connection, event_id)

                appointment.google_calendar_sync_status = GoogleCalendarSyncStatus.DELETED
                appointment.google_calendar_synced_at = datetime.now(timezone.utc)
                appointment.google_calendar_last_error = None

            elif status == AppointmentStatus.COMPLETED:
                # Keep event, do nothing. If there was no event initially, do not create one retroactively
                pass

            elif status == AppointmentStatus.PENDING:
                # Pending cannot be synced, should be skipped
                pass

            await db.commit()

        except Exception as err:
            logger.error(f"Error syncing appointment {appointment_id} to Google Calendar: {err}")
            appointment.google_calendar_sync_status = GoogleCalendarSyncStatus.FAILED
            appointment.google_calendar_last_error = str(err)
            await db.commit()
