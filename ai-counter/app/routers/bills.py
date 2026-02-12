import uuid
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import get_current_user, get_db
from app.models.bill import Bill
from app.models.meter import Meter
from app.models.property import Property
from app.models.reading import Reading
from app.models.user import User
from app.schemas.bill import BillCreate, BillResponse
from app.services.billing import calculate_cost

router = APIRouter(prefix="/bills", tags=["bills"])


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


@router.get("", response_model=list[BillResponse])
async def list_bills(
    meter_id: str,
    limit: int = 50,
    offset: int = 0,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meter = await _verify_meter_ownership(meter_id, user, db)

    result = await db.execute(
        select(Bill)
        .where(Bill.meter_id == meter.id)
        .order_by(Bill.period_end.desc())
        .limit(limit)
        .offset(offset)
    )
    bills = result.scalars().all()
    return [
        BillResponse(
            id=str(b.id),
            meter_id=str(b.meter_id),
            reading_from_id=str(b.reading_from_id),
            reading_to_id=str(b.reading_to_id),
            tariff_used=float(b.tariff_used),
            currency=b.currency,
            consumed_units=float(b.consumed_units),
            total_cost=float(b.total_cost),
            period_start=b.period_start,
            period_end=b.period_end,
        )
        for b in bills
    ]


@router.post("", response_model=BillResponse, status_code=status.HTTP_201_CREATED)
async def create_bill(
    body: BillCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meter = await _verify_meter_ownership(body.meter_id, user, db)

    # Fetch both readings
    try:
        from_id = uuid.UUID(body.reading_from_id)
        to_id = uuid.UUID(body.reading_to_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid reading ID")

    result = await db.execute(
        select(Reading).where(Reading.id == from_id, Reading.meter_id == meter.id)
    )
    reading_from = result.scalar_one_or_none()
    if not reading_from:
        raise HTTPException(status_code=404, detail="From-reading not found")

    result = await db.execute(
        select(Reading).where(Reading.id == to_id, Reading.meter_id == meter.id)
    )
    reading_to = result.scalar_one_or_none()
    if not reading_to:
        raise HTTPException(status_code=404, detail="To-reading not found")

    consumed = Decimal(str(reading_to.value - reading_from.value))
    if consumed < 0:
        raise HTTPException(status_code=400, detail="To-reading must be greater than from-reading")

    tariff = Decimal(str(body.tariff_per_unit))
    total = calculate_cost(consumed, tariff)

    bill = Bill(
        meter_id=meter.id,
        reading_from_id=from_id,
        reading_to_id=to_id,
        tariff_used=tariff,
        consumed_units=consumed,
        total_cost=total,
        period_start=reading_from.recorded_at.date(),
        period_end=reading_to.recorded_at.date(),
    )
    db.add(bill)
    await db.commit()
    await db.refresh(bill)

    return BillResponse(
        id=str(bill.id),
        meter_id=str(bill.meter_id),
        reading_from_id=str(bill.reading_from_id),
        reading_to_id=str(bill.reading_to_id),
        tariff_used=float(bill.tariff_used),
        currency=bill.currency,
        consumed_units=float(bill.consumed_units),
        total_cost=float(bill.total_cost),
        period_start=bill.period_start,
        period_end=bill.period_end,
    )


@router.delete("/{bill_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_bill(
    bill_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        bid = uuid.UUID(bill_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid bill_id")

    result = await db.execute(
        select(Bill)
        .join(Meter)
        .join(Property)
        .where(Bill.id == bid, Property.user_id == user.id)
    )
    bill = result.scalar_one_or_none()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    await db.delete(bill)
    await db.commit()
