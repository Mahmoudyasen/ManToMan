import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';

/// Login / sign-up gate shown before the app shell. Matches the violet
/// gradient identity of the home design.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = false;
  bool _obscure = true;
  String? _error;

  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);
    if (_signup) {
      final err = store.signUp(
          _username.text, _displayName.text, _password.text);
      if (err != null) setState(() => _error = err);
    } else {
      final user = store.login(_username.text, _password.text);
      if (user == null) {
        setState(() => _error = 'Wrong username or password.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: C.pageGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _logo(),
                  const SizedBox(height: 26),
                  _card(),
                  const SizedBox(height: 22),
                  _demoHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: C.accentGradient,
            boxShadow: [
              BoxShadow(
                color: C.accent.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.sports_soccer, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 16),
        const Text('Kickoff',
            style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text('The community + podcast hub for football',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toggle(),
          const SizedBox(height: 22),
          AppField(
            controller: _username,
            hint: 'Username',
            icon: Icons.alternate_email_rounded,
            action: TextInputAction.next,
          ),
          if (_signup) ...[
            const SizedBox(height: 14),
            AppField(
              controller: _displayName,
              hint: 'Display name',
              icon: Icons.badge_outlined,
              action: TextInputAction.next,
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
                color: C.ink, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle:
                  const TextStyle(color: C.muted, fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: C.violetMid, size: 21),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: C.muted,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              filled: true,
              fillColor: C.field,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: C.violetMid, width: 1.5),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: C.live, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: C.live,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          PillButton(
            label: _signup ? 'Create account' : 'Log in',
            icon: _signup
                ? Icons.person_add_alt_1_rounded
                : Icons.login_rounded,
            onTap: _submit,
          ),
        ],
      ),
    );
  }

  Widget _toggle() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: C.chip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _toggleTab('Log in', !_signup, () => setState(() => _signup = false)),
          _toggleTab('Sign up', _signup, () => setState(() => _signup = true)),
        ],
      ),
    );
  }

  Widget _toggleTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _error = null);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: C.violetMid.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: active ? C.violetMid : C.muted,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _demoHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('Demo accounts',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
          const SizedBox(height: 8),
          _hintRow('Admin', 'mantoman', '123'),
          const SizedBox(height: 4),
          _hintRow('User', 'mahmoud', '123'),
        ],
      ),
    );
  }

  Widget _hintRow(String role, String user, String pass) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$role · ',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
        Text('$user / $pass',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
