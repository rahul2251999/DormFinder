from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Listing
from app.schemas import ListingOut

router = APIRouter(prefix="/listings", tags=["listings"])


@router.get("", response_model=list[ListingOut])
async def list_listings(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=25, ge=1, le=100),
    lat: float | None = Query(default=None),
    lng: float | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
) -> list[Listing]:
    """Returns a page of listings. `lat`/`lng` are accepted for future proximity sorting —
    the client always sends them so the server can layer in geo-ranking without an API change."""
    statement = (
        select(Listing)
        .order_by(Listing.distance_to_campus_meters.asc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    result = await db.scalars(statement)
    return list(result.all())


@router.get("/{listing_id}", response_model=ListingOut)
async def get_listing(listing_id: str, db: AsyncSession = Depends(get_db)) -> Listing:
    listing = await db.get(Listing, listing_id)
    if listing is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")
    return listing
