from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration, loaded from environment variables / a `.env` file.

    Mirrors the values the iOS client expects: the JWT secret and lifetime here
    must match what `AuthService` (Swift) assumes when decoding `expires_in`.
    """

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str = "postgresql+asyncpg://dormfinder:dormfinder@localhost:5432/dormfinder"
    jwt_secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expires_minutes: int = 60
    refresh_token_expires_days: int = 30


@lru_cache
def get_settings() -> Settings:
    return Settings()
