from collections.abc import Sequence

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db
from app.repositories.business_repository import (
    get_active_business_by_slug,
    list_active_businesses,
)
from app.schemas.business import BusinessDetail, BusinessListItem

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
