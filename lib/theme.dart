import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────
/// Palette — the violet identity from the original design, extended.
/// ─────────────────────────────────────────────────────────────────
class C {
  static const violet = Color(0xFF7C3AED);
  static const violetMid = Color(0xFF6D28D9);
  static const violetDark = Color(0xFF4C1D95);
  static const violetDeep = Color(0xFF3B0764);
  static const accent = Color(0xFFF97316); // central live button / badges
  static const accentLight = Color(0xFFFB923C);
  static const live = Color(0xFFEF4444);
  static const ink = Color(0xFF211A37);
  static const muted = Color(0xFF908AA6);
  static const chip = Color(0xFFF1ECFB);
  static const field = Color(0xFFF6F3FD);
  static const ok = Color(0xFF22C55E);

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [violet, violetMid, violetDeep],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, violetDark],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentLight, accent],
  );
}

/// Soft white card used across every feature screen.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C1D95).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}

/// Rounded gradient pill — the primary action button.
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expand;
  final Gradient gradient;
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.expand = true,
    this.gradient = C.accentGradient,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: C.accent.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header shown at the top of every feature screen.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onMenu;
  final Widget? trailing;
  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onMenu,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onMenu,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: C.chip, shape: BoxShape.circle),
              child: const Icon(Icons.menu_rounded, color: C.ink, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: C.muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800, color: C.ink)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small colored status / role badge.
class TagBadge extends StatelessWidget {
  final String text;
  final Color color;
  const TagBadge(this.text, {super.key, this.color = C.violetMid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }
}

/// Friendly empty / error placeholder.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: C.chip, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: C.violetMid),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: C.ink)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: C.muted, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// A circle avatar with the user's initial.
class InitialAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool admin;
  const InitialAvatar({super.key, required this.name, this.size = 44, this.admin = false});

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: admin ? C.accentGradient : C.cardGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
            color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Styled text field used by auth + composer sheets.
class AppField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final int maxLines;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  const AppField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.maxLines = 1,
    this.action,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      textInputAction: action,
      onSubmitted: onSubmitted,
      style: const TextStyle(
          color: C.ink, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: C.muted, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: C.violetMid, size: 21),
        filled: true,
        fillColor: C.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.violetMid, width: 1.5),
        ),
      ),
    );
  }
}
