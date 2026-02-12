"""initial schema

Revision ID: 001
Revises:
Create Date: 2026-02-12

"""
from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Users
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("email", sa.String(255), unique=True, nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=True),
        sa.Column("google_id", sa.String(255), unique=True, nullable=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
    )

    # Properties
    op.create_table(
        "properties",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("address", sa.String(255), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "name"),
    )

    # Meters
    op.create_table(
        "meters",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("property_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("properties.id", ondelete="CASCADE"), nullable=False),
        sa.Column("utility_type", sa.String(20), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("digit_count", sa.Integer, server_default="5"),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("property_id", "utility_type", "name"),
        sa.CheckConstraint("utility_type IN ('gas', 'water', 'electricity')", name="ck_utility_type"),
    )

    # Readings
    op.create_table(
        "readings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("meter_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("meters.id", ondelete="CASCADE"), nullable=False),
        sa.Column("value", sa.Integer, nullable=False),
        sa.Column("image_url", sa.String(500), nullable=True),
        sa.Column("recorded_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_readings_meter_recorded", "readings", ["meter_id", "recorded_at"])

    # Tariffs
    op.create_table(
        "tariffs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("meter_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("meters.id", ondelete="CASCADE"), nullable=False),
        sa.Column("price_per_unit", sa.Numeric(10, 4), nullable=False),
        sa.Column("currency", sa.String(3), server_default="'EUR'"),
        sa.Column("effective_from", sa.Date, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_tariffs_meter_effective", "tariffs", ["meter_id", "effective_from"])

    # Bills
    op.create_table(
        "bills",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("meter_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("meters.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reading_from_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("readings.id"), nullable=False),
        sa.Column("reading_to_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("readings.id"), nullable=False),
        sa.Column("tariff_used", sa.Numeric(10, 4), nullable=False),
        sa.Column("currency", sa.String(3), server_default="'EUR'"),
        sa.Column("consumed_units", sa.Numeric(10, 2), nullable=False),
        sa.Column("total_cost", sa.Numeric(10, 2), nullable=False),
        sa.Column("period_start", sa.Date, nullable=False),
        sa.Column("period_end", sa.Date, nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_bills_meter_period", "bills", ["meter_id", "period_end"])


def downgrade() -> None:
    op.drop_table("bills")
    op.drop_table("tariffs")
    op.drop_table("readings")
    op.drop_table("meters")
    op.drop_table("properties")
    op.drop_table("users")
