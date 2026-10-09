#!/bin/sh
# (Re)create the local smartmeter database with synthetic data, then build the forecasts cache.
# Run from the repo root: sh db/setup.sh
set -e
export PATH="/usr/local/opt/postgresql@17/bin:$PATH"
DB=${SMARTMETER_DB:-smartmeter}

createdb "$DB" 2>/dev/null || true
# Production runs in UTC; some pages break if date_trunc returns mixed BST/GMT offsets
psql -q -d "$DB" -c "ALTER DATABASE \"$DB\" SET timezone TO 'UTC'"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f db/schema.sql -f db/seed.sql
uv run python -m db.make_forecast_cache
