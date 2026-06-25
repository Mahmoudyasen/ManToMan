import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/teams.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Login / sign-up gate shown before the app shell. Matches the violet
/// gradient identity of the home design.
///
/// Login is unified — the same form for everyone; admin rights come from the
/// account's stored flag (no separate admin login). Sign-up always creates a
/// community member (you can't register as an admin) and collects name, email,
/// phone, date of birth, and the club + national team you support.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  // Login
  final _identifier = TextEditingController();

  // Sign-up
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _dob;
  String? _club;
  String? _national;

  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = _signup
        ? await store.signUp(
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            phone: _phone.text,
            dob: _dob,
            clubTeam: _club ?? '',
            nationalTeam: _national ?? '',
            password: _password.text,
          )
        : await store.login(_identifier.text, _password.text);
    // On success the store flips currentUser and this screen is replaced, so
    // only touch state if we're still mounted and stayed on this screen.
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
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
                  if (!_signup) _demoHint(),
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
          if (_signup) ..._signupFields() else ..._loginFields(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: C.live, size: 18),
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
            label: _busy
                ? 'Please wait…'
                : (_signup ? 'Create account' : 'Log in'),
            icon: _busy
                ? null
                : (_signup
                    ? Icons.person_add_alt_1_rounded
                    : Icons.login_rounded),
            onTap: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }

  List<Widget> _loginFields() => [
        AppField(
          controller: _identifier,
          hint: 'Email or username',
          icon: Icons.alternate_email_rounded,
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _passwordField(),
      ];

  List<Widget> _signupFields() => [
        Row(
          children: [
            Expanded(
              child: AppField(
                controller: _firstName,
                hint: 'First name',
                icon: Icons.person_outline_rounded,
                action: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppField(
                controller: _lastName,
                hint: 'Last name',
                icon: Icons.badge_outlined,
                action: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppField(
          controller: _email,
          hint: 'Email',
          icon: Icons.mail_outline_rounded,
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        AppField(
          controller: _phone,
          hint: 'Phone number',
          icon: Icons.phone_outlined,
          action: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _dobField(),
        const SizedBox(height: 14),
        _clubField(),
        const SizedBox(height: 14),
        _nationalField(),
        const SizedBox(height: 14),
        _passwordField(),
      ];

  Widget _passwordField() {
    return TextField(
      controller: _password,
      obscureText: _obscure,
      onSubmitted: (_) => _submit(),
      style:
          const TextStyle(color: C.ink, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle:
            const TextStyle(color: C.muted, fontWeight: FontWeight.w500),
        prefixIcon:
            const Icon(Icons.lock_outline_rounded, color: C.violetMid, size: 21),
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
    );
  }

  Widget _dobField() {
    final label = _dob == null
        ? 'Date of birth'
        : DateFormat('d MMMM yyyy').format(_dob!);
    return _SelectorTile(
      icon: Icons.cake_outlined,
      selected: _dob != null,
      child: Text(label,
          style: TextStyle(
              color: _dob == null ? C.muted : C.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
          firstDate: DateTime(1920),
          lastDate: now,
          helpText: 'Select your date of birth',
        );
        if (picked != null) setState(() => _dob = picked);
      },
    );
  }

  Widget _clubField() {
    final club = _club == null
        ? null
        : kClubs.firstWhere((c) => c.name == _club,
            orElse: () => Club(_club!, null));
    return _SelectorTile(
      icon: Icons.shield_outlined,
      selected: _club != null,
      leading: club == null
          ? null
          : ClubCrest(name: club.name, logoUrl: club.logoUrl, size: 28),
      child: Text(_club ?? 'Club you support',
          style: TextStyle(
              color: _club == null ? C.muted : C.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final picked = await pickClub(context, _club);
        if (picked != null) setState(() => _club = picked);
      },
    );
  }

  Widget _nationalField() {
    final nat = _national == null
        ? null
        : kNationalTeams.where((n) => n.name == _national).firstOrNull;
    return _SelectorTile(
      icon: Icons.public_rounded,
      selected: _national != null,
      leading: nat == null ? null : CountryFlag(flagUrl: nat.flagUrl, size: 30),
      child: Text(_national ?? 'National team you support',
          style: TextStyle(
              color: _national == null ? C.muted : C.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final picked = await pickNational(context, _national);
        if (picked != null) setState(() => _national = picked);
      },
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

/// A tappable field that looks like [AppField] but shows a selected value
/// (date / club / national team) with an optional leading logo or flag.
class _SelectorTile extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;
  const _SelectorTile({
    required this.icon,
    required this.child,
    required this.onTap,
    this.leading,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: C.field,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: C.violetMid.withValues(alpha: 0.4), width: 1.4)
              : null,
        ),
        child: Row(
          children: [
            if (leading != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: leading,
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(icon, color: C.violetMid, size: 21),
              ),
            Expanded(child: child),
            const Icon(Icons.expand_more_rounded, color: C.muted, size: 22),
          ],
        ),
      ),
    );
  }
}
