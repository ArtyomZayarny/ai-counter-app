import uuid
from datetime import date, datetime, timezone

from sqlalchemy import Date, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Tariff(Base):
    __tablename__ = "tariffs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    meter_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("meters.id", ondelete="CASCADE"), nullable=False, index=True)
    price_per_unit: Mapped[float] = mapped_column(Numeric(10, 4), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="EUR")
    effective_from: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc), server_default=func.now())

    meter = relationship("Meter", back_populates="tariffs")
