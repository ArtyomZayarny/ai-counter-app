import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.dependencies import get_current_user, get_db
from app.models.meter import Meter
from app.models.property import Property
from app.models.user import User
from app.schemas.meter import MeterCreate, MeterResponse

router = APIRouter(prefix="/meters", tags=["meters"])


@router.get("", response_model=list[MeterResponse])
async def list_meters(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Meter)
        .join(Property)
        .where(Property.user_id == user.id)
        .order_by(Meter.created_at)
    )
    meters = result.scalars().all()
    return [
        MeterResponse(
            id=str(m.id),
            property_id=str(m.property_id),
            utility_type=m.utility_type,
            name=m.name,
            digit_count=m.digit_count,
        )
        for m in meters
    ]


@router.post("", response_model=MeterResponse, status_code=status.HTTP_201_CREATED)
async def create_meter(
    body: MeterCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify property belongs to user
    try:
        prop_id = uuid.UUID(body.property_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid property_id")

    result = await db.execute(
        select(Property).where(Property.id == prop_id, Property.user_id == user.id)
    )
    prop = result.scalar_one_or_none()
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    if body.utility_type not in ("gas", "water", "electricity"):
        raise HTTPException(status_code=400, detail="utility_type must be gas, water, or electricity")

    meter = Meter(
        property_id=prop_id,
        utility_type=body.utility_type,
        name=body.name,
    )
    db.add(meter)
    await db.commit()
    await db.refresh(meter)

    return MeterResponse(
        id=str(meter.id),
        property_id=str(meter.property_id),
        utility_type=meter.utility_type,
        name=meter.name,
        digit_count=meter.digit_count,
    )
