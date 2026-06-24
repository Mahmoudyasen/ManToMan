import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Challenges thrown at the admin. The community writes + upvotes them; the
/// admin accepts or declines.
class ChallengesScreen extends StatelessWidget {
  final VoidCallback onMenu;
  const ChallengesScreen({super.key, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final admin = store.isAdmin;
    final items = [...store.challenges]..sort((a, b) {
        if (a.votes.length != b.votes.length) {
          return b.votes.length.compareTo(a.votes.length);
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return Stack(
      children: [
        Column(
          children: [
            ScreenHeader(
              title: 'Challenges',
              subtitle: 'DARE THE ADMIN',
              onMenu: onMenu,
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'No challenges yet',
                      message:
                          'Think the admin can\'t do it? Throw down a challenge.',
                      action: PillButton(
                        label: 'Write a challenge',
                        icon: Icons.add_rounded,
                        expand: false,
                        onTap: () => _add(context),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 6, 24, 140),
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ChallengeCard(item: items[i], admin: admin),
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 22,
          bottom: 104,
          child: ComposeFab(
            label: 'Challenge',
            icon: Icons.bolt_rounded,
            onTap: () => _add(context),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final res = await showComposer(
      context,
      heading: 'Challenge the admin',
      titleHint: 'Challenge title',
      bodyHint: 'Describe the challenge…',
      submitLabel: 'Throw it down',
    );
    if (res != null && res.$1.isNotEmpty) {
      store.addChallenge(res.$1, res.$2);
    }
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge item;
  final bool admin;
  const _ChallengeCard({required this.item, required this.admin});

  static const _statusMeta = {
    ChallengeStatus.open: ('OPEN', C.muted),
    ChallengeStatus.accepted: ('ACCEPTED', C.ok),
    ChallengeStatus.declined: ('DECLINED', C.live),
  };

  @override
  Widget build(BuildContext context) {
    final me = store.currentUser!.username;
    final voted = item.votes.contains(me);
    final meta = _statusMeta[item.status]!;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: C.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded, color: C.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: C.ink)),
              ),
              TagBadge(meta.$1, color: meta.$2),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.text,
              style: const TextStyle(
                  fontSize: 14.5, height: 1.45, color: C.ink)),
          const SizedBox(height: 8),
          Text('by @${item.author} · ${timeAgo(item.createdAt)}',
              style: const TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 14),
          Row(
            children: [
              VoteChip(
                count: item.votes.length,
                active: voted,
                onTap: () => store.toggleChallengeVote(item.id),
              ),
              const Spacer(),
              if (admin && item.status == ChallengeStatus.open) ...[
                _adminAction('Decline', C.live,
                    () => store.setChallengeStatus(item.id, ChallengeStatus.declined)),
                const SizedBox(width: 10),
                _adminAction('Accept', C.ok,
                    () => store.setChallengeStatus(item.id, ChallengeStatus.accepted)),
              ] else if (admin)
                GestureDetector(
                  onTap: () =>
                      store.setChallengeStatus(item.id, ChallengeStatus.open),
                  child: const Text('Reopen',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: C.violetMid)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adminAction(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
