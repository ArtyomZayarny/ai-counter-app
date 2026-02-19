import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db

limiter = Limiter(key_func=get_remote_address)
from app.models.meter import Meter
from app.models.property import Property
from app.models.user import User
from app.schemas.auth import AppleAuthRequest, AuthResponse, GoogleAuthRequest, LoginRequest, RegisterRequest, UserResponse
from app.services.auth import create_access_token, hash_password, verify_apple_token, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


async def _create_default_property_and_meter(db: AsyncSession, user_id: uuid.UUID) -> None:
    """Create a default property and gas meter for a new user."""
    prop = Property(user_id=user_id, name="My Home")
    db.add(prop)
    await db.flush()

    gas_meter = Meter(property_id=prop.id, utility_type="gas", name="Gas Meter")
    db.add(gas_meter)

    electricity_meter = Meter(property_id=prop.id, utility_type="electricity", name="Electricity Meter", digit_count=6)
    db.add(electricity_meter)

    water_meter = Meter(property_id=prop.id, utility_type="water", name="Water Meter")
    db.add(water_meter)


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def register(request: Request, body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check if email already exists
    result = await db.execute(select(User).where(User.email == body.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        email=body.email,
        password_hash=hash_password(body.password),
        name=body.name,
    )
    db.add(user)
    await db.flush()

    await _create_default_property_and_meter(db, user.id)
    await db.commit()
    await db.refresh(user)

    token = create_access_token(str(user.id))
    return AuthResponse(
        access_token=token,
        user=UserResponse(id=str(user.id), email=user.email, name=user.name),
    )


@router.post("/login", response_model=AuthResponse)
@limiter.limit("10/minute")
async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()

    if not user or not user.password_hash or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    token = create_access_token(str(user.id))
    return AuthResponse(
        access_token=token,
        user=UserResponse(id=str(user.id), email=user.email, name=user.name),
    )


@router.post("/google", response_model=AuthResponse)
@limiter.limit("10/minute")
async def google_auth(request: Request, body: GoogleAuthRequest, db: AsyncSession = Depends(get_db)):
    # Verify Google ID token
    from google.auth.transport.requests import Request
    from google.oauth2 import id_token

    from app.config import GOOGLE_CLIENT_ID

    try:
        idinfo = id_token.verify_oauth2_token(body.google_id_token, Request(), GOOGLE_CLIENT_ID)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google token")

    google_id = idinfo["sub"]
    email = idinfo.get("email", "")
    name = idinfo.get("name", email.split("@")[0])

    # Check if user exists by google_id
    result = await db.execute(select(User).where(User.google_id == google_id))
    user = result.scalar_one_or_none()

    if not user:
        # Check if email exists (link accounts)
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user:
            user.google_id = google_id
        else:
            user = User(email=email, google_id=google_id, name=name)
            db.add(user)
            await db.flush()
            await _create_default_property_and_meter(db, user.id)

        await db.commit()
        await db.refresh(user)

    token = create_access_token(str(user.id))
    return AuthResponse(
        access_token=token,
        user=UserResponse(id=str(user.id), email=user.email, name=user.name),
    )


@router.post("/apple", response_model=AuthResponse)
@limiter.limit("10/minute")
async def apple_auth(request: Request, body: AppleAuthRequest, db: AsyncSession = Depends(get_db)):
    from app.config import APPLE_BUNDLE_ID

    payload = await verify_apple_token(body.identity_token, APPLE_BUNDLE_ID)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Apple token")

    apple_id = payload["sub"]
    email = payload.get("email", "")
    name = body.name or (email.split("@")[0] if email else "User")

    # Check if user exists by apple_id
    result = await db.execute(select(User).where(User.apple_id == apple_id))
    user = result.scalar_one_or_none()

    if not user:
        # Check if email exists (link accounts)
        if email:
            result = await db.execute(select(User).where(User.email == email))
            user = result.scalar_one_or_none()
        if user:
            user.apple_id = apple_id
        else:
            user = User(email=email or f"{apple_id}@apple.private", apple_id=apple_id, name=name)
            db.add(user)
            await db.flush()
            await _create_default_property_and_meter(db, user.id)

        await db.commit()
        await db.refresh(user)

    token = create_access_token(str(user.id))
    return AuthResponse(
        access_token=token,
        user=UserResponse(id=str(user.id), email=user.email, name=user.name),
    )


@router.delete("/account", status_code=status.HTTP_200_OK)
@limiter.limit("3/minute")
async def delete_account(
    request: Request,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.delete(user)
    await db.commit()
    return {"detail": "Account deleted"}
