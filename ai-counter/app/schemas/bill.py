from datetime import date

from pydantic import BaseModel, Field


class BillCreate(BaseModel):
    meter_id: str
    reading_from_id: str
    reading_to_id: str
    tariff_per_unit: float = Field(gt=0)


class BillResponse(BaseModel):
    id: str
    meter_id: str
    reading_from_id: str
    reading_to_id: str
    tariff_used: float
    currency: str
    consumed_units: float
    total_cost: float
    period_start: date
    period_end: date

    model_config = {"from_attributes": True}
