import 'package:flutter/material.dart';

import '../services/connectivity.dart';
import '../theme.dart';

/// Full-screen gate shown when the app can't reach the backend — either on
/// launch (restoring a stay-logged-in session) or any time the service is
/// unreachable. The message adapts to [reason]: a VPN is the most common
/// culprit on phones, so we ask the user to turn it off first.
class ConnectionScreen extends StatelessWidget {
  final ConnReason reason;
  final Future<void> Function() onRetry;

  /// Optional secondary action (e.g. "Log in with a different account").
  final VoidCallback? onSecondary;
  final String? secondaryLabel;

  const ConnectionScreen({
    super.key,
    required this.reason,
    required this.onRetry,
    this.onSecondary,
    this.secondaryLabel,
  });

  ({IconData icon, String title, String body}) get _copy {
    switch (reason) {
      case ConnReason.vpn:
        return (
          icon: Icons.vpn_lock_rounded,
          title: "Can't reach Kickoff",
          body:
              "You're connected through a VPN. Kickoff works better without "
              "one — if you're having trouble connecting, try turning it off. "
              'You can keep it on and just try again.',
        );
      case ConnReason.offline:
        return (
          icon: Icons.wifi_off_rounded,
          title: 'No connection',
          body:
              'You appear to be offline. Check your internet connection and '
              'try again.',
        );
      case ConnReason.generic:
        return (
          icon: Icons.cloud_off_rounded,
          title: "Can't reach Kickoff",
          body:
              "We couldn't reach the server. Please check your connection and "
              'try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: C.pageGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: Icon(c.icon, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    c.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 30),
                  PillButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onTap: () => onRetry(),
                  ),
                  if (onSecondary != null) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(
                        secondaryLabel ?? 'Back',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
