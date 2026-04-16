"""Postgres scaffolding for production migration.

This file is intentionally not wired into request handlers yet. It provides:
- SQLAlchemy engine/session bootstrap from DATABASE_URL
- ORM models for users and event log
- A simple helper to create tables for local bootstrapping
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Iterator

from sqlalchemy import JSON, Boolean, DateTime, Float, Integer, String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker


def _database_url() -> str:
    url = os.getenv("DATABASE_URL", "").strip()
    if not url:
        raise RuntimeError("DATABASE_URL is not set")
    return url


class Base(DeclarativeBase):
    pass


class HabitUser(Base):
    __tablename__ = "habit_users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    device_id: Mapped[str] = mapped_column(String(200), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(200))
    version: Mapped[int] = mapped_column(Integer, default=1)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    onboarding_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    goal_type: Mapped[str] = mapped_column(String(40), default="quit")
    quit_reason: Mapped[str] = mapped_column(Text, default="")
    trigger_profile: Mapped[list[str]] = mapped_column(JSON, default=list)
    trigger_log: Mapped[list[str]] = mapped_column(JSON, default=list)
    crave_sessions: Mapped[list[dict]] = mapped_column(JSON, default=list)
    milestone_days: Mapped[int] = mapped_column(Integer, default=30)
    preferred_currency: Mapped[str] = mapped_column(String(12), default="auto")
    daily_spend: Mapped[float] = mapped_column(Float, default=12.5)
    daily_hours: Mapped[float] = mapped_column(Float, default=1.5)

    resist_count: Mapped[int] = mapped_column(Integer, default=0)
    last_relapse_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_mood_logged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_resist_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    heatmap_week: Mapped[list[int]] = mapped_column(JSON, default=lambda: [0, 0, 0, 0, 0, 0, 0])


class HabitEvent(Base):
    __tablename__ = "habit_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    device_id: Mapped[str] = mapped_column(String(200), index=True)
    event_type: Mapped[str] = mapped_column(String(40), index=True)
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True)


_engine = None
_SessionFactory = None


def engine():
    global _engine
    if _engine is None:
        _engine = create_engine(_database_url(), pool_pre_ping=True, future=True)
    return _engine


def session_factory():
    global _SessionFactory
    if _SessionFactory is None:
        _SessionFactory = sessionmaker(bind=engine(), autoflush=False, autocommit=False, future=True)
    return _SessionFactory


@contextmanager
def session_scope() -> Iterator[Session]:
    session = session_factory()()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def create_tables() -> None:
    Base.metadata.create_all(bind=engine())

