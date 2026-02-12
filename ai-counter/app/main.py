from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine
from app.routers import auth, bills, meters, readings, tariffs


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(title="AI Counter", version="2.0", lifespan=lifespan)

# CORS — allow all origins for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(readings.router)
app.include_router(meters.router)
app.include_router(tariffs.router)
app.include_router(bills.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
