import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/espn_api.dart';
import '../theme.dart';

/// A selectable competition (ESPN league slug).
class _Comp {
  final String slug;
  final String name;
  final bool national;
  const _Comp(this.slug, this.name, {this.national = false});
}

const _clubComps = <_Comp>[
  _Comp('eng.1', 'Premier League'),
  _Comp('esp.1', 'La Liga'),
  _Comp('ita.1', 'Serie A'),
  _Comp('ger.1', 'Bundesliga'),
  _Comp('fra.1', 'Ligue 1'),
  _Comp('uefa.champions', 'Champions League'),
  _Comp('uefa.europa', 'Europa League'),
  _Comp('uefa.europa.conf', 'Conference League'),
  _Comp('eng.2', 'Championship'),
  _Comp('ned.1', 'Eredivisie'),
  _Comp('por.1', 'Primeira Liga'),
  _Comp('ksa.1', 'Saudi Pro League'),
  _Comp('usa.1', 'MLS'),
];

const _nationalComps = <_Comp>[
  _Comp('fifa.world', 'World Cup', national: true),
  _Comp('fifa.worldq.uefa', 'WC Qualifying — Europe', national: true),
  _Comp('fifa.worldq.conmebol', 'WC Qualifying — S. America', national: true),
  _Comp('uefa.euro', 'Euro Championship', national: true),
  _Comp('uefa.nations', 'Nations League', national: true),
  _Comp('conmebol.america', 'Copa América', national: true),
  _Comp('caf.nations', 'Africa Cup of Nations', national: true),
  _Comp('fifa.friendly', 'International Friendlies', national: true),
];

/// Popular national teams (ESPN team ids) for one-tap selection.
const _nationalTeams = <(int, String)>[
  (205, 'Brazil'),
  (202, 'Argentina'),
  (478, 'France'),
  (448, 'England'),
  (164, 'Spain'),
  (481, 'Germany'),
  (482, 'Portugal'),
  (162, 'Italy'),
  (449, 'Netherlands'),
  (2869, 'Morocco'),
  (2620, 'Egypt'),
];

const _teamSeasons = [2026, 2025, 2024, 2023, 2022];

/// A competition + its current status, for the overview list.
class _CompRow {
  final _Comp comp;
  final String logo;
  final bool live;
  final int count;
  final DateTime? next;
  final bool ended;
  const _CompRow(
      this.comp, this.logo, this.live, this.count, this.next, this.ended);
}

enum _Scope { date, competition, team }

/// Live + scheduled fixtures via ESPN's free endpoints. Browse by date, by
/// competition (clubs + national-team tournaments), or by team.
class FixturesScreen extends StatefulWidget {
  final VoidCallback onMenu;
  const FixturesScreen({super.key, required this.onMenu});

  @override
  State<FixturesScreen> createState() => _FixturesScreenState();
}

class _FixturesScreenState extends State<FixturesScreen> {
  _Scope _scope = _Scope.date;

  // Date mode
  DateTime _selected = DateTime.now();

  // Competition mode
  _Comp? _comp;
  DateTime? _compDate; // null = ESPN "current" view
  List<DateTime> _calendar = [];

  // Team mode
  EspnTeam? _team;
  int _season = 2025;

  Future<List<Fixture>>? _future;
  Future<List<_CompRow>>? _overviewFuture;

  @override
  void initState() {
    super.initState();
    _loadDate();
    _loadOverview();
  }

  // ── Loaders ──────────────────────────────────────────────────
  void _loadDate() {
    setState(() {
      _future = EspnApi.fixturesByDate(_selected);
    });
  }

  /// Status of every available competition (fetched once, date-independent).
  void _loadOverview() {
    final comps = [..._nationalComps, ..._clubComps];
    _overviewFuture = Future.wait(comps.map((c) async {
      try {
        final s = await EspnApi.competitionStatus(c.slug);
        return _CompRow(c, s.logo, s.live, s.count, s.next, s.ended);
      } catch (_) {
        return _CompRow(c, '', false, 0, null, false);
      }
    }));
  }

