from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import get_settings

settings = get_settings()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def _create_token(subject: str, expires_delta: timedelta, token_type: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {"sub": subject, "type": token_type, "iat": now, "exp": now + expires_delta}
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: str) -> str:
    return _create_token(user_id, timedelta(minutes=settings.access_token_expires_minutes), "access")


def create_refresh_token(user_id: str) -> str:
    return _create_token(user_id, timedelta(days=settings.refresh_token_expires_days), "refresh")


def decode_token(token: str, expected_type: str) -> str | None:
    """Returns the subject (user id) if `token` is valid and of `expected_type`, else `None`."""
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None

    if payload.get("type") != expected_type:
        return None
    return payload.get("sub")
