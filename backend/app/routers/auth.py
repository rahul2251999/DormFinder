from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.models import User
from app.schemas import AuthOut, LoginIn, RefreshIn, SignupIn, UserOut
from app.security import create_access_token, create_refresh_token, decode_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


def _auth_response(user: User) -> AuthOut:
    return AuthOut(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        expires_in=settings.access_token_expires_minutes * 60,
        user=UserOut.model_validate(user),
    )


@router.post("/signup", response_model=AuthOut, status_code=status.HTTP_201_CREATED)
async def signup(payload: SignupIn, db: AsyncSession = Depends(get_db)) -> AuthOut:
    existing = await db.scalar(select(User).where(User.email == payload.email))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account with this email already exists")

    user = User(
        email=payload.email,
        hashed_password=hash_password(payload.password),
        full_name=payload.full_name,
        university=payload.university,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return _auth_response(user)


@router.post("/login", response_model=AuthOut)
async def login(payload: LoginIn, db: AsyncSession = Depends(get_db)) -> AuthOut:
    user = await db.scalar(select(User).where(User.email == payload.email))
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    return _auth_response(user)


@router.post("/refresh", response_model=AuthOut)
async def refresh(payload: RefreshIn, db: AsyncSession = Depends(get_db)) -> AuthOut:
    user_id = decode_token(payload.refresh_token, expected_type="refresh")
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return _auth_response(user)
