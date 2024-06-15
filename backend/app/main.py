from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import Base, engine
from app.routers import auth, bookings, listings


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Convenience for local development; use Alembic migrations in production instead.
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    title="DormFinder API",
    version="1.0.0",
    description="REST API backing the DormFinder iOS app: listings, bookings, and JWT auth.",
    lifespan=lifespan,
)

app.include_router(auth.router, prefix="/v1")
app.include_router(listings.router, prefix="/v1")
app.include_router(bookings.router, prefix="/v1")


@app.get("/health", tags=["health"])
async def health() -> dict[str, str]:
    return {"status": "ok"}
