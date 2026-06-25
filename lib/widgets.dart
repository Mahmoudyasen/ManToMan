import 'package:flutter/material.dart';

import 'data/teams.dart';
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

/// A club crest loaded from the network, with a colored monogram fallback
/// for clubs that have no hosted logo (or while loading / on error).
class ClubCrest extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final double size;
  const ClubCrest({super.key, required this.name, this.logoUrl, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final fallback = _Monogram(name: name, size: size);
    if (logoUrl == null || logoUrl!.isEmpty) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        logoUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

/// A country flag loaded from the network, rounded, with a globe fallback.
class CountryFlag extends StatelessWidget {
  final String flagUrl;
  final double size;
  const CountryFlag({super.key, required this.flagUrl, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.network(
        flagUrl,
        width: size,
        height: size * 0.7,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size * 0.7,
          color: C.chip,
          child: const Icon(Icons.flag_outlined, color: C.muted, size: 16),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  final String name;
  final double size;
  const _Monogram({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, gradient: C.cardGradient),
      alignment: Alignment.center,
      child: Text(letter,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800)),
    );
  }
}

// ── Team / national-team pickers (shared by sign-up and profile edit) ───────

/// Bottom-sheet picker for the supported club. Returns the chosen name or null.
Future<String?> pickClub(BuildContext context, String? current) {
  return _showPickerSheet<Club>(
    context: context,
    title: 'Choose your club',
    items: kClubs,
    nameOf: (c) => c.name,
    selected: current,
    leadingOf: (c) => ClubCrest(name: c.name, logoUrl: c.logoUrl, size: 36),
  );
}

/// Bottom-sheet picker for the supported national team.
Future<String?> pickNational(BuildContext context, String? current) {
  return _showPickerSheet<NationalTeam>(
    context: context,
    title: 'Choose your national team',
    items: kNationalTeams,
    nameOf: (n) => n.name,
    selected: current,
    leadingOf: (n) => CountryFlag(flagUrl: n.flagUrl, size: 40),
  );
}

/// Generic searchable bottom-sheet picker that renders a leading logo/flag.
Future<String?> _showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) nameOf,
  required Widget Function(T) leadingOf,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      var query = '';
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = items
              .where((e) => nameOf(e).toLowerCase().contains(query.toLowerCase()))
              .toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.72,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                        color: C.chip, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(height: 16),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: C.ink)),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setSheet(() => query = v),
                    style: const TextStyle(
                        color: C.ink, fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: const TextStyle(
                          color: C.muted, fontWeight: FontWeight.w500),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: C.violetMid, size: 21),
                      filled: true,
                      fillColor: C.field,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF0ECF9)),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        final name = nameOf(item);
                        final isSel = name == selected;
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          leading: SizedBox(
                              width: 44, child: Center(child: leadingOf(item))),
                          title: Text(name,
                              style: TextStyle(
                                  color: C.ink,
                                  fontSize: 15.5,
                                  fontWeight: isSel
                                      ? FontWeight.w800
                                      : FontWeight.w600)),
                          trailing: isSel
                              ? const Icon(Icons.check_circle_rounded,
                                  color: C.violetMid, size: 22)
                              : null,
                          onTap: () => Navigator.pop(ctx, name),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
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