  void _loadComp({DateTime? date}) {
    _compDate = date;
    final req = EspnApi.scoreboard(_comp!.slug, date: date);
    setState(() {
      _future = req.then((r) {
        if (r.calendar.isNotEmpty && mounted) {
          // Update the date strip after the frame to avoid setState-in-build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _calendar = r.calendar);
          });
        }
        return r.fixtures;
      });
    });
  }

  void _loadTeam() {
    setState(() {
      _future = _team!.slug.isEmpty
          ? Future.error(EspnException(
              'A schedule isn\'t available for this team\'s league.'))
          : EspnApi.teamSchedule(_team!.slug, _team!.id, _season);
    });
  }

  void _reload() {
    switch (_scope) {
      case _Scope.date:
        setState(_loadOverview);
        _loadDate();
      case _Scope.competition:
        _loadComp(date: _compDate);
      case _Scope.team:
        _loadTeam();
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(
          title: 'Fixtures',
          subtitle: 'LIVE SCORES & SCHEDULE',
          onMenu: widget.onMenu,
          trailing: GestureDetector(
            onTap: _reload,
            child: Container(
              width: 46,
              height: 46,
              decoration:
                  const BoxDecoration(color: C.chip, shape: BoxShape.circle),
              child: const Icon(Icons.refresh_rounded, color: C.ink, size: 22),
            ),
          ),
        ),
        _scopeBar(),
        switch (_scope) {
          _Scope.date => _dateStrip(),
          _Scope.competition => _calendarStrip(),
          _Scope.team => _seasonPicker(),
        },
        Expanded(
          child: _scope == _Scope.date ? _dateBody() : _fixturesBody(),
        ),
      ],
    );
  }

  // ── Body for competition / team scopes ───────────────────────
  Widget _fixturesBody() {
    return FutureBuilder<List<Fixture>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: C.violetMid));
        }
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load fixtures',
            message: '${snap.error}',
            action: _retry(),
          );
        }
        final fixtures = snap.data ?? [];
        if (fixtures.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'No matches',
            message: _scope == _Scope.competition
                ? 'No matches for ${_comp!.name} here. Try another date on the strip above.'
                : 'No fixtures for ${_team!.name} in $_season. Try another season.',
            action: _retry(),
          );
        }
        return _list(
          fixtures,
          header:
              _scope == _Scope.competition ? _seasonNotice(fixtures) : null,
        );
      },
    );
  }

  // ── Body for the date scope: day matches + all-competitions overview ──
  Widget _dateBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
      physics: const BouncingScrollPhysics(),
      children: [
        FutureBuilder<List<Fixture>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(color: C.violetMid)),
              );
            }
            final fixtures = snap.data ?? [];
            if (snap.hasError || fixtures.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(top: 6, bottom: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: C.chip, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy_rounded, color: C.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          'No matches on ${DateFormat('EEE d MMM').format(_selected)}. See every competition\'s status below.',
                          style: const TextStyle(
                              fontSize: 13, color: C.muted, height: 1.3)),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _leagueSections(fixtures),
            );
          },
        ),
        const SizedBox(height: 18),
        _overviewSection(),
      ],
    );
  }

  // ── All-competitions overview ────────────────────────────────
  Widget _overviewSection() {
    return FutureBuilder<List<_CompRow>>(
      future: _overviewFuture,
      builder: (context, snap) {
        final rows = [...(snap.data ?? <_CompRow>[])];
        if (rows.isEmpty) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: C.violetMid)),
            );
          }
          return const SizedBox.shrink();
        }
        // Live first, then soonest upcoming (nulls last).
        rows.sort((a, b) {
          if (a.live != b.live) return a.live ? -1 : 1;
          final an = a.next, bn = b.next;
          if (an == null && bn == null) return 0;
          if (an == null) return 1;
          if (bn == null) return -1;
          return an.compareTo(bn);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text('ALL COMPETITIONS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: C.muted,
                      letterSpacing: 0.6)),
            ),
            ...rows.map(_overviewRow),
          ],
        );
      },
    );
  }

  Widget _overviewRow(_CompRow r) {
    // Status chip text/colour.
    String status;
    Color color;
    if (r.live) {
      status = 'LIVE';
      color = C.live;
    } else if (r.next != null &&
        r.next!.difference(DateTime.now()).inDays >= 10) {
      status = 'On break · ${DateFormat('d MMM').format(r.next!)}';
      color = C.muted;
    } else if (r.next != null) {
      status = DateFormat('EEE d MMM').format(r.next!);
      color = C.violetMid;
    } else if (r.ended) {
      status = 'Season ended';
      color = C.muted;
    } else {
      status = 'No fixtures';
      color = C.muted;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () {
          setState(() {
            _scope = _Scope.competition;
            _comp = r.comp;
            _calendar = [];
          });
          _loadComp(date: null);
        },
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: r.logo.isEmpty
                  ? Icon(
                      r.comp.national
                          ? Icons.flag_rounded
                          : Icons.emoji_events_rounded,
                      size: 22,
                      color: C.violetMid)
                  : Image.network(r.logo,
                      errorBuilder: (_, _, _) => Icon(
                          r.comp.national
                              ? Icons.flag_rounded
                              : Icons.emoji_events_rounded,
                          size: 22,
                          color: C.violetMid)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(r.comp.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: C.ink)),
            ),
            const SizedBox(width: 8),
            if (r.live)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration:
                    const BoxDecoration(color: C.live, shape: BoxShape.circle),
              ),
            Flexible(
              child: Text(status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
          ],
        ),
      ),
    );
  }

  /// When a competition has no live/finished games and its first match is
  /// well in the future, surface a clear "not started yet" notice.
  Widget? _seasonNotice(List<Fixture> fixtures) {
    if (fixtures.isEmpty) return null;
    if (fixtures.any((f) => f.isLive || f.isFinished)) return null;
    final upcoming = fixtures
        .where((f) => f.notStarted && f.kickoff != null)
        .toList()
      ..sort((a, b) => a.kickoff!.compareTo(b.kickoff!));
    if (upcoming.isEmpty) return null;
    final first = upcoming.first.kickoff!;
    if (first.difference(DateTime.now()).inDays < 10) return null;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: C.cardGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pause_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_comp!.name} hasn\'t kicked off yet',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    'On break — first match ${DateFormat('EEE d MMM yyyy').format(first)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Scope bar ────────────────────────────────────────────────
  Widget _scopeBar() {
    String label;
    IconData icon;
    switch (_scope) {
      case _Scope.date:
        label = 'Browse by date';
        icon = Icons.calendar_today_rounded;
      case _Scope.competition:
        label = _comp!.name;
        icon = _comp!.national
            ? Icons.flag_rounded
            : Icons.emoji_events_rounded;
      case _Scope.team:
        label = _team!.name;
        icon = Icons.shield_rounded;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: GestureDetector(
        onTap: _openScopeSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration:
              BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(icon, size: 20, color: C.violetMid),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: C.ink)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.tune_rounded, size: 20, color: C.violetMid),
            ],
          ),
        ),
      ),
    );
  }

  // ── Date strip (date mode) ───────────────────────────────────
  Widget _dateStrip() {
    final today = DateTime.now();
    final days = List.generate(11, (i) => today.add(Duration(days: i - 3)));
    return _DateRow(
      dates: days,
      isSelected: (d) => _sameDay(d, _selected),
      onTap: (d) {
        setState(() => _selected = d);
        _loadDate();
      },
    );
  }

  // ── Calendar strip (competition mode) ────────────────────────
  Widget _calendarStrip() {
    if (_calendar.isEmpty) {
      return const SizedBox(height: 8);
    }
    // Keep the strip readable: dates near "now" first.
    final dates = [..._calendar]..sort();
    return _DateRow(
      dates: dates,
      isSelected: (d) => _compDate != null && _sameDay(d, _compDate!),
      leading: _miniChip('Current', _compDate == null,
          () => _loadComp(date: null)),
      onTap: (d) => _loadComp(date: d),
    );
  }

  Widget _miniChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active ? C.cardGradient : null,
          color: active ? null : C.chip,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : C.ink)),
      ),
    );
  }

  // ── Season picker (team mode) ────────────────────────────────
  Widget _seasonPicker() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        physics: const BouncingScrollPhysics(),
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 10, top: 8),
            child: Text('SEASON',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: C.muted,
                    letterSpacing: 0.6)),
          ),
          for (final s in _teamSeasons)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (_season == s) return;
                  setState(() => _season = s);
                  _loadTeam();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: _season == s ? C.cardGradient : null,
                    color: _season == s ? null : C.chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text('$s',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _season == s ? Colors.white : C.ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _retry() => GestureDetector(
        onTap: _reload,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
              color: C.chip, borderRadius: BorderRadius.circular(14)),
          child: const Text('Retry',
              style: TextStyle(
                  color: C.violetMid,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ),
      );

  // ── Fixtures list ────────────────────────────────────────────
  Widget _list(List<Fixture> fixtures, {Widget? header}) {
    final sections = _leagueSections(fixtures);
    final hasHeader = header != null;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
      physics: const BouncingScrollPhysics(),
      itemCount: sections.length + (hasHeader ? 1 : 0),
      itemBuilder: (_, idx) {
        if (hasHeader && idx == 0) return header;
        return sections[idx - (hasHeader ? 1 : 0)];
      },
    );
  }

  /// Builds one non-scrolling section per competition (header + match cards).
  List<Widget> _leagueSections(List<Fixture> fixtures) {
    final byLeague = <String, List<Fixture>>{};
    for (final f in fixtures) {
      byLeague.putIfAbsent(f.league, () => []).add(f);
    }
    return byLeague.entries.map((e) {
      final group = e.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
            child: Row(
              children: [
                if (group.first.leagueLogo.isNotEmpty)
                  Image.network(group.first.leagueLogo,
                      width: 22,
                      height: 22,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.shield_outlined, size: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.key,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: C.ink)),
                ),
              ],
            ),
          ),
          ...group.map(_fixtureCard),
        ],
      );
    }).toList();
  }

  Widget _fixtureCard(Fixture f) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _teamRow(f.home, f.homeLogo, right: true)),
              _centre(f),
              Expanded(child: _teamRow(f.away, f.awayLogo, right: false)),
            ],
          ),
          if (f.kickoff != null && f.notStarted) ...[
            const SizedBox(height: 8),
            Text(DateFormat('EEE d MMM').format(f.kickoff!),
                style: const TextStyle(fontSize: 11, color: C.muted)),
          ],
        ],
      ),
    );
  }

  Widget _teamRow(String name, String logo, {required bool right}) {
    final logoWidget = logo.isEmpty
        ? const Icon(Icons.sports_soccer, size: 26, color: C.muted)
        : Image.network(logo,
            width: 28,
            height: 28,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.sports_soccer, size: 26, color: C.muted));
    final text = Flexible(
      child: Text(name,
          textAlign: right ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700, color: C.ink)),
    );
    return Row(
      mainAxisAlignment:
          right ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: right
          ? [text, const SizedBox(width: 10), logoWidget]
          : [logoWidget, const SizedBox(width: 10), text],
    );
  }

  Widget _centre(Fixture f) {
    String label;
    Color color = C.muted;
    if (f.isLive) {
      label = f.elapsed != null ? "${f.elapsed}'" : 'LIVE';
      color = C.live;
    } else if (f.isFinished) {
      label = 'FT';
    } else if (f.kickoff != null) {
      label = DateFormat('HH:mm').format(f.kickoff!);
    } else {
      label = f.statusShort;
    }

    final showScore = f.isLive || f.isFinished;
    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showScore)
            Text('${f.goalsHome ?? 0} - ${f.goalsAway ?? 0}',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w900, color: C.ink))
          else
            const Icon(Icons.schedule_rounded, size: 18, color: C.muted),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  // ── Scope sheet ──────────────────────────────────────────────
  void _openScopeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScopeSheet(
        onDate: () {
          Navigator.pop(ctx);
          setState(() => _scope = _Scope.date);
          _loadDate();
        },
        onComp: (c) {
          Navigator.pop(ctx);
          setState(() {
            _scope = _Scope.competition;
            _comp = c;
            _calendar = [];
          });
          _loadComp(date: null);
        },
        onTeam: (t) {
          Navigator.pop(ctx);
          setState(() {
            _scope = _Scope.team;
            _team = t;
            _season = t.national ? 2026 : 2025;
          });
          _loadTeam();
        },
      ),
    );
  }
}

