import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.meter import Meter
from app.models.property import Property
from app.models.tariff import Tariff
from app.models.user import User
from app.schemas.tariff import TariffCreate, TariffResponse, TariffUpdate

router = APIRouter(prefix="/tariffs", tags=["tariffs"])


async def _verify_meter_ownership(meter_id: str, user: User, db: AsyncSession) -> Meter:
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


@router.get("", response_model=list[TariffResponse])
async def list_tariffs(
    meter_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meter = await _verify_meter_ownership(meter_id, user, db)

    result = await db.execute(
        select(Tariff)
        .where(Tariff.meter_id == meter.id)
        .order_by(Tariff.effective_from.desc())
    )
    tariffs = result.scalars().all()
    return [
        TariffResponse(
            id=str(t.id),
            meter_id=str(t.meter_id),
            price_per_unit=float(t.price_per_unit),
            currency=t.currency,
            effective_from=t.effective_from,
        )
        for t in tariffs
    ]


@router.post("", response_model=TariffResponse, status_code=status.HTTP_201_CREATED)
async def create_tariff(
    body: TariffCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meter = await _verify_meter_ownership(body.meter_id, user, db)

    tariff = Tariff(
        meter_id=meter.id,
        price_per_unit=body.price_per_unit,
        currency=body.currency,
        effective_from=body.effective_from,
    )
    db.add(tariff)
    await db.commit()
    await db.refresh(tariff)

    return TariffResponse(
        id=str(tariff.id),
        meter_id=str(tariff.meter_id),
        price_per_unit=float(tariff.price_per_unit),
        currency=tariff.currency,
        effective_from=tariff.effective_from,
    )


@router.put("/{tariff_id}", response_model=TariffResponse)
async def update_tariff(
    tariff_id: str,
    body: TariffUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        tid = uuid.UUID(tariff_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid tariff_id")

    result = await db.execute(
        select(Tariff)
        .join(Meter)
        .join(Property)
        .where(Tariff.id == tid, Property.user_id == user.id)
    )
    tariff = result.scalar_one_or_none()
    if not tariff:
        raise HTTPException(status_code=404, detail="Tariff not found")

    if body.price_per_unit is not None:
        tariff.price_per_unit = body.price_per_unit
    if body.effective_from is not None:
        tariff.effective_from = body.effective_from

    await db.commit()
    await db.refresh(tariff)

    return TariffResponse(
        id=str(tariff.id),
        meter_id=str(tariff.meter_id),
        price_per_unit=float(tariff.price_per_unit),
        currency=tariff.currency,
        effective_from=tariff.effective_from,
    )
