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
| **Login / Sign up** | Gate before the app. Seeded demo accounts + new sign‑ups. |
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

You can also create new community accounts from the Sign‑up tab.

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
