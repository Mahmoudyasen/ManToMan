#!/usr/bin/env bash
# Start the Kickoff auth API. Creates a venv + installs deps on first run.
set -e
cd "$(dirname "$0")"

if [ ! -d venv ]; then
  python3 -m venv venv
  ./venv/bin/pip install --quiet --upgrade pip
  ./venv/bin/pip install --quiet -r requirements.txt
fi

# DB connection. The password is intentionally NOT stored here — set it in your
# shell before running, e.g.:
#   export MTM_DB_PASSWORD='your-password'
#   ./run.sh
export MTM_DB_SERVER="${MTM_DB_SERVER:-man-to-man.database.windows.net}"
export MTM_DB_NAME="${MTM_DB_NAME:-man-to-man}"
export MTM_DB_USER="${MTM_DB_USER:-adminMTM}"
export MTM_API_PORT="${MTM_API_PORT:-8000}"

if [ -z "${MTM_DB_PASSWORD:-}" ]; then
  echo "ERROR: MTM_DB_PASSWORD is not set. Run: export MTM_DB_PASSWORD='...'" >&2
  exit 1
fi

exec ./venv/bin/python app.py
