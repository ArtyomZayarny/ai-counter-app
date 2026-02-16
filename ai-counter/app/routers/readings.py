import asyncio
import json
import re
import time
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.meter import Meter
from app.models.property import Property
from app.models.reading import Reading
from app.models.user import User
from app.recognizer import recognize_digits
from app.schemas.reading import ReadingResponse
from app.validation import ValidationError, normalize_digits, validate_image

router = APIRouter(tags=["readings"])

TIMEOUT_SECONDS = 10


def _parse_response(raw_text: str, digit_count: int = 5) -> str:
    """Extract digits from GPT-4o response (JSON or chain-of-thought)."""
    match = re.search(r'\{[^}]+\}', raw_text)
    if match:
        try:
            data = json.loads(match.group())
            values = [data.get(f"pos{i}") for i in range(1, digit_count + 1)]
            if all(v is not None and isinstance(v, int) and 0 <= v <= 9 for v in values):
                return "".join(str(v) for v in values)
        except (json.JSONDecodeError, TypeError):
            pass
    return normalize_digits(raw_text)


async def _verify_meter_ownership(meter_id: str, user: User, db: AsyncSession) -> Meter:
    """Verify meter belongs to user and return it."""
    try:
        mid = uuid.UUID(meter_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid meter_id")

    result = await db.execute(
        select(Meter).join(Property).where(Meter.id == mid, Property.user_id == user.id)
    )
    meter = result.scalar_one_or_none()
    if not meter:
        raise HTTPException(status_code=404, detail="Meter not found")
    return meter


@router.post("/recognize")
async def recognize(
    image: UploadFile = File(...),
    meter_id: str = Form(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify meter belongs to user
    meter = await _verify_meter_ownership(meter_id, user, db)

    # 1. Validate input
    try:
        image_data = await validate_image(image)
    except ValidationError as e:
        return JSONResponse(status_code=400, content={"error": e.detail})

    # 2. Start timer
    start = time.monotonic()

    # 3. Call GPT-4o Vision API with timeout
    try:
        raw_text = await asyncio.wait_for(
            asyncio.to_thread(recognize_digits, image_data, image.content_type, meter.utility_type),
            timeout=TIMEOUT_SECONDS - (time.monotonic() - start),
        )
    except asyncio.TimeoutError:
        return JSONResponse(status_code=408, content={"error": "Processing exceeded 10 seconds"})
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})

    # 4. Parse structured JSON response, fallback to plain-text normalization
    expected = meter.digit_count or 5
    digits = _parse_response(raw_text, expected)

    if len(digits) < expected:
        return JSONResponse(
            status_code=422,
            content={"error": f"Expected at least {expected} digits, got {len(digits)}", "result": digits},
        )
    digits = digits[:expected]

    # 5. Auto-save reading
    reading = Reading(
        meter_id=meter.id,
        value=int(digits),
        recorded_at=datetime.now(timezone.utc),
    )
    db.add(reading)
    await db.commit()
    await db.refresh(reading)

    return {"result": digits, "reading_id": str(reading.id)}


@router.post("/readings", response_model=ReadingResponse, status_code=status.HTTP_201_CREATED)
async def create_reading(
    meter_id: str = Form(...),
    value: int = Form(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meter = await _verify_meter_ownership(meter_id, user, db)
    expected = meter.digit_count or 5
    max_value = 10 ** expected - 1

    if value < 0 or value > max_value:
        raise HTTPException(
            status_code=400,
            detail=f"Value must be between 0 and {max_value}",
        )

    reading = Reading(
        meter_id=meter.id,
        value=value,
        recorded_at=datetime.now(timezone.utc),
    )
    db.add(reading)
    await db.commit()
    await db.refresh(reading)

    return ReadingResponse(
        id=str(reading.id),
        meter_id=str(reading.meter_id),
        value=reading.value,
        recorded_at=reading.recorded_at,
        created_at=reading.created_at,
    )


@router.get("/readings", response_model=list[ReadingResponse])
async def list_readings(
    meter_id: str,
    limit: int = 50,
    offset: int = 0,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meter = await _verify_meter_ownership(meter_id, user, db)

    result = await db.execute(
        select(Reading)
        .where(Reading.meter_id == meter.id)
        .order_by(Reading.recorded_at.desc())
        .limit(limit)
        .offset(offset)
    )
    readings = result.scalars().all()
    return [
        ReadingResponse(
            id=str(r.id),
            meter_id=str(r.meter_id),
            value=r.value,
            recorded_at=r.recorded_at,
            created_at=r.created_at,
        )
        for r in readings
    ]


@router.get("/readings/{reading_id}", response_model=ReadingResponse)
async def get_reading(
    reading_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        rid = uuid.UUID(reading_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid reading_id")

    result = await db.execute(
        select(Reading)
        .join(Meter)
        .join(Property)
        .where(Reading.id == rid, Property.user_id == user.id)
    )
    reading = result.scalar_one_or_none()
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")

    return ReadingResponse(
        id=str(reading.id),
        meter_id=str(reading.meter_id),
        value=reading.value,
        recorded_at=reading.recorded_at,
        created_at=reading.created_at,
    )


@router.delete("/readings/{reading_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_reading(
    reading_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        rid = uuid.UUID(reading_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid reading_id")

    result = await db.execute(
        select(Reading)
        .join(Meter)
        .join(Property)
        .where(Reading.id == rid, Property.user_id == user.id)
    )
    reading = result.scalar_one_or_none()
    if not reading:
        raise HTTPException(status_code=404, detail="Reading not found")

    await db.delete(reading)
    await db.commit()
