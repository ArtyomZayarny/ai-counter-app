from datetime import date

from pydantic import BaseModel, Field


class TariffCreate(BaseModel):
    meter_id: str
    price_per_unit: float = Field(gt=0)
    effective_from: date
    currency: str = "EUR"


class TariffUpdate(BaseModel):
    price_per_unit: float | None = Field(None, gt=0)
    effective_from: date | None = None


class TariffResponse(BaseModel):
    id: str
    meter_id: str
    price_per_unit: float
    currency: str
    effective_from: date

    model_config = {"from_attributes": True}
