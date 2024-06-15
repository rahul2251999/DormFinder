from datetime import datetime, date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

# NOTE: field names use snake_case and are serialized as-is — the iOS `NetworkService`
# decodes/encodes using matching `CodingKeys`, so keep these two layers in sync.


class AmenitySchema(BaseModel):
    id: str
    name: str
    symbolName: str = Field(serialization_alias="symbolName", validation_alias="symbolName")

    model_config = ConfigDict(populate_by_name=True)


class ListingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    summary: str
    price_per_month: Decimal
    currency_code: str
    room_type: str
    latitude: float
    longitude: float
    address: str
    distance_to_campus_meters: float
    amenities: list[dict]
    photo_urls: list[str]
    is_available: bool
    available_from: date
    rating: float
    updated_at: datetime


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    full_name: str
    university: str | None = None


class SignupIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    full_name: str
    university: str | None = None


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class AuthOut(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    user: UserOut


class BookingIn(BaseModel):
    listing_id: str
    check_in: datetime
    check_out: datetime


class BookingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    listing_id: str
    listing_title: str
    user_id: str
    check_in: datetime
    check_out: datetime
    total_price: Decimal
    currency_code: str
    status: str
    created_at: datetime
    updated_at: datetime
    version: int
