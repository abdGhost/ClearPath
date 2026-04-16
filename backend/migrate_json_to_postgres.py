"""One-time migration utility from JSON state file to Postgres."""

from __future__ import annotations

import os
from datetime import datetime, timezone

from main import load_db
from postgres_storage import HabitUser, create_tables, session_scope


def _migrate() -> tuple[int, int]:
    db = load_db()
    users = db.users
    inserted = 0
    updated = 0

    create_tables()
    with session_scope() as session:
        for device_id, state in users.items():
            row = session.query(HabitUser).filter(HabitUser.device_id == device_id).one_or_none()
            if row is None:
                row = HabitUser(
                    device_id=device_id,
                    display_name=state.display_name,
                    last_relapse_date=state.last_relapse_date,
                )
                session.add(row)
                inserted += 1
            else:
                updated += 1

            row.display_name = state.display_name
            row.version = state.version
            row.updated_at = state.updated_at or datetime.now(timezone.utc)
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
            row.resist_count = state.resist_count
            row.last_relapse_date = state.last_relapse_date
            row.last_mood_logged_at = state.last_mood_logged_at
            row.last_resist_at = state.last_resist_at
            row.heatmap_week = list(state.heatmap_week)

    return inserted, updated


def main() -> None:
    if not os.getenv("DATABASE_URL", "").strip():
        raise SystemExit("DATABASE_URL is required")
    inserted, updated = _migrate()
    print(f"migration complete: inserted={inserted}, updated={updated}")


if __name__ == "__main__":
    main()

