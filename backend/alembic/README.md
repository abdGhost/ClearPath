# Alembic migrations

This folder contains migration scaffolding for Postgres.

## Already included

- `alembic/env.py`
- `alembic/script.py.mako`
- `alembic/versions/0001_init_postgres_schema.py`
- root config file: `backend/alembic.ini`

## Run migrations

```bash
cd backend
set DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/clearpath
alembic -c alembic.ini upgrade head
```

## JSON -> Postgres migration

After running migrations, move existing JSON users:

```bash
cd backend
set DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/clearpath
python migrate_json_to_postgres.py
```

