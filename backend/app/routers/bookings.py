from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user
from app.models import Booking, Listing, User
from app.schemas import BookingIn, BookingOut

router = APIRouter(prefix="/bookings", tags=["bookings"])


def _to_out(booking: Booking, listing_title: str) -> BookingOut:
    """`Booking` doesn't carry the listing title as a column (it's joined from `Listing`),
    so we build the response explicitly rather than relying on `from_attributes`."""
    return BookingOut(
        id=booking.id,
        listing_id=booking.listing_id,
        listing_title=listing_title,
        user_id=booking.user_id,
        check_in=booking.check_in,
        check_out=booking.check_out,
        total_price=booking.total_price,
        currency_code=booking.currency_code,
        status=booking.status,
        created_at=booking.created_at,
        updated_at=booking.updated_at,
        version=booking.version,
    )


@router.get("", response_model=list[BookingOut])
async def list_bookings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[BookingOut]:
    statement = (
        select(Booking, Listing.title)
        .join(Listing, Listing.id == Booking.listing_id)
        .where(Booking.user_id == current_user.id)
        .order_by(Booking.check_in.desc())
    )
    rows = (await db.execute(statement)).all()
    return [_to_out(booking, title) for booking, title in rows]


@router.post("", response_model=BookingOut, status_code=status.HTTP_201_CREATED)
async def create_booking(
    payload: BookingIn,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> BookingOut:
    if payload.check_out <= payload.check_in:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="check_out must be after check_in")

    listing = await db.get(Listing, payload.listing_id)
    if listing is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")
    if not listing.is_available:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Listing is not currently available")

    nights = (payload.check_out - payload.check_in).days
    total_price = (Decimal(listing.price_per_month) / Decimal(30)) * Decimal(max(nights, 1))
    total_price = total_price.quantize(Decimal("0.01"))

    booking = Booking(
        listing_id=listing.id,
        user_id=current_user.id,
        check_in=payload.check_in,
        check_out=payload.check_out,
        total_price=total_price,
        currency_code=listing.currency_code,
        status="pending",
        version=1,
    )
    db.add(booking)
    await db.commit()
    await db.refresh(booking)

    return _to_out(booking, listing.title)


@router.delete("/{booking_id}", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_booking(
    booking_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    booking = await db.get(Booking, booking_id)
    if booking is None or booking.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    if booking.status != "cancelled":
        booking.status = "cancelled"
        booking.version += 1
        booking.updated_at = datetime.now(timezone.utc)
        await db.commit()
