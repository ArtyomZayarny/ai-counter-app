"""add apple_id to users

Revision ID: 002
Revises: 001
Create Date: 2026-02-19

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("apple_id", sa.String(255), unique=True, nullable=True))


def downgrade() -> None:
    op.drop_column("users", "apple_id")
