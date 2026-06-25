#!/usr/bin/env python3
"""
Kickoff auth backend — a tiny HTTP API in front of the Azure SQL `users` table.

Why this exists: Flutter has no working pure-Dart SQL Server driver, and shipping
the DB admin password inside the app would be insecure. So the app calls this
small service over HTTP, and only this service holds the DB credentials.

Endpoints
  GET  /health              -> {"ok": true}
  POST /auth/login          {identifier, password}
  POST /auth/register       {firstName,lastName,email,phone,dob,clubTeam,nationalTeam,password}

Run:
  python3 -m venv venv && source venv/bin/activate
  pip install -r requirements.txt
  ./run.sh                 # or: python3 app.py

Config comes from environment variables (see run.sh) and falls back to the
project's known values so it works out of the box. For anything real, move the
password into a secret store and hash passwords (see SECURITY note at bottom).
"""
import json
import os
from datetime import date, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import certifi
import pytds

DB = dict(
    server=os.environ.get("MTM_DB_SERVER", "man-to-man.database.windows.net"),
    database=os.environ.get("MTM_DB_NAME", "man-to-man"),
    user=os.environ.get("MTM_DB_USER", "adminMTM"),
    password=os.environ.get("MTM_DB_PASSWORD", ""),
    port=int(os.environ.get("MTM_DB_PORT", "1433")),
)
HOST = os.environ.get("MTM_API_HOST", "0.0.0.0")
PORT = int(os.environ.get("MTM_API_PORT", "8000"))


def connect():
    return pytds.connect(
        server=DB["server"], database=DB["database"], user=DB["user"],
        password=DB["password"], port=DB["port"],
        login_timeout=30, timeout=30,
        cafile=certifi.where(), validate_host=False, autocommit=True,
    )


def row_to_user(r):
    """Map a users row to the JSON shape the Flutter AppUser expects.
    Password is intentionally NOT returned to the client."""
    (uid, first, last, email, phone, dob, username, club, national, is_admin) = r
    return {
        "id": uid,
        "username": username or email,
        "firstName": first or "",
        "lastName": last or "",
        "email": email or "",
        "phone": phone or "",
        "dob": dob.isoformat() if isinstance(dob, (date, datetime)) else None,
        "clubTeam": club or "",
        "nationalTeam": national or "",
        "isAdmin": bool(is_admin),
    }


SELECT_COLS = ("id, first_name, last_name, email, phone, date_of_birth, "
               "username, club_team, national_team, is_admin")


def find_user(cur, identifier, password):
    cur.execute(
        f"SELECT {SELECT_COLS} FROM dbo.users "
        "WHERE (LOWER(username) = LOWER(%s) OR LOWER(email) = LOWER(%s)) "
        "AND password = %s",
        (identifier, identifier, password),
    )
    return cur.fetchone()


def parse_dob(raw):
    if not raw:
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "")).date()
    except ValueError:
        try:
            return datetime.strptime(raw[:10], "%Y-%m-%d").date()
        except ValueError:
            return None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        # CORS preflight (Flutter web). Return 200 with an empty body.
        self._send(200, {"ok": True})

    def do_GET(self):
        if self.path == "/health":
            return self._send(200, {"ok": True})
        self._send(404, {"error": "not found"})

    def _body(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw or b"{}")

    def do_POST(self):
        try:
            data = self._body()
        except json.JSONDecodeError:
            return self._send(400, {"error": "invalid JSON"})

        if self.path == "/auth/login":
            return self.login(data)
        if self.path == "/auth/register":
            return self.register(data)
        self._send(404, {"error": "not found"})

    def login(self, data):
        identifier = (data.get("identifier") or "").strip()
        password = data.get("password") or ""
        if not identifier or not password:
            return self._send(400, {"error": "Missing credentials."})
        try:
            with connect() as conn:
                cur = conn.cursor()
                row = find_user(cur, identifier, password)
        except Exception as e:  # noqa: BLE001
            return self._send(503, {"error": f"Database unavailable: {e}"})
        if not row:
            return self._send(401, {"error": "Wrong email/username or password."})
        self._send(200, {"user": row_to_user(row)})

    def register(self, data):
        first = (data.get("firstName") or "").strip()
        last = (data.get("lastName") or "").strip()
        email = (data.get("email") or "").strip()
        phone = (data.get("phone") or "").strip()
        club = (data.get("clubTeam") or "").strip()
        national = (data.get("nationalTeam") or "").strip()
        password = data.get("password") or ""
        dob = parse_dob(data.get("dob"))

        if not first or not last:
            return self._send(400, {"error": "Please enter your first and last name."})
        if "@" not in email:
            return self._send(400, {"error": "Please enter a valid email address."})
        if not phone:
            return self._send(400, {"error": "Please enter your phone number."})
        if dob is None:
            return self._send(400, {"error": "Please pick your date of birth."})
        if not club:
            return self._send(400, {"error": "Please choose the club you support."})
        if not national:
            return self._send(400, {"error": "Please choose the national team you support."})
        if len(password) < 3:
            return self._send(400, {"error": "Password must be at least 3 characters."})

        try:
            with connect() as conn:
                cur = conn.cursor()
                # Members log in with their email; that's also their username.
                cur.execute(
                    "SELECT 1 FROM dbo.users WHERE LOWER(email) = LOWER(%s) "
                    "OR LOWER(username) = LOWER(%s)",
                    (email, email),
                )
                if cur.fetchone():
                    return self._send(409, {"error": "An account with that email already exists."})
                cur.execute(
                    "INSERT INTO dbo.users "
                    "(first_name,last_name,email,phone,date_of_birth,username,"
                    " password,club_team,national_team,is_admin) "
                    "OUTPUT INSERTED.id "
                    "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,0)",
                    (first, last, email, phone, dob, email, password, club, national),
                )
                new_id = cur.fetchone()[0]
                row = (new_id, first, last, email, phone, dob, email, club, national, 0)
        except Exception as e:  # noqa: BLE001
            return self._send(503, {"error": f"Database unavailable: {e}"})
        self._send(201, {"user": row_to_user(row)})

    def log_message(self, *args):  # quieter logs
        pass


if __name__ == "__main__":
    print(f"Kickoff auth API on http://{HOST}:{PORT}  (DB: {DB['server']}/{DB['database']})")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY: passwords are stored/compared in plain text only to match the
# requested "123" test account. For production, hash with bcrypt/argon2 in
# register() and compare hashes in login(), and load MTM_DB_PASSWORD from a
# secret store instead of a default baked into the source.
# ─────────────────────────────────────────────────────────────────────────────
