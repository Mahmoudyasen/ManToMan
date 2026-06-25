# ManToMan ⚽ (Kickoff)

A community-driven football companion app built with Flutter. The host ("the
admin") runs the show — opening question rounds, broadcasting podcast episodes,
and fielding challenges — while the community asks, suggests, votes, and listens,
hoping to get mentioned on air. It also bundles live fixtures and football news.

The design language is a violet gradient identity with a signature 3D side
drawer, rounded cards, and a floating bottom bar.

## Features

| Tab | What it does |
| --- | --- |
| **Login / Sign up** | Gate before the app. Unified login (email **or** username + password; admin rights come from the account's flag — no separate admin login). Sign‑up collects name, last name, email, phone, date of birth, and the **club** + **national team** you support, picked from lists with crests & flags. You can't register as an admin. |
| **Community Q&A** | Admin opens/closes question rounds with a topic; members ask & upvote; admin marks questions "on the show". |
| **Podcast** | Admin publishes episodes (title / description / audio URL); everyone listens with an inline play / pause / scrub player. |
| **Suggestions** | Members suggest ideas and upvote; admin moves them Fresh → Planned → Done. |
| **Challenges** | Members dare the admin; admin accepts / declines. |
| **Fixtures** | Live scores & schedules via ESPN's free endpoints — browse by date, by competition (clubs + national‑team tournaments incl. the World Cup), or by team / national team, plus an "all competitions" status overview (live · on‑break · start date). |
| **News** | Aggregated football headlines from BBC Sport, Sky Sports, ESPN and The Guardian RSS feeds. |
| **Profile** | Your account, activity stats, editable details, and logout. |

## Demo accounts

| Role | Username | Password |
| --- | --- | --- |
| Admin (the host) | `mantoman` | `123` |
| Community member | `mahmoud` | `123` |

You can also create new community accounts from the Sign‑up tab (members log in
with their email).

## Database (Azure SQL) + backend API

Auth is backed by the Azure SQL database `man-to-man`. Because Flutter has no
working pure‑Dart SQL Server driver — and shipping the DB password inside the app
would be insecure — the app talks to a tiny **backend API** that owns the DB
credentials. The app calls it over HTTP; only the API touches SQL.

```
Flutter app ──HTTP──▶ backend/app.py ──TDS──▶ Azure SQL (users table)
```

**1. Create the table + admin** (once). The `users` schema and the seeded
`mantoman` admin live in [`db/schema.sql`](db/schema.sql). Easiest is **Azure
Portal → your SQL database → Query editor → paste → Run**.

**2. Run the API.** Needs Python 3.

```bash
cd backend
./run.sh                 # creates a venv, installs deps, starts on :8000
# health check:
curl http://localhost:8000/health      # -> {"ok": true}
```

**3. Run the app.** It auto‑targets the API:

- macOS / Chrome / iOS simulator → `http://localhost:8000`
- Android emulator → `http://10.0.2.2:8000` (handled automatically)
- Real phone on Wi‑Fi → pass your machine's LAN IP:
  `flutter run --dart-define=KICKOFF_API=http://192.168.1.x:8000`

If the API is unreachable the app falls back to local `shared_preferences` so it
still runs (with the seeded demo accounts), then syncs to the DB once the API is
back. The server still needs **Public network access** enabled in Azure Portal →
SQL server → Networking (+ a firewall rule for wherever the API runs).

> **Security:** passwords are stored in plain text only to honour the `123` test
> account. For production, hash them in the API and load the DB password from a
> secret instead of the default baked into `backend/run.sh`.

## Getting started

```bash
flutter pub get
flutter run            # pick a device, e.g. -d macos or -d chrome
```

> **Note on networking:** Fixtures and News make live HTTP calls, so they work
> best on **macOS / iOS / Android**. On Flutter **web (Chrome)** the RSS feeds
> and some endpoints may be blocked by CORS.

## Tech notes

- **State & persistence:** a single `ChangeNotifier` store (`lib/store.dart`)
  backed by `shared_preferences` — no backend; data survives restarts.
- **Fixtures data:** ESPN's public (unofficial) soccer JSON API — free and
  keyless, with broad coverage including national‑team competitions. It's
  undocumented, so it could change; the client is isolated in
  `lib/services/espn_api.dart`.
- **News:** RSS parsed with the `xml` package (`lib/services/news_service.dart`).
- **Audio:** `audioplayers` for podcast playback.

## Project layout

```
lib/
  main.dart            App entry, 3D drawer shell, navigation, auth gate
  theme.dart           Palette + shared widgets
  widgets.dart         Reusable feed widgets (vote chip, composer sheet, …)
  models.dart          Data models
  store.dart           Persistent app state (shared_preferences)
  services/
    espn_api.dart      Fixtures, competitions, team search (ESPN)
    news_service.dart  RSS news aggregation
  screens/             One file per tab
```

## Dependencies

`http`, `shared_preferences`, `xml`, `audioplayers`, `url_launcher`, `intl`.

---

Built with [Flutter](https://flutter.dev). Fixtures courtesy of ESPN's public
endpoints; news courtesy of the respective publishers' RSS feeds.
