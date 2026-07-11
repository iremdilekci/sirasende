import asyncio
import os
from datetime import time

from pwdlib import PasswordHash
from sqlalchemy import or_, select

from app.core.database import async_session_factory
from app.models import AdminUser, Business


DEMO_BUSINESS_SLUG = "demo-kuafor"
DEMO_ADMIN_USERNAME = "demo_admin"
DEMO_ADMIN_EMAIL = "demo@example.com"


async def seed_database() -> None:
    admin_password = os.getenv("SEED_ADMIN_PASSWORD")
    if not admin_password or admin_password == "change_me":
        raise RuntimeError(
            "SEED_ADMIN_PASSWORD must be set to a non-example value before seeding"
        )

    password_hash = PasswordHash.recommended()

    async with async_session_factory() as session:
        async with session.begin():
            business = await session.scalar(
                select(Business).where(Business.slug == DEMO_BUSINESS_SLUG)
            )
            if business is None:
                business = Business(
                    name="Demo Kuaför",
                    slug=DEMO_BUSINESS_SLUG,
                    description="SıraSende geliştirme ortamı için örnek işletme.",
                    working_start_time=time(9, 0),
                    working_end_time=time(18, 0),
                    slot_duration_minutes=30,
                )
                session.add(business)
                await session.flush()

            admin_user = await session.scalar(
                select(AdminUser).where(
                    or_(
                        AdminUser.username == DEMO_ADMIN_USERNAME,
                        AdminUser.email == DEMO_ADMIN_EMAIL,
                    )
                )
            )
            if admin_user is None:
                session.add(
                    AdminUser(
                        business_id=business.id,
                        username=DEMO_ADMIN_USERNAME,
                        email=DEMO_ADMIN_EMAIL,
                        password_hash=password_hash.hash(admin_password),
                    )
                )

    print("Seed completed; existing demo records were preserved.")


if __name__ == "__main__":
    asyncio.run(seed_database())
