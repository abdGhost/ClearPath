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

