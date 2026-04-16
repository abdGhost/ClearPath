"""Haptive habit state API — mirrors Flutter HabitStore fields."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator

STATE_PATH = Path(__file__).resolve().parent / "habit_state.json"
STATE_LOCK = Lock()
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
STORAGE_MODE = "postgres" if DATABASE_URL else "json"


class HabitState(BaseModel):
    last_relapse_date: datetime
    version: int = 1
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    resist_count: int = 0
    onboarding_completed: bool = False
    goal_type: str = "quit"
    quit_reason: str = ""
    trigger_profile: list[str] = Field(default_factory=list)
    milestone_days: int = 30
    preferred_currency: str = "auto"
    daily_spend: float = 12.5
    daily_hours: float = 1.5
    trigger_log: list[str] = Field(default_factory=list)
    crave_sessions: list[dict[str, Any]] = Field(default_factory=list)
    heatmap_week: list[int] = Field(default_factory=lambda: [0, 0, 0, 0, 0, 0, 0])
    last_mood_logged_at: datetime | None = None
    last_resist_at: datetime | None = None


class DeviceHabitState(HabitState):
    device_id: str
    display_name: str


class HabitDb(BaseModel):
    users: dict[str, DeviceHabitState] = Field(default_factory=dict)


class TriggerBody(BaseModel):
    emotion: str

    @field_validator("emotion")
    @classmethod
    def validate_emotion(cls, value: str) -> str:
        v = value.strip()
        if not v:
            raise ValueError("emotion is required")
        if len(v) > 80:
            raise ValueError("emotion too long")
        return v


class CraveSessionBody(BaseModel):
    mode: str
    helped: bool
    at: datetime | None = None

    @field_validator("mode")
    @classmethod
    def validate_mode(cls, value: str) -> str:
        v = value.strip()
        if not v:
            raise ValueError("mode is required")
        if len(v) > 40:
            raise ValueError("mode too long")
        return v


class RelapseBody(BaseModel):
    at: datetime | None = None


class PreferencesBody(BaseModel):
    onboarding_completed: bool | None = None
    goal_type: str | None = None
    quit_reason: str | None = None
    trigger_profile: list[str] | None = None
    milestone_days: int | None = None
    preferred_currency: str | None = None
    daily_spend: float = 12.5
    daily_hours: float = 1.5


class ModeSummary(BaseModel):
    mode: str
    attempts: int
    helped: int
    help_rate: float


class HabitSummary(BaseModel):
    clean_days: int
    total_resists: int
    total_triggers: int
    total_crave_sessions: int
    total_helped_sessions: int
    help_rate: float
    top_trigger: str | None = None
    best_mode: str | None = None
    mode_stats: list[ModeSummary] = Field(default_factory=list)


class WeeklyActivity(BaseModel):
    monday_first: list[int] = Field(default_factory=lambda: [0, 0, 0, 0, 0, 0, 0])


def _default_state() -> HabitState:
    return HabitState(last_relapse_date=datetime.now(timezone.utc))


def _name_from_device_id(device_id: str) -> str:
    left = ["Steady", "Calm", "Focused", "Bold", "Bright", "Grounded", "Resilient", "Patient", "Clear", "Brave"]
    right = ["Falcon", "River", "Pine", "Summit", "Harbor", "Atlas", "Nova", "Comet", "Oak", "Dawn"]
    h = 0x811C9DC5
    for ch in device_id:
        h ^= ord(ch)
        h = (h * 0x01000193) & 0xFFFFFFFF
    return f"{left[h % len(left)]} {right[(h // len(left)) % len(right)]} #{format(h, '08x')[:4].upper()}"


def _sanitize_milestone_days(value: int) -> int:
    options = {7, 14, 30, 60, 90}
    return value if value in options else 30


def _sanitize_currency(value: str) -> str:
    v = value.strip().upper()
    return v if v in {"INR", "USD"} else "auto"


def load_db() -> HabitDb:
    if not STATE_PATH.is_file():
        db = HabitDb()
        save_db(db)
        return db
    raw = STATE_PATH.read_text(encoding="utf-8")
    try:
        return HabitDb.model_validate_json(raw)
    except Exception:
        return HabitDb()


def save_db(db: HabitDb) -> None:
    with STATE_LOCK:
        tmp = STATE_PATH.with_suffix(".json.tmp")
        tmp.write_text(db.model_dump_json(indent=2), encoding="utf-8")
        tmp.replace(STATE_PATH)


def _legacy_to_device_state(device_id: str, display_name: str) -> DeviceHabitState:
    legacy = _default_state()
    return DeviceHabitState(
        device_id=device_id,
        display_name=display_name,
        last_relapse_date=legacy.last_relapse_date,
        version=legacy.version,
        updated_at=legacy.updated_at,
        resist_count=legacy.resist_count,
        onboarding_completed=legacy.onboarding_completed,
        goal_type=legacy.goal_type,
        quit_reason=legacy.quit_reason,
        trigger_profile=legacy.trigger_profile,
        milestone_days=legacy.milestone_days,
        preferred_currency=legacy.preferred_currency,
        daily_spend=legacy.daily_spend,
        daily_hours=legacy.daily_hours,
        trigger_log=legacy.trigger_log,
        crave_sessions=legacy.crave_sessions,
        heatmap_week=legacy.heatmap_week,
        last_mood_logged_at=legacy.last_mood_logged_at,
        last_resist_at=legacy.last_resist_at,
    )


def _postgres_row_to_state(row: Any) -> DeviceHabitState:
    return DeviceHabitState(
        device_id=row.device_id,
        display_name=row.display_name,
        last_relapse_date=row.last_relapse_date,
        version=row.version,
        updated_at=row.updated_at,
        resist_count=row.resist_count,
        onboarding_completed=row.onboarding_completed,
        goal_type=row.goal_type,
        quit_reason=row.quit_reason,
        trigger_profile=list(row.trigger_profile or []),
        milestone_days=row.milestone_days,
        preferred_currency=row.preferred_currency,
        daily_spend=row.daily_spend,
        daily_hours=row.daily_hours,
        trigger_log=list(row.trigger_log or []),
        crave_sessions=list(row.crave_sessions or []),
        heatmap_week=list(row.heatmap_week or [0, 0, 0, 0, 0, 0, 0]),
        last_mood_logged_at=row.last_mood_logged_at,
        last_resist_at=row.last_resist_at,
    )


def _apply_state_to_postgres_row(row: Any, state: DeviceHabitState) -> None:
    row.device_id = state.device_id
    row.display_name = state.display_name
    row.last_relapse_date = state.last_relapse_date
    row.version = state.version
    row.updated_at = state.updated_at
    row.resist_count = state.resist_count
    row.onboarding_completed = state.onboarding_completed
    row.goal_type = state.goal_type
    row.quit_reason = state.quit_reason
    row.trigger_profile = list(state.trigger_profile)
    row.trigger_log = list(state.trigger_log)
    row.crave_sessions = list(state.crave_sessions)
    row.milestone_days = state.milestone_days
    row.preferred_currency = state.preferred_currency
    row.daily_spend = state.daily_spend
    row.daily_hours = state.daily_hours
    row.heatmap_week = list(state.heatmap_week)
    row.last_mood_logged_at = state.last_mood_logged_at
    row.last_resist_at = state.last_resist_at


def get_or_create_user(device_id: str, display_name: str | None) -> tuple[HabitDb | None, DeviceHabitState]:
    if STORAGE_MODE == "postgres":
        from postgres_storage import HabitUser, create_tables, session_scope

        create_tables()
        with session_scope() as session:
            row = session.query(HabitUser).filter(HabitUser.device_id == device_id).one_or_none()
            if row is not None:
                if display_name and display_name.strip() and row.display_name != display_name.strip():
                    row.display_name = display_name.strip()
                    session.add(row)
                session.flush()
                return None, _postgres_row_to_state(row)

            name = (display_name or "").strip() or _name_from_device_id(device_id)
            legacy = _default_state()
            row = HabitUser(
                device_id=device_id,
                display_name=name,
                last_relapse_date=legacy.last_relapse_date,
                version=legacy.version,
                updated_at=legacy.updated_at,
                resist_count=legacy.resist_count,
                onboarding_completed=legacy.onboarding_completed,
                goal_type=legacy.goal_type,
                quit_reason=legacy.quit_reason,
                trigger_profile=legacy.trigger_profile,
                trigger_log=legacy.trigger_log,
                crave_sessions=legacy.crave_sessions,
                milestone_days=legacy.milestone_days,
                preferred_currency=legacy.preferred_currency,
                daily_spend=legacy.daily_spend,
                daily_hours=legacy.daily_hours,
                heatmap_week=legacy.heatmap_week,
                last_mood_logged_at=legacy.last_mood_logged_at,
                last_resist_at=legacy.last_resist_at,
            )
            session.add(row)
            session.flush()
            return None, _postgres_row_to_state(row)

    db = load_db()
    user = db.users.get(device_id)
    if user is not None:
        if display_name and display_name.strip() and user.display_name != display_name.strip():
            user.display_name = display_name.strip()
            db.users[device_id] = user
            save_db(db)
        return db, user

    name = (display_name or "").strip() or _name_from_device_id(device_id)
    if STATE_PATH.is_file():
        try:
            raw = STATE_PATH.read_text(encoding="utf-8")
            legacy = HabitState.model_validate_json(raw)
            user = DeviceHabitState(
                device_id=device_id,
                display_name=name,
                last_relapse_date=legacy.last_relapse_date,
                version=legacy.version,
                updated_at=legacy.updated_at,
                resist_count=legacy.resist_count,
                onboarding_completed=legacy.onboarding_completed,
                goal_type=legacy.goal_type,
                quit_reason=legacy.quit_reason,
                trigger_profile=legacy.trigger_profile,
                milestone_days=legacy.milestone_days,
                preferred_currency=legacy.preferred_currency,
                daily_spend=legacy.daily_spend,
                daily_hours=legacy.daily_hours,
                trigger_log=legacy.trigger_log,
                crave_sessions=legacy.crave_sessions,
                heatmap_week=legacy.heatmap_week,
                last_mood_logged_at=legacy.last_mood_logged_at,
                last_resist_at=legacy.last_resist_at,
            )
        except Exception:
            user = _legacy_to_device_state(device_id, name)
    else:
        user = _legacy_to_device_state(device_id, name)
    db.users[device_id] = user
    save_db(db)
    return db, user


def persist_user(db: HabitDb | None, device_id: str, state: DeviceHabitState) -> DeviceHabitState:
    state.version = max(1, state.version + 1)
    state.updated_at = datetime.now(timezone.utc)
    if STORAGE_MODE == "postgres":
        from postgres_storage import HabitUser, create_tables, session_scope

        create_tables()
        with session_scope() as session:
            row = session.query(HabitUser).filter(HabitUser.device_id == device_id).one_or_none()
            if row is None:
                row = HabitUser(device_id=device_id, display_name=state.display_name, last_relapse_date=state.last_relapse_date)
            _apply_state_to_postgres_row(row, state)
            session.add(row)
            session.flush()
        return state

    if db is None:
        raise RuntimeError("JSON storage requires HabitDb instance")
    db.users[device_id] = state
    save_db(db)
    return state


def assert_expected_version(state: DeviceHabitState, if_version: int | None) -> None:
    if if_version is None:
        return
    if if_version != state.version:
        raise HTTPException(
            status_code=409,
            detail=f"version mismatch (expected {state.version}, got {if_version})",
        )


def build_summary(s: DeviceHabitState) -> HabitSummary:
    clean_days = max(0, (datetime.now(timezone.utc) - s.last_relapse_date).days)
    trigger_counts: dict[str, int] = {}
    for item in s.trigger_log:
        k = item.strip() or "Unknown"
        trigger_counts[k] = trigger_counts.get(k, 0) + 1
    top_trigger = max(trigger_counts.items(), key=lambda x: x[1])[0] if trigger_counts else None

    mode_buckets: dict[str, tuple[int, int]] = {}
    for entry in s.crave_sessions:
        mode = str(entry.get("mode", "unknown")).strip() or "unknown"
        helped = entry.get("helped") is True
        attempts, helped_n = mode_buckets.get(mode, (0, 0))
        mode_buckets[mode] = (attempts + 1, helped_n + (1 if helped else 0))
    mode_stats = [
        ModeSummary(
            mode=mode,
            attempts=attempts,
            helped=helped_n,
            help_rate=(helped_n / attempts if attempts else 0.0),
        )
        for mode, (attempts, helped_n) in mode_buckets.items()
    ]
    mode_stats.sort(key=lambda m: (m.help_rate, m.attempts), reverse=True)
    total_sessions = len(s.crave_sessions)
    total_helped = sum(1 for e in s.crave_sessions if e.get("helped") is True)
    return HabitSummary(
        clean_days=clean_days,
        total_resists=s.resist_count,
        total_triggers=len(s.trigger_log),
        total_crave_sessions=total_sessions,
        total_helped_sessions=total_helped,
        help_rate=(total_helped / total_sessions if total_sessions else 0.0),
        top_trigger=top_trigger,
        best_mode=(mode_stats[0].mode if mode_stats else None),
        mode_stats=mode_stats,
    )


def build_weekly_activity(s: DeviceHabitState) -> WeeklyActivity:
    # Stored heatmap index: Sun=0 .. Sat=6. Convert to Mon-first.
    resist_monday_first = [0, 0, 0, 0, 0, 0, 0]
    if len(s.heatmap_week) == 7:
        resist_monday_first = [s.heatmap_week[1], s.heatmap_week[2], s.heatmap_week[3], s.heatmap_week[4], s.heatmap_week[5], s.heatmap_week[6], s.heatmap_week[0]]

    crave_monday_first = [0, 0, 0, 0, 0, 0, 0]
    for entry in s.crave_sessions:
        raw = entry.get("at")
        if not isinstance(raw, str):
            continue
        try:
            dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
            i = dt.weekday()  # Mon=0 .. Sun=6
            crave_monday_first[i] += 1
        except Exception:
            continue

    return WeeklyActivity(
        monday_first=[
            resist_monday_first[i] + crave_monday_first[i]
            for i in range(7)
        ]
    )


app = FastAPI(title="Haptive API", version="0.2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "storage": STORAGE_MODE}


@app.get("/habit/state")
def get_state(device_id: str, display_name: str | None = None) -> DeviceHabitState:
    _, user = get_or_create_user(device_id=device_id, display_name=display_name)
    return user


@app.get("/habit/summary")
def get_summary(device_id: str, display_name: str | None = None) -> HabitSummary:
    _, user = get_or_create_user(device_id=device_id, display_name=display_name)
    return build_summary(user)


@app.get("/habit/modes")
def get_modes(device_id: str, display_name: str | None = None) -> list[ModeSummary]:
    _, user = get_or_create_user(device_id=device_id, display_name=display_name)
    return build_summary(user).mode_stats


@app.get("/habit/weekly-activity")
def get_weekly_activity(device_id: str, display_name: str | None = None) -> WeeklyActivity:
    _, user = get_or_create_user(device_id=device_id, display_name=display_name)
    return build_weekly_activity(user)


@app.post("/habit/resist")
def resist(
    device_id: str,
    display_name: str | None = None,
    if_version: int | None = Query(default=None),
) -> DeviceHabitState:
    db, s = get_or_create_user(device_id=device_id, display_name=display_name)
    assert_expected_version(s, if_version)
    now = datetime.now(timezone.utc)
    s.resist_count += 1
    s.last_resist_at = now
    i = now.weekday() % 7
    if len(s.heatmap_week) == 7:
        s.heatmap_week[i] = min(4, s.heatmap_week[i] + 1)
    return persist_user(db, device_id, s)


@app.post("/habit/log-trigger")
def log_trigger(
    body: TriggerBody,
    device_id: str,
    display_name: str | None = None,
    if_version: int | None = Query(default=None),
) -> DeviceHabitState:
    db, s = get_or_create_user(device_id=device_id, display_name=display_name)
    assert_expected_version(s, if_version)
    s.trigger_log.append(body.emotion)
    s.last_mood_logged_at = datetime.now(timezone.utc)
    return persist_user(db, device_id, s)


@app.post("/habit/crave-session")
def crave_session(
    body: CraveSessionBody,
    device_id: str,
    display_name: str | None = None,
    if_version: int | None = Query(default=None),
) -> DeviceHabitState:
    db, s = get_or_create_user(device_id=device_id, display_name=display_name)
    assert_expected_version(s, if_version)
    s.crave_sessions.append(
        {
            "mode": body.mode,
            "helped": body.helped,
            "at": (body.at if body.at else datetime.now(timezone.utc)).isoformat(),
        }
    )
    return persist_user(db, device_id, s)


@app.post("/habit/relapse")
def relapse(
    body: RelapseBody | None = None,
    device_id: str = "",
    display_name: str | None = None,
    if_version: int | None = Query(default=None),
) -> DeviceHabitState:
    if not device_id.strip():
        raise HTTPException(status_code=422, detail="device_id is required")
    db, s = get_or_create_user(device_id=device_id, display_name=display_name)
    assert_expected_version(s, if_version)
    s.last_relapse_date = body.at if body and body.at else datetime.now(timezone.utc)
    return persist_user(db, device_id, s)


@app.post("/habit/preferences")
def update_preferences(
    body: PreferencesBody,
    device_id: str,
    display_name: str | None = None,
    if_version: int | None = Query(default=None),
) -> DeviceHabitState:
    db, s = get_or_create_user(device_id=device_id, display_name=display_name)
    assert_expected_version(s, if_version)
    if body.onboarding_completed is not None:
        s.onboarding_completed = body.onboarding_completed
    if body.goal_type is not None and body.goal_type.strip():
        s.goal_type = body.goal_type.strip()
    if body.quit_reason is not None:
        s.quit_reason = body.quit_reason.strip()
    if body.trigger_profile is not None:
        s.trigger_profile = [item.strip() for item in body.trigger_profile if isinstance(item, str) and item.strip()]
    if body.milestone_days is not None:
        s.milestone_days = _sanitize_milestone_days(body.milestone_days)
    if body.preferred_currency is not None:
        s.preferred_currency = _sanitize_currency(body.preferred_currency)
    s.daily_spend = max(0.0, min(body.daily_spend, 1000000.0))
    s.daily_hours = max(0.0, min(body.daily_hours, 24.0))
    return persist_user(db, device_id, s)
