from datetime import datetime

from pydantic import BaseModel


class ReadingResponse(BaseModel):
    id: str
    meter_id: str
    value: int
    recorded_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}
