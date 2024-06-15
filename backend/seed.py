"""Populates the database with sample listings for local/end-to-end testing.

Usage:
    python seed.py
"""
import asyncio
from datetime import date

from sqlalchemy import select

from app.database import Base, async_session_factory, engine
from app.models import Listing

SAMPLE_LISTINGS = [
    dict(
        title="Sunny Studio Near Campus",
        summary="A bright studio five minutes from the quad, fully furnished with everything you need.",
        price_per_month=950,
        currency_code="USD",
        room_type="studio",
        latitude=37.8719,
        longitude=-122.2585,
        address="123 University Ave, Berkeley, CA",
        distance_to_campus_meters=450,
        amenities=[
            {"id": "wifi", "name": "WiFi", "symbolName": "wifi"},
            {"id": "furnished", "name": "Furnished", "symbolName": "sofa.fill"},
        ],
        photo_urls=["https://images.example.com/listings/studio-1/1.jpg"],
        is_available=True,
        available_from=date(2026, 7, 1),
        rating=4.6,
    ),
    dict(
        title="Spacious Shared Apartment",
        summary="Three-bedroom apartment a short bus ride from campus, great for groups.",
        price_per_month=700,
        currency_code="USD",
        room_type="shared",
        latitude=37.8651,
        longitude=-122.2601,
        address="456 College St, Berkeley, CA",
        distance_to_campus_meters=1800,
        amenities=[
            {"id": "laundry", "name": "Laundry", "symbolName": "washer"},
            {"id": "parking", "name": "Parking", "symbolName": "car.fill"},
        ],
        photo_urls=["https://images.example.com/listings/apt-2/1.jpg"],
        is_available=True,
        available_from=date(2026, 8, 1),
        rating=4.2,
    ),
    dict(
        title="Modern Private Room with Ensuite",
        summary="Private room with its own bathroom in a newly renovated complex.",
        price_per_month=1200,
        currency_code="USD",
        room_type="private",
        latitude=37.8755,
        longitude=-122.2530,
        address="789 Telegraph Ave, Berkeley, CA",
        distance_to_campus_meters=900,
        amenities=[
            {"id": "gym", "name": "Gym", "symbolName": "dumbbell.fill"},
            {"id": "security", "name": "Security", "symbolName": "lock.shield.fill"},
            {"id": "study_room", "name": "Study Room", "symbolName": "books.vertical.fill"},
        ],
        photo_urls=["https://images.example.com/listings/room-3/1.jpg"],
        is_available=False,
        available_from=date(2026, 9, 1),
        rating=4.9,
    ),
]


async def seed() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session_factory() as session:
        existing = await session.scalar(select(Listing).limit(1))
        if existing is not None:
            print("Listings already exist — skipping seed.")
            return

        for data in SAMPLE_LISTINGS:
            session.add(Listing(**data))
        await session.commit()
        print(f"Seeded {len(SAMPLE_LISTINGS)} listings.")


if __name__ == "__main__":
    asyncio.run(seed())
