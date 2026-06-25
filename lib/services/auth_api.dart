import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

/// Outcome of an auth call. [reachable] is false when the backend couldn't be
/// contacted at all, which lets the store fall back to local accounts.
class AuthResult {
  final AppUser? user;
  final String? error;
  final bool reachable;
  const AuthResult({this.user, this.error, this.reachable = true});
}

/// Thin HTTP client for the Kickoff auth backend (see `backend/app.py`).
class AuthApi {
  AuthApi._();
  static final AuthApi instance = AuthApi._();

  /// Base URL. Override at build time with
  /// `--dart-define=KICKOFF_API=http://192.168.1.5:8000` (e.g. a phone on the
  /// same Wi-Fi). Defaults handle the common dev targets automatically.
  static String get baseUrl {
    const override = String.fromEnvironment('KICKOFF_API');
    if (override.isNotEmpty) return override;
    // Android emulators reach the host machine via 10.0.2.2, not localhost.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  Future<AuthResult> login(String identifier, String password) async {
    return _post('/auth/login',
        {'identifier': identifier, 'password': password}, password);
  }

  Future<AuthResult> register(Map<String, dynamic> payload, String password) async {
    return _post('/auth/register', payload, password);
  }

  Future<AuthResult> _post(
      String path, Map<String, dynamic> body, String password) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
      final decoded = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (res.statusCode >= 200 && res.statusCode < 300 && decoded['user'] != null) {
        final map = Map<String, dynamic>.from(decoded['user'] as Map);
        map['password'] = password; // backend never returns it; we know it
        return AuthResult(user: AppUser.fromJson(map));
      }
      return AuthResult(
          error: decoded['error']?.toString() ?? 'Something went wrong.');
    } catch (_) {
      // Connection refused / timeout / DNS — let the caller fall back.
      return const AuthResult(reachable: false);
    }
  }
}
