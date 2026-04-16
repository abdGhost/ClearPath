# ClearPath

ClearPath is a habit-breaker app with:
- A Flutter frontend (`haptive_flutter`)
- A FastAPI backend (`backend`)

It supports onboarding, crave-control sessions, streak tracking, analytics, and profile preferences.

## Project Structure

- `haptive_flutter/` - Flutter app (web/mobile/desktop)
- `backend/` - FastAPI server and state storage

## Prerequisites

- Flutter SDK (stable)
- Python 3.10+ (tested with 3.13)

## Run Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Health check:
- `http://127.0.0.1:8000/health`

### Production storage (Postgres scaffold)

Backend now includes initial SQLAlchemy scaffolding in:
- `backend/postgres_storage.py`
- `backend/alembic.ini`
- `backend/alembic/versions/0001_init_postgres_schema.py`

Install DB deps:

```bash
cd backend
pip install -r requirements.txt
```

Set environment variable:

```bash
set DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/clearpath
```

Current API handlers still run on JSON storage for compatibility while migration
work is in progress. `/health` now reports storage mode (`json` or `postgres`).

Run initial DB migration:

```bash
cd backend
set DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/clearpath
alembic -c alembic.ini upgrade head
```

Migrate existing JSON users into Postgres:

```bash
cd backend
set DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/clearpath
python migrate_json_to_postgres.py
```

## Run Flutter App

```bash
cd haptive_flutter
flutter pub get
flutter run -d chrome
```

## Core API Endpoints

- `GET /health`
- `GET /habit/state`
- `GET /habit/summary`
- `GET /habit/modes`
- `GET /habit/weekly-activity`
- `POST /habit/resist`
- `POST /habit/log-trigger`
- `POST /habit/crave-session`
- `POST /habit/relapse`
- `POST /habit/preferences` (supports `if_version`)

All habit endpoints use:
- `device_id` (query param)
- `display_name` (query param, optional)

## Tests

Backend:

```bash
cd backend
python -m pytest test_api.py -q
```

Flutter:

```bash
cd haptive_flutter
flutter test
```

## Deploy on Render

This repo includes a Render blueprint:
- `render.yaml`

### Option A: One-click Blueprint (recommended)

1. Push this repo to GitHub.
2. In Render, choose **New +** -> **Blueprint**.
3. Select this repository.
4. Render will create:
   - `clearpath-api` (web service)
   - `clearpath-db` (Postgres)

The API start command runs migrations first:
- `alembic -c alembic.ini upgrade head`
- then starts `uvicorn` on `$PORT`.

### Option B: Manual service setup

If creating manually, use:
- Root directory: `backend`
- Build command: `pip install -r requirements.txt`
- Start command: `alembic -c alembic.ini upgrade head && uvicorn main:app --host 0.0.0.0 --port $PORT`
- Health check path: `/health`
- Environment variable:
  - `DATABASE_URL` = your Render Postgres connection string
  - `ALLOWED_ORIGINS` = comma-separated allowed frontend origins (recommended in production), e.g.
    - `https://clearpath-1.onrender.com,https://your-frontend-domain.com`

### Post-deploy check

Open:
- `https://<your-render-service>/health`

Expected:
- `{"status":"ok","storage":"postgres"}`

Root endpoint:
- `GET /` returns `{"name":"ClearPath API","status":"ok"}`

## Flutter API base URL

`HabitApi` defaults:
- Debug/profile: `http://127.0.0.1:8000`
- Release: `https://clearpath-1.onrender.com`

Override at build/run time with:

```bash
flutter run --dart-define=API_BASE_URL=https://clearpath-1.onrender.com
```

