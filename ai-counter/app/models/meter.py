import uuid
from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Meter(Base):
    __tablename__ = "meters"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    property_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("properties.id", ondelete="CASCADE"), nullable=False)
    utility_type: Mapped[str] = mapped_column(String(20), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    digit_count: Mapped[int] = mapped_column(Integer, default=5)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("property_id", "utility_type", "name"),
        CheckConstraint("utility_type IN ('gas', 'water', 'electricity')", name="ck_utility_type"),
    )

    property = relationship("Property", back_populates="meters")
    readings = relationship("Reading", back_populates="meter", cascade="all, delete-orphan")
    tariffs = relationship("Tariff", back_populates="meter", cascade="all, delete-orphan")
    bills = relationship("Bill", back_populates="meter", cascade="all, delete-orphan")
