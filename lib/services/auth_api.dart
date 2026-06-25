import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

/// Outcome of an auth call.
///
/// [networkProblem] is true when we couldn't get a real answer from the
/// service — the device is offline, the backend couldn't be reached, or the
/// server/database is down (5xx). In that case the UI shows a "check your
/// connection" popup instead of an inline credential error.
class AuthResult {
  final AppUser? user;
  final String? error;
  final bool networkProblem;
  const AuthResult({this.user, this.error, this.networkProblem = false});
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

  /// Re-validates a stay-logged-in session against the database by user [id].
  /// Returns the fresh user on success; [AuthResult.networkProblem] if the
  /// service can't be reached; or an [AuthResult.error] if the account is gone.
  Future<AuthResult> me(int id) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/auth/me?id=$id'))
          .timeout(const Duration(seconds: 25));
      final decoded = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
      if (res.statusCode >= 200 && res.statusCode < 300 && decoded['user'] != null) {
        final map = Map<String, dynamic>.from(decoded['user'] as Map);
        return AuthResult(user: AppUser.fromJson(map));
      }
      if (res.statusCode >= 500) {
        return const AuthResult(networkProblem: true);
      }
      // 4xx (e.g. 404) means the account no longer exists — session is stale.
      return AuthResult(error: decoded['error']?.toString() ?? 'Session expired.');
    } catch (_) {
      return const AuthResult(networkProblem: true);
    }
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
      // 5xx means the service or its database is unavailable — treat it as a
      // connection problem so the user is told to try again, not that their
      // credentials were wrong.
      if (res.statusCode >= 500) {
        return const AuthResult(networkProblem: true);
      }
      return AuthResult(
          error: decoded['error']?.toString() ?? 'Something went wrong.');
    } catch (_) {
      // Connection refused / timeout / DNS — the device is offline or the
      // backend is unreachable.
      return const AuthResult(networkProblem: true);
    }
  }
}
