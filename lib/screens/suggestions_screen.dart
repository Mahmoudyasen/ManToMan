import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Community suggestions board. Anyone can suggest + upvote; the admin moves
/// items through Fresh → Planned → Done.
class SuggestionsScreen extends StatelessWidget {
  final VoidCallback onMenu;
  const SuggestionsScreen({super.key, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final admin = store.isAdmin;
    final items = [...store.suggestions]..sort((a, b) {
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
              title: 'Suggestions',
              subtitle: 'SHAPE THE COMMUNITY',
              onMenu: onMenu,
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                      icon: Icons.lightbulb_outline_rounded,
                      title: 'No suggestions yet',
                      message:
                          'Got an idea for the show or the app? Be the first to suggest it.',
                      action: PillButton(
                        label: 'Add a suggestion',
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
                        child: _SuggestionCard(item: items[i], admin: admin),
                      ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 22,
          bottom: 104,
          child: ComposeFab(
            label: 'Suggest',
            icon: Icons.lightbulb_outline_rounded,
            onTap: () => _add(context),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final res = await showComposer(
      context,
      heading: 'Suggest something',
      bodyHint: 'Your idea for the show, app, or community…',
      submitLabel: 'Post suggestion',
    );
    if (res != null) store.addSuggestion(res.$2);
  }
}

class _SuggestionCard extends StatelessWidget {
  final Suggestion item;
  final bool admin;
  const _SuggestionCard({required this.item, required this.admin});

  static const _statusMeta = {
    SuggestionStatus.fresh: ('FRESH', C.violetMid),
    SuggestionStatus.planned: ('PLANNED', C.accent),
    SuggestionStatus.done: ('DONE', C.ok),
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
              InitialAvatar(name: item.author, size: 32),
              const SizedBox(width: 10),
              Text('@${item.author}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: C.ink)),
              const SizedBox(width: 8),
              Text(timeAgo(item.createdAt),
                  style: const TextStyle(fontSize: 11.5, color: C.muted)),
              const Spacer(),
              TagBadge(meta.$1, color: meta.$2),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.text,
              style: const TextStyle(
                  fontSize: 15, height: 1.4, color: C.ink, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          Row(
            children: [
              VoteChip(
                count: item.votes.length,
                active: voted,
                onTap: () => store.toggleSuggestionVote(item.id),
              ),
              const Spacer(),
              if (admin) _adminMenu(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adminMenu() {
    return PopupMenuButton<SuggestionStatus>(
      onSelected: (s) => store.setSuggestionStatus(item.id, s),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => const [
        PopupMenuItem(value: SuggestionStatus.fresh, child: Text('Mark Fresh')),
        PopupMenuItem(
            value: SuggestionStatus.planned, child: Text('Mark Planned')),
        PopupMenuItem(value: SuggestionStatus.done, child: Text('Mark Done')),
      ],
      child: Row(
        children: const [
          Icon(Icons.tune_rounded, size: 18, color: C.violetMid),
          SizedBox(width: 5),
          Text('Set status',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: C.violetMid)),
        ],
      ),
    );
  }
}
