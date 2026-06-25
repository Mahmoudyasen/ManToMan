import 'package:flutter/material.dart';

import '../data/teams.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Profile tab — shows the signed-in user, their activity stats, and lets
/// them edit their details or log out.
class ProfileScreen extends StatelessWidget {
  final VoidCallback onMenu;
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onMenu, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final me = store.currentUser!;
    final myQuestions =
        store.questions.where((q) => q.author == me.username).length;
    final mentioned = store.questions
        .where((q) => q.author == me.username && q.mentioned)
        .length;
    final mySuggestions =
        store.suggestions.where((s) => s.author == me.username).length;
    final myChallenges =
        store.challenges.where((c) => c.author == me.username).length;

    return Column(
      children: [
        ScreenHeader(
          title: 'Profile',
          subtitle: 'YOUR KICKOFF ACCOUNT',
          onMenu: onMenu,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 140),
            physics: const BouncingScrollPhysics(),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: C.cardGradient,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  children: [
                    InitialAvatar(name: me.displayName, size: 76, admin: me.isAdmin),
                    const SizedBox(height: 14),
                    Text(me.displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('@${me.username}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        me.isAdmin ? '⭐ ADMIN · THE HOST' : '⚽ COMMUNITY MEMBER',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6),
                      ),
                    ),
                    if (me.clubTeam.isNotEmpty || me.nationalTeam.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (me.clubTeam.isNotEmpty)
                            _supportChip(
                              child: ClubCrest(
                                  name: me.clubTeam,
                                  logoUrl: _clubLogo(me.clubTeam),
                                  size: 24),
                              label: me.clubTeam,
                            ),
                          if (me.clubTeam.isNotEmpty && me.nationalTeam.isNotEmpty)
                            const SizedBox(width: 10),
                          if (me.nationalTeam.isNotEmpty)
                            _supportChip(
                              child: _natFlag(me.nationalTeam),
                              label: me.nationalTeam,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Your activity',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: C.ink)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _stat('Questions', '$myQuestions', Icons.forum_outlined),
                  const SizedBox(width: 12),
                  _stat('On the show', '$mentioned', Icons.star_outline_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat('Suggestions', '$mySuggestions',
                      Icons.lightbulb_outline_rounded),
                  const SizedBox(width: 12),
                  _stat('Challenges', '$myChallenges',
                      Icons.emoji_events_outlined),
                ],
              ),
              const SizedBox(height: 22),
              SoftCard(
                onTap: () => _editSheet(context, me),
                child: Row(
                  children: const [
                    Icon(Icons.edit_outlined, color: C.violetMid),
                    SizedBox(width: 14),
                    Text('Edit profile',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: C.ink)),
                    Spacer(),
                    Icon(Icons.chevron_right_rounded, color: C.muted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SoftCard(
                onTap: onLogout,
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, color: C.live),
                    SizedBox(width: 14),
                    Text('Log out',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: C.live)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: C.violetMid, size: 24),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: C.ink)),
            Text(label,
                style: const TextStyle(fontSize: 12.5, color: C.muted)),
          ],
        ),
      ),
    );
  }

  // ── Support chips + logo lookups ───────────────────────────────────────
  static String? _clubLogo(String name) =>
      kClubs.where((c) => c.name == name).firstOrNull?.logoUrl;

  static Widget _natFlag(String name) {
    final n = kNationalTeams.where((t) => t.name == name).firstOrNull;
    return n == null
        ? const Icon(Icons.public_rounded, color: Colors.white, size: 22)
        : CountryFlag(flagUrl: n.flagUrl, size: 26);
  }

  Widget _supportChip({required Widget child, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _editSheet(BuildContext context, AppUser me) async {
    final firstCtrl = TextEditingController(text: me.firstName);
    final lastCtrl = TextEditingController(text: me.lastName);
    final phoneCtrl = TextEditingController(text: me.phone);
    var club = me.clubTeam;
    var national = me.nationalTeam;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                          color: C.chip,
                          borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Edit profile',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: C.ink)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppField(
                            controller: firstCtrl,
                            hint: 'First name',
                            icon: Icons.person_outline_rounded,
                            action: TextInputAction.next),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppField(
                            controller: lastCtrl,
                            hint: 'Last name',
                            icon: Icons.badge_outlined,
                            action: TextInputAction.next),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppField(
                      controller: phoneCtrl,
                      hint: 'Phone number',
                      icon: Icons.phone_outlined),
                  const SizedBox(height: 12),
                  _editPick(
                    icon: Icons.shield_outlined,
                    leading: club.isEmpty
                        ? null
                        : ClubCrest(
                            name: club, logoUrl: _clubLogo(club), size: 26),
                    label: club.isEmpty ? 'Club you support' : club,
                    placeholder: club.isEmpty,
                    onTap: () async {
                      final p = await pickClub(ctx, club.isEmpty ? null : club);
                      if (p != null) setSheet(() => club = p);
                    },
                  ),
                  const SizedBox(height: 12),
                  _editPick(
                    icon: Icons.public_rounded,
                    leading: national.isEmpty ? null : _natFlag(national),
                    label: national.isEmpty
                        ? 'National team you support'
                        : national,
                    placeholder: national.isEmpty,
                    onTap: () async {
                      final p = await pickNational(
                          ctx, national.isEmpty ? null : national);
                      if (p != null) setSheet(() => national = p);
                    },
                  ),
                  const SizedBox(height: 20),
                  PillButton(
                    label: 'Save changes',
                    icon: Icons.check_rounded,
                    onTap: () {
                      store.updateProfile(
                        firstName: firstCtrl.text.trim(),
                        lastName: lastCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        clubTeam: club,
                        nationalTeam: national,
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editPick({
    required IconData icon,
    required Widget? leading,
    required String label,
    required bool placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: C.field,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: leading ?? Icon(icon, color: C.violetMid, size: 21),
            ),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: placeholder ? C.muted : C.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.expand_more_rounded, color: C.muted, size: 22),
          ],
        ),
      ),
    );
  }
}
