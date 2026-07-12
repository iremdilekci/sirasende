from collections.abc import Sequence
from datetime import date as date_type, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db
from app.repositories.appointment_repository import list_active_appointments_by_date
from app.repositories.business_repository import (
    get_active_business_by_slug,
    list_active_businesses,
)
from app.schemas.business import BusinessDetail, BusinessListItem
from app.schemas.slot import SlotOut
from app.services.slot_service import (
    ISTANBUL_TIMEZONE,
    generate_daily_slots,
    get_now_istanbul,
    mark_booked_slots,
    mark_past_slots,
)

router = APIRouter(tags=["businesses"])


@router.get(
    "/businesses",
    response_model=Sequence[BusinessListItem],
    status_code=status.HTTP_200_OK,
    summary="List active businesses",
)
async def get_businesses(
    db: AsyncSession = Depends(get_db),
) -> Sequence[BusinessListItem]:
    """Retrieve all active businesses, ordered by name.

    Returns an empty list if no active businesses exist.
    """
    return await list_active_businesses(db)


@router.get(
    "/businesses/{slug}",
    response_model=BusinessDetail,
    status_code=status.HTTP_200_OK,
    summary="Get active business details by slug",
)
async def get_business_by_slug(
    slug: str,
    db: AsyncSession = Depends(get_db),
) -> BusinessDetail:
    """Retrieve details of a specific active business using its unique slug.

    Raises a 404 error if the business does not exist or is inactive.
    """
    business = await get_active_business_by_slug(db, slug)
    if business is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Business not found",
        )
    return business


@router.get(
    "/businesses/{slug}/slots",
    response_model=list[SlotOut],
    status_code=status.HTTP_200_OK,
    summary="Get dynamic slots for a business on a specific date",
    responses={
        200: {"description": "List of slots with start/end time and availability."},
        400: {"description": "Query date is in the past."},
        404: {"description": "Business not found or is inactive."},
        422: {"description": "Invalid date query parameter format."},
    },
)
async def get_business_slots(
    slug: str,
    query_date: date_type = Query(..., alias="date", description="Query date for slots in YYYY-MM-DD format"),
    db: AsyncSession = Depends(get_db),
) -> list[SlotOut]:
    """Retrieve available and booked time slots for an active business on a given date.

    Greys out past hours for today's queries and rejects past date queries with a 400 Bad Request error.
    """
    # 1. Fetch active business
    business = await get_active_business_by_slug(db, slug)
    if business is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Business not found",
        )

    # 2. Check if selected date is in the past
    today_local = get_now_istanbul().date()
    if query_date < today_local:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot query slots for past dates",
        )

    # 3. Retrieve active appointments for the business on the given date
    appointments = await list_active_appointments_by_date(
        db,
        business_id=business.id,
        appointment_date=query_date,
    )

    # 4. Generate and mark slots
    slots = generate_daily_slots(
        working_start_time=business.working_start_time,
        working_end_time=business.working_end_time,
        slot_duration_minutes=business.slot_duration_minutes,
    )
    slots = mark_booked_slots(slots, appointments)
    slots = mark_past_slots(slots, query_date)

    return slots

