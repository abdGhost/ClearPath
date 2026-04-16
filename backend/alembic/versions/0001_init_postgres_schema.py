"""init postgres schema

Revision ID: 0001_init_postgres_schema
Revises:
Create Date: 2026-04-16
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "0001_init_postgres_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "habit_users",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("device_id", sa.String(length=200), nullable=False),
        sa.Column("display_name", sa.String(length=200), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("onboarding_completed", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("goal_type", sa.String(length=40), nullable=False, server_default="quit"),
        sa.Column("quit_reason", sa.Text(), nullable=False, server_default=""),
        sa.Column("trigger_profile", sa.JSON(), nullable=False),
        sa.Column("trigger_log", sa.JSON(), nullable=False),
        sa.Column("crave_sessions", sa.JSON(), nullable=False),
        sa.Column("milestone_days", sa.Integer(), nullable=False, server_default="30"),
        sa.Column("preferred_currency", sa.String(length=12), nullable=False, server_default="auto"),
        sa.Column("daily_spend", sa.Float(), nullable=False, server_default="12.5"),
        sa.Column("daily_hours", sa.Float(), nullable=False, server_default="1.5"),
        sa.Column("resist_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_relapse_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_mood_logged_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_resist_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("heatmap_week", sa.JSON(), nullable=False),
        sa.UniqueConstraint("device_id", name="uq_habit_users_device_id"),
    )
    op.create_index("ix_habit_users_device_id", "habit_users", ["device_id"], unique=True)

    op.create_table(
        "habit_events",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("device_id", sa.String(length=200), nullable=False),
        sa.Column("event_type", sa.String(length=40), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_habit_events_device_id", "habit_events", ["device_id"], unique=False)
    op.create_index("ix_habit_events_event_type", "habit_events", ["event_type"], unique=False)
    op.create_index("ix_habit_events_created_at", "habit_events", ["created_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_habit_events_created_at", table_name="habit_events")
    op.drop_index("ix_habit_events_event_type", table_name="habit_events")
    op.drop_index("ix_habit_events_device_id", table_name="habit_events")
    op.drop_table("habit_events")

    op.drop_index("ix_habit_users_device_id", table_name="habit_users")
    op.drop_table("habit_users")

