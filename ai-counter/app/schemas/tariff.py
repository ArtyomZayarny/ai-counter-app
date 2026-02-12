from datetime import date

from pydantic import BaseModel


class TariffCreate(BaseModel):
    meter_id: str
    price_per_unit: float
    effective_from: date
    currency: str = "EUR"


class TariffUpdate(BaseModel):
    price_per_unit: float | None = None
    effective_from: date | None = None


class TariffResponse(BaseModel):
    id: str
    meter_id: str
    price_per_unit: float
    currency: str
    effective_from: date

    model_config = {"from_attributes": True}
