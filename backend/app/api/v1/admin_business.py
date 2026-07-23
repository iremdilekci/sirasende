from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_admin, get_db
from app.models import AdminUser
from app.repositories.business_repository import get_business_by_id
from app.schemas.business import BusinessDetail, BusinessUpdate

router = APIRouter(prefix="/admin/business", tags=["admin_business"])


@router.get(
    "",
    response_model=BusinessDetail,
    summary="Get current admin's business profile details",
    responses={
        200: {"description": "Business profile retrieved successfully."},
        401: {"description": "Not authenticated."},
        404: {"description": "Business not found."},
    },
)
async def get_my_business(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> BusinessDetail:
    """Retrieve details of the business owned/managed by the current logged-in admin."""
    if not current_admin.business_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin is not associated with any business",
        )
    business = await get_business_by_id(db, current_admin.business_id)
    if business is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Business not found",
        )
    return business


@router.patch(
    "",
    response_model=BusinessDetail,
    summary="Update current admin's business profile details",
    responses={
        200: {"description": "Business profile updated successfully."},
        400: {"description": "Invalid parameters or time constraints."},
        401: {"description": "Not authenticated."},
        404: {"description": "Business not found."},
        422: {"description": "Validation error."},
    },
)
async def update_my_business(
    payload: BusinessUpdate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
) -> BusinessDetail:
    """Update business details for the current admin's business."""
    if not current_admin.business_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin is not associated with any business",
        )
    business = await get_business_by_id(db, current_admin.business_id)
    if business is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Business not found",
        )

    # 1. Custom working hours validations
    if payload.working_start_time is not None or payload.working_end_time is not None:
        start = payload.working_start_time or business.working_start_time
        end = payload.working_end_time or business.working_end_time
        if end <= start:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Working end time must be after working start time.",
            )

    # 2. Update fields
    if payload.name is not None:
        if not payload.name.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Business name cannot be empty.",
            )
        business.name = payload.name
    if payload.description is not None:
        business.description = payload.description
    if payload.phone is not None:
        business.phone = payload.phone
    if payload.address is not None:
        business.address = payload.address
    if payload.working_start_time is not None:
        business.working_start_time = payload.working_start_time
    if payload.working_end_time is not None:
        business.working_end_time = payload.working_end_time
    if payload.slot_duration_minutes is not None:
        if payload.slot_duration_minutes not in (30, 45, 60):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Slot duration must be 30, 45, or 60 minutes.",
            )
        business.slot_duration_minutes = payload.slot_duration_minutes

    db.add(business)
    await db.commit()
    await db.refresh(business)
    return business
