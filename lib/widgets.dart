import 'package:flutter/material.dart';

import 'theme.dart';

/// Compact "time ago" label for feeds.
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
}

/// An upvote chip used by questions / suggestions / challenges.
class VoteChip extends StatelessWidget {
  final int count;
  final bool active;
  final VoidCallback onTap;
  const VoteChip(
      {super.key, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? C.violetMid : C.chip,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_upward_rounded,
                size: 15, color: active ? Colors.white : C.violetMid),
            const SizedBox(width: 5),
            Text('$count',
                style: TextStyle(
                    color: active ? Colors.white : C.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// Floating "compose" action button reused by community tabs.
class ComposeFab extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  const ComposeFab(
      {super.key,
      required this.onTap,
      this.icon = Icons.add_rounded,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: C.accentGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: C.accent.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// A bottom-sheet composer with one or two fields. Returns the entered
/// values (title, body) on submit, or null if dismissed.
Future<(String, String)?> showComposer(
  BuildContext context, {
  required String heading,
  String? titleHint,
  required String bodyHint,
  String submitLabel = 'Post',
}) async {
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                      color: C.chip, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 18),
              Text(heading,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: C.ink)),
              const SizedBox(height: 18),
              if (titleHint != null) ...[
                AppField(
                    controller: titleCtrl,
                    hint: titleHint,
                    icon: Icons.title_rounded,
                    action: TextInputAction.next),
                const SizedBox(height: 12),
              ],
              AppField(
                  controller: bodyCtrl,
                  hint: bodyHint,
                  icon: Icons.edit_outlined,
                  maxLines: 4),
              const SizedBox(height: 20),
              PillButton(
                label: submitLabel,
                icon: Icons.send_rounded,
                onTap: () {
                  if (bodyCtrl.text.trim().isEmpty) return;
                  if (titleHint != null && titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, (titleCtrl.text.trim(), bodyCtrl.text.trim()));
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