/// Horizontal day selector shared by date + calendar strips.
class _DateRow extends StatelessWidget {
  final List<DateTime> dates;
  final bool Function(DateTime) isSelected;
  final ValueChanged<DateTime> onTap;
  final Widget? leading;
  const _DateRow({
    required this.dates,
    required this.isSelected,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        physics: const BouncingScrollPhysics(),
        children: [
          if (leading != null) leading!,
          for (final d in dates)
            GestureDetector(
              onTap: () => onTap(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 58,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected(d) ? C.cardGradient : null,
                  color: isSelected(d) ? null : C.chip,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('E').format(d).toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected(d) ? Colors.white70 : C.muted)),
                    const SizedBox(height: 4),
                    Text('${d.day}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSelected(d) ? Colors.white : C.ink)),
                    Text(DateFormat('MMM').format(d).toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isSelected(d) ? Colors.white70 : C.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Filter sheet: date, competitions (clubs + national), or team search.
class _ScopeSheet extends StatefulWidget {
  final VoidCallback onDate;
  final ValueChanged<_Comp> onComp;
  final ValueChanged<EspnTeam> onTeam;
  const _ScopeSheet(
      {required this.onDate, required this.onComp, required this.onTeam});

  @override
  State<_ScopeSheet> createState() => _ScopeSheetState();
}

class _ScopeSheetState extends State<_ScopeSheet> {
  final _search = TextEditingController();
  Future<List<EspnTeam>>? _teamFuture;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch(String q) {
    if (q.trim().length < 3) {
      setState(() => _teamFuture = null);
      return;
    }
    setState(() => _teamFuture = EspnApi.searchTeams(q));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                  color: C.chip, borderRadius: BorderRadius.circular(3)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                physics: const BouncingScrollPhysics(),
                children: [
                  const Text('Show fixtures for',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: C.ink)),
                  const SizedBox(height: 16),
                  SoftCard(
                    onTap: widget.onDate,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: const [
                        Icon(Icons.calendar_today_rounded, color: C.violetMid),
                        SizedBox(width: 14),
                        Text('Browse by date',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: C.ink)),
                        Spacer(),
                        Icon(Icons.chevron_right_rounded, color: C.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _label('NATIONAL TEAMS & CUPS'),
                  const SizedBox(height: 12),
                  _compWrap(_nationalComps),
                  const SizedBox(height: 22),
                  _label('CLUB COMPETITIONS'),
                  const SizedBox(height: 12),
                  _compWrap(_clubComps),
                  const SizedBox(height: 22),
                  _label('POPULAR NATIONAL TEAMS'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final (id, name) in _nationalTeams)
                        _teamChip(id, name),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _label('FIND ANY TEAM'),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _search,
                    hint: 'Search club or country (min 3 letters)…',
                    icon: Icons.search_rounded,
                    action: TextInputAction.search,
                    onSubmitted: _runSearch,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _runSearch(_search.text),
                      child: const Text('Search',
                          style: TextStyle(
                              color: C.violetMid,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  if (_teamFuture != null) _searchResults(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchResults() {
    return FutureBuilder<List<EspnTeam>>(
      future: _teamFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: C.violetMid)),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('${snap.error}',
                style: const TextStyle(color: C.live, fontSize: 13)),
          );
        }
        final teams = snap.data ?? [];
        if (teams.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No teams found.', style: TextStyle(color: C.muted)),
          );
        }
        return Column(
          children: [
            for (final t in teams)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Image.network(t.logo,
                    width: 32,
                    height: 32,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.shield_outlined)),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(t.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: C.ink)),
                    ),
                    if (t.national) ...[
                      const SizedBox(width: 8),
                      const TagBadge('NATIONAL', color: C.accent),
                    ],
                  ],
                ),
                subtitle: t.league.isEmpty
                    ? null
                    : Text(t.league, style: const TextStyle(color: C.muted)),
                onTap: () => widget.onTeam(t),
              ),
          ],
        );
      },
    );
  }

  Widget _compWrap(List<_Comp> comps) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in comps)
          GestureDetector(
            onTap: () => widget.onComp(c),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: C.field, borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      c.national
                          ? Icons.flag_rounded
                          : Icons.emoji_events_rounded,
                      size: 18,
                      color: C.violetMid),
                  const SizedBox(width: 8),
                  Text(c.name,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: C.ink)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _teamChip(int id, String name) {
    return GestureDetector(
      onTap: () => widget.onTeam(EspnTeam(
        id: id,
        name: name,
        league: 'National team',
        slug: 'fifa.world',
        national: true,
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration:
            BoxDecoration(color: C.field, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network('https://a.espncdn.com/i/teamlogos/soccer/500/$id.png',
                width: 20,
                height: 20,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.flag_rounded, size: 18, color: C.violetMid)),
            const SizedBox(width: 8),
            Text(name,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: C.ink)),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: C.muted,
          letterSpacing: 0.6));
}
