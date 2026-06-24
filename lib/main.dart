import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/fixtures_screen.dart';
import 'screens/news_screen.dart';
import 'screens/podcast_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/questions_screen.dart';
import 'screens/suggestions_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  await store.init();
  runApp(const KickoffApp());
}

class KickoffApp extends StatelessWidget {
  const KickoffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kickoff',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.violetDark,
        fontFamily: 'SF Pro Display',
        colorScheme: ColorScheme.fromSeed(seedColor: C.violet),
      ),
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.ready) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }
          return store.currentUser == null ? const AuthScreen() : const RootShell();
        },
      ),
    );
  }
}

/// The tabs available in the app.
enum Tab { questions, podcast, suggestions, challenges, fixtures, news, profile }

const _tabMeta = <Tab, (IconData, String)>{
  Tab.questions: (Icons.forum_rounded, 'Community Q&A'),
  Tab.podcast: (Icons.podcasts_rounded, 'Podcast'),
  Tab.suggestions: (Icons.lightbulb_outline_rounded, 'Suggestions'),
  Tab.challenges: (Icons.emoji_events_outlined, 'Challenges'),
  Tab.fixtures: (Icons.event_note_outlined, 'Fixtures'),
  Tab.news: (Icons.article_outlined, 'News'),
  Tab.profile: (Icons.person_outline_rounded, 'Profile'),
};

/// ─────────────────────────────────────────────────────────────────
/// Root shell — keeps the original 3D drawer transform and floating
/// bottom bar, now driving navigation across every tab.
/// ─────────────────────────────────────────────────────────────────
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  Tab _tab = Tab.questions;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 430));
    _anim = CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() => _ctrl.forward();
  void _close() => _ctrl.reverse();

  void _select(Tab tab) {
    setState(() => _tab = tab);
    _close();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final w = MediaQuery.of(context).size.width;
    _ctrl.value += (d.primaryDelta ?? 0) / (w * 0.62);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() > 450) {
      v > 0 ? _open() : _close();
    } else {
      _ctrl.value > 0.45 ? _open() : _close();
    }
  }

  Widget _screenFor(Tab tab) {
    switch (tab) {
      case Tab.questions:
        return QuestionsScreen(onMenu: _open);
      case Tab.podcast:
        return PodcastScreen(onMenu: _open);
      case Tab.suggestions:
        return SuggestionsScreen(onMenu: _open);
      case Tab.challenges:
        return ChallengesScreen(onMenu: _open);
      case Tab.fixtures:
        return FixturesScreen(onMenu: _open);
      case Tab.news:
        return NewsScreen(onMenu: _open);
      case Tab.profile:
        return ProfileScreen(onMenu: _open, onLogout: store.logout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          final slide = size.width * 0.58 * t;
          final scale = 1 - 0.26 * t;
          final rotate = -0.30 * t;
          final radius = 30.0 * t;

          return Stack(
            children: [
              const Positioned.fill(child: _Backdrop()),
              SideMenu(
                progress: t,
                current: _tab,
                onClose: _close,
                onSelect: _select,
                onLogout: store.logout,
              ),
              GestureDetector(
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0011)
                    ..translate(slide)
                    ..scale(scale)
                    ..rotateY(rotate),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: t > 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28 * t),
                                blurRadius: 44,
                                offset: const Offset(-14, 22),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.white,
                          child: SafeArea(
                            bottom: false,
                            child: ListenableBuilder(
                              listenable: store,
                              builder: (context, _) => _screenFor(_tab),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _BottomBar(
                            current: _tab,
                            onSelect: (tab) => setState(() => _tab = tab),
                          ),
                        ),
                        if (t > 0.001)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _close,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: C.pageGradient),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────
/// Side menu — the signature staggered drawer, now full navigation.
/// ─────────────────────────────────────────────────────────────────
class SideMenu extends StatelessWidget {
  final double progress;
  final Tab current;
  final VoidCallback onClose;
  final ValueChanged<Tab> onSelect;
  final VoidCallback onLogout;
  const SideMenu({
    super.key,
    required this.progress,
    required this.current,
    required this.onClose,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final me = store.currentUser;
    return IgnorePointer(
      ignoring: p < 0.5,
      child: Opacity(
        opacity: p,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 14, 0, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InitialAvatar(
                        name: me?.displayName ?? '?',
                        size: 52,
                        admin: me?.isAdmin ?? false),
                    const Spacer(),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                ),
                const SizedBox(height: 18),
                Text(me?.displayName ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text(
                    me?.isAdmin == true
                        ? 'Admin · the host'
                        : '@${me?.username ?? ''}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 30),
                for (var i = 0; i < Tab.values.length; i++)
                  _MenuRow(
                    icon: _tabMeta[Tab.values[i]]!.$1,
                    label: _tabMeta[Tab.values[i]]!.$2,
                    progress: p,
                    index: i,
                    active: current == Tab.values[i],
                    onTap: () => onSelect(Tab.values[i]),
                  ),
                const Spacer(),
                _MenuRow(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  progress: p,
                  index: Tab.values.length,
                  active: false,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double progress;
  final int index;
  final bool active;
  final VoidCallback onTap;
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.progress,
    required this.index,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stagger = (progress * 1.4 - index * 0.05).clamp(0.0, 1.0);
    final dx = (1 - stagger) * -36;
    return Transform.translate(
      offset: Offset(dx, 0),
      child: Opacity(
        opacity: stagger,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 18),
                  Text(label,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────
/// Bottom bar with the floating central button (now → Community Q&A).
/// ─────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final Tab current;
  final ValueChanged<Tab> onSelect;
  const _BottomBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navIcon(Icons.podcasts_rounded, Tab.podcast),
                  _navIcon(Icons.article_outlined, Tab.news),
                  const SizedBox(width: 64),
                  _navIcon(Icons.event_note_outlined, Tab.fixtures),
                  _navIcon(Icons.person_outline_rounded, Tab.profile),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 34,
            child: GestureDetector(
              onTap: () => onSelect(Tab.questions),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: C.accentGradient,
                  border: Border.all(
                      color: current == Tab.questions
                          ? Colors.white
                          : Colors.transparent,
                      width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: C.accent.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.forum_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, Tab tab) {
    final active = current == tab;
    return GestureDetector(
      onTap: () => onSelect(tab),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(icon, size: 27, color: active ? C.violetMid : C.muted),
      ),
    );
  }
}
