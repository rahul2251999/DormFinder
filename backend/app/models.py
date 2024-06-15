import uuid
from datetime import datetime, date

from sqlalchemy import ForeignKey, Numeric, String, Boolean, Float, DateTime, Date, Integer, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String, nullable=False)
    full_name: Mapped[str] = mapped_column(String, nullable=False)
    university: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    bookings: Mapped[list["Booking"]] = relationship(back_populates="user")


class Listing(Base):
    __tablename__ = "listings"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    title: Mapped[str] = mapped_column(String, nullable=False)
    summary: Mapped[str] = mapped_column(String, nullable=False)
    price_per_month: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    currency_code: Mapped[str] = mapped_column(String, default="USD")
    room_type: Mapped[str] = mapped_column(String, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    address: Mapped[str] = mapped_column(String, nullable=False)
    distance_to_campus_meters: Mapped[float] = mapped_column(Float, nullable=False)
    amenities: Mapped[list] = mapped_column(JSON, default=list)
    photo_urls: Mapped[list] = mapped_column(JSON, default=list)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    available_from: Mapped[date] = mapped_column(Date, nullable=False)
    rating: Mapped[float] = mapped_column(Float, default=0.0)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    bookings: Mapped[list["Booking"]] = relationship(back_populates="listing")


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    listing_id: Mapped[str] = mapped_column(ForeignKey("listings.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    check_in: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    check_out: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    total_price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    currency_code: Mapped[str] = mapped_column(String, default="USD")
    status: Mapped[str] = mapped_column(String, default="pending")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # Bumped on every server-side mutation; the iOS client uses this for
    # last-write-wins conflict resolution when merging cached bookings (see SyncManager.swift).
    version: Mapped[int] = mapped_column(Integer, default=1)

    user: Mapped["User"] = relationship(back_populates="bookings")
    listing: Mapped["Listing"] = relationship(back_populates="bookings")
