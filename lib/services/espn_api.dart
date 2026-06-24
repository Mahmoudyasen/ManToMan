import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models.dart';

/// Free football data via ESPN's public (unofficial) JSON endpoints — no API
/// key, broad coverage of leagues, cups, and national-team competitions.
class EspnApi {
  static const _site = 'site.api.espn.com';
  static const _searchHost = 'site.web.api.espn.com';

  /// Competitions scanned in the "by date" view.
  static const scanSlugs = <String>[
    'eng.1', 'esp.1', 'ita.1', 'ger.1', 'fra.1',
    'uefa.champions', 'uefa.europa', 'uefa.europa.conf',
    'eng.2', 'ned.1', 'por.1', 'ksa.1', 'usa.1',
    'uefa.nations', 'fifa.friendly',
    'fifa.worldq.uefa', 'fifa.worldq.conmebol', 'fifa.world',
  ];

  // ── Scoreboard (by competition / by date) ────────────────────
  /// Returns fixtures, the season's match-day calendar, and league metadata.
  static Future<
      ({
        List<Fixture> fixtures,
        List<DateTime> calendar,
        String leagueName,
        String leagueLogo,
      })> scoreboard(String slug, {DateTime? date}) async {
    final query = <String, String>{};
    if (date != null) query['dates'] = _ymd(date);
    final uri = Uri.https(_site, '/apis/site/v2/sports/soccer/$slug/scoreboard', query);
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw EspnException('Server returned ${res.statusCode}.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final league = (body['leagues'] as List?)?.cast<Map<String, dynamic>>().firstOrNull;
    final leagueName = league?['name'] as String? ?? '';
    final leagueLogo = _firstLogo(league?['logos']);
    final calendar = ((league?['calendar'] as List?) ?? [])
        .whereType<String>()
        .map((s) => DateTime.tryParse(s)?.toLocal())
        .whereType<DateTime>()
        .toList();

    final events = (body['events'] as List?) ?? [];
    final fixtures = events
        .cast<Map<String, dynamic>>()
        .map((e) => _parseEvent(e,
            leagueNameFallback: leagueName, leagueLogoFallback: leagueLogo))
        .whereType<Fixture>()
        .toList();
    _sort(fixtures);
    return (
      fixtures: fixtures,
      calendar: calendar,
      leagueName: leagueName,
      leagueLogo: leagueLogo,
    );
  }

  /// Current status of a competition (live / on-break / next match / ended).
  static Future<
      ({
        String name,
        String logo,
        bool live,
        int count,
        DateTime? next,
        bool ended,
      })> competitionStatus(String slug) async {
    final r = await scoreboard(slug);
    final upcoming = r.fixtures
        .where((f) => f.notStarted && f.kickoff != null)
        .toList()
      ..sort((a, b) => a.kickoff!.compareTo(b.kickoff!));
    return (
      name: r.leagueName,
      logo: r.leagueLogo,
      live: r.fixtures.any((f) => f.isLive),
      count: r.fixtures.length,
      next: upcoming.isNotEmpty ? upcoming.first.kickoff : null,
      // No upcoming match but the last season's games are loaded: ESPN hasn't
      // published the new fixtures yet.
      ended: upcoming.isEmpty && r.fixtures.any((f) => f.isFinished),
    );
  }

  /// Every fixture on a given day across the scanned competitions.
  static Future<List<Fixture>> fixturesByDate(DateTime date) async {
    final results = await Future.wait(
      scanSlugs.map((s) => scoreboard(s, date: date)
          .then((r) => r.fixtures)
          .catchError((_) => <Fixture>[])),
    );
    final all = results.expand((e) => e).toList();
    _sort(all);
    return all;
  }

  // ── Team schedule (club or national team) ────────────────────
  static Future<List<Fixture>> teamSchedule(
      String slug, int teamId, int season) async {
    final uri = Uri.https(
      _site,
      '/apis/site/v2/sports/soccer/$slug/teams/$teamId/schedule',
      {'season': '$season'},
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw EspnException('Server returned ${res.statusCode}.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final events = (body['events'] as List?) ?? [];
    final fixtures = events
        .cast<Map<String, dynamic>>()
        .map((e) => _parseEvent(e))
        .whereType<Fixture>()
        .toList();
    _sort(fixtures);
    return fixtures;
  }

  // ── Team search ──────────────────────────────────────────────
  static Future<List<EspnTeam>> searchTeams(String query) async {
    final q = query.trim();
    if (q.length < 3) return [];
    final uri = Uri.https(_searchHost, '/apis/search/v2',
        {'query': q, 'limit': '20', 'sport': 'soccer'});
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw EspnException('Server returned ${res.statusCode}.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final out = <EspnTeam>[];
    for (final r in (body['results'] as List?) ?? []) {
      if (r is! Map) continue;
      if (!'${r['type']}'.toLowerCase().contains('team')) continue;
      for (final it in (r['contents'] as List?) ?? []) {
        if (it is! Map) continue;
        final uid = '${it['uid']}';
        final idStr = uid.contains('~t:') ? uid.split('~t:').last : '';
        final id = int.tryParse(idStr);
        if (id == null) continue;
        final subtitle = '${it['subtitle'] ?? ''}';
        final lower = subtitle.toLowerCase();
        // Skip women's teams to keep the list focused.
        if (lower.contains('women')) continue;
        final national = lower.contains('soccer team');
        out.add(EspnTeam(
          id: id,
          name: '${it['displayName'] ?? ''}',
          league: subtitle,
          slug: _slugForLeague(subtitle, national),
          national: national,
        ));
      }
    }
    return out;
  }

  // ── Parsing helpers ──────────────────────────────────────────
  static Fixture? _parseEvent(Map<String, dynamic> event,
      {String leagueNameFallback = '', String leagueLogoFallback = ''}) {
    final comps = event['competitions'] as List?;
    if (comps == null || comps.isEmpty) return null;
    final comp = comps.first as Map<String, dynamic>;
    final competitors = (comp['competitors'] as List?)?.cast<Map<String, dynamic>>();
    if (competitors == null || competitors.length < 2) return null;

    Map<String, dynamic> side(String ha) => competitors.firstWhere(
        (c) => c['homeAway'] == ha,
        orElse: () => competitors[ha == 'home' ? 0 : 1]);
    final home = side('home');
    final away = side('away');
    final homeTeam = home['team'] as Map<String, dynamic>? ?? {};
    final awayTeam = away['team'] as Map<String, dynamic>? ?? {};

    final status = (comp['status'] ?? event['status']) as Map<String, dynamic>?;
    final type = status?['type'] as Map<String, dynamic>?;
    final state = type?['state'] as String? ?? 'pre';
    final detail = (type?['shortDetail'] ?? type?['detail'] ?? '') as String;

    String short;
    int? elapsed;
    switch (state) {
      case 'in':
        short = 'LIVE';
        elapsed = _minute(status);
      case 'post':
        short = 'FT';
      default:
        short = 'NS';
    }

    final leagueName =
        (event['league'] as Map<String, dynamic>?)?['name'] as String? ??
            leagueNameFallback;

    return Fixture(
      home: '${homeTeam['displayName'] ?? homeTeam['name'] ?? 'Home'}',
      away: '${awayTeam['displayName'] ?? awayTeam['name'] ?? 'Away'}',
      homeLogo: _teamLogo(homeTeam),
      awayLogo: _teamLogo(awayTeam),
      league: leagueName,
      leagueLogo: leagueLogoFallback,
      statusShort: short,
      statusLong: detail,
      goalsHome: _score(home['score']),
      goalsAway: _score(away['score']),
      elapsed: elapsed,
      kickoff: event['date'] != null
          ? DateTime.tryParse('${event['date']}')?.toLocal()
          : null,
    );
  }

  static int? _score(dynamic s) {
    if (s == null) return null;
    if (s is num) return s.toInt();
    if (s is String) return int.tryParse(s);
    if (s is Map) {
      final v = s['value'];
      if (v is num) return v.toInt();
      return int.tryParse('${s['displayValue']}');
    }
    return null;
  }

  static int? _minute(Map<String, dynamic>? status) {
    if (status == null) return null;
    final clock = '${status['displayClock'] ?? ''}';
    final m = RegExp(r'(\d+)').firstMatch(clock);
    if (m != null) return int.tryParse(m.group(1)!);
    final period = status['period'];
    return period is num ? period.toInt() : null;
  }

  static String _teamLogo(Map<String, dynamic> team) {
    final logo = team['logo'];
    if (logo is String && logo.isNotEmpty) return logo;
    final logos = team['logos'];
    if (logos is List && logos.isNotEmpty) {
      return '${(logos.first as Map)['href'] ?? ''}';
    }
    final id = team['id'];
    if (id != null) return 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png';
    return '';
  }

  static String _firstLogo(dynamic logos) {
    if (logos is List && logos.isNotEmpty) {
      return '${(logos.first as Map)['href'] ?? ''}';
    }
    return '';
  }

  static void _sort(List<Fixture> fixtures) {
    fixtures.sort((a, b) {
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      final ak = a.kickoff, bk = b.kickoff;
      if (ak == null || bk == null) return 0;
      return ak.compareTo(bk);
    });
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  /// Maps a search subtitle (league display name) to an ESPN slug for the
  /// team-schedule endpoint. National teams use the World Cup slug.
  static String _slugForLeague(String subtitle, bool national) {
    if (national) return 'fifa.world';
    final s = subtitle.toLowerCase();
    if (s.contains('premier league')) return 'eng.1';
    if (s.contains('laliga') || s.contains('la liga')) return 'esp.1';
    if (s.contains('serie a')) return 'ita.1';
    if (s.contains('bundesliga')) return 'ger.1';
    if (s.contains('ligue 1')) return 'fra.1';
    if (s.contains('eredivisie')) return 'ned.1';
    if (s.contains('primeira') || s.contains('liga portugal')) return 'por.1';
    if (s.contains('saudi')) return 'ksa.1';
    if (s.contains('mls') || s.contains('major league')) return 'usa.1';
    if (s.contains('championship')) return 'eng.2';
    if (s.contains('champions league')) return 'uefa.champions';
    return ''; // unknown — schedule lookup will be unavailable
  }
}

/// A team returned by ESPN search.
class EspnTeam {
  final int id;
  final String name;
  final String league; // human-readable league/subtitle
  final String slug; // ESPN league slug for schedule lookups ('' if unknown)
  final bool national;
  const EspnTeam({
    required this.id,
    required this.name,
    required this.league,
    required this.slug,
    required this.national,
  });

  String get logo => 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png';
}

class EspnException implements Exception {
  final String message;
  EspnException(this.message);
  @override
  String toString() => message;
}
