from pydantic import BaseModel


class MeterCreate(BaseModel):
    property_id: str
    utility_type: str
    name: str


class MeterResponse(BaseModel):
    id: str
    property_id: str
    utility_type: str
    name: str
    digit_count: int

    model_config = {"from_attributes": True}
