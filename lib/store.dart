import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services/auth_api.dart';

/// Central app state + persistence. A single instance ([store]) is shared
/// through the widget tree via [ListenableBuilder]. Everything lives in
/// shared_preferences so it survives restarts without a backend.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  late SharedPreferences _prefs;
  bool _ready = false;
  bool get ready => _ready;

  // ── Collections ──────────────────────────────────────────────
  final List<AppUser> users = [];
  final List<Question> questions = [];
  final List<Suggestion> suggestions = [];
  final List<Challenge> challenges = [];
  final List<PodcastEpisode> podcasts = [];

  bool questionsOpen = false;
  String questionTopic = '';

  AppUser? currentUser;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  // ── Keys ─────────────────────────────────────────────────────
  static const _kUsers = 'users';
  static const _kQuestions = 'questions';
  static const _kSuggestions = 'suggestions';
  static const _kChallenges = 'challenges';
  static const _kPodcasts = 'podcasts';
  static const _kQOpen = 'questionsOpen';
  static const _kQTopic = 'questionTopic';
  static const _kSession = 'session';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
    _seedIfNeeded();
    _ready = true;
    notifyListeners();
  }

  // ── Loading / seeding ────────────────────────────────────────
  List<Map<String, dynamic>> _decodeList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  void _load() {
    users
      ..clear()
      ..addAll(_decodeList(_kUsers).map(AppUser.fromJson));
    questions
      ..clear()
      ..addAll(_decodeList(_kQuestions).map(Question.fromJson));
    suggestions
      ..clear()
      ..addAll(_decodeList(_kSuggestions).map(Suggestion.fromJson));
    challenges
      ..clear()
      ..addAll(_decodeList(_kChallenges).map(Challenge.fromJson));
    podcasts
      ..clear()
      ..addAll(_decodeList(_kPodcasts).map(PodcastEpisode.fromJson));
    questionsOpen = _prefs.getBool(_kQOpen) ?? false;
    questionTopic = _prefs.getString(_kQTopic) ?? '';

    final session = _prefs.getString(_kSession);
    if (session != null) {
      currentUser = users.where((u) => u.username == session).firstOrNull;
    }
  }

  void _seedIfNeeded() {
    if (users.isEmpty) {
      users.addAll(const [
        // The host. There is no admin sign-up — this seeded account (and the
        // matching row in db/schema.sql) is the only way in as an admin.
        AppUser(
          username: 'mantoman',
          firstName: 'Man to Man',
          email: 'admin@mantoman.app',
          password: '123',
          isAdmin: true,
        ),
        AppUser(
          username: 'mahmoud',
          firstName: 'Mahmoud',
          email: 'mahmoud@example.com',
          password: '123',
          clubTeam: 'Liverpool',
          nationalTeam: 'Egypt',
        ),
      ]);
      _persist(_kUsers, users);
    }
    if (podcasts.isEmpty) {
      podcasts.add(PodcastEpisode(
        id: _id(),
        title: 'Episode 1 — Welcome to Kickoff',
        description:
            'The first show. We open the floor to your questions and break down the weekend\'s biggest talking points.',
        // A small public-domain audio clip so playback works out of the box.
        audioUrl:
            'https://archive.org/download/testmp3testfile/mpthreetest.mp3',
        createdAt: DateTime.now(),
      ));
      _persist(_kPodcasts, podcasts);
    }
  }

  // ── Persistence helpers ──────────────────────────────────────
  void _persist(String key, List<dynamic> list) =>
      _prefs.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  // ── Auth ─────────────────────────────────────────────────────
  /// Unified login against the backend API (see `backend/app.py`).
  /// [identifier] matches either the username (e.g. the admin's "mantoman") or
  /// a member's email; admin rights come from the stored `is_admin` flag — there
  /// is no separate admin login. Returns null on success or an error message.
  ///
  /// If the backend is unreachable, falls back to locally-cached accounts (the
  /// seeded demo accounts and anyone who registered on this device) so the app
  /// still works offline.
  Future<String?> login(String identifier, String password) async {
    final res = await AuthApi.instance.login(identifier, password);
    if (res.user != null) {
      _startSession(res.user!);
      return null;
    }
    if (res.reachable) {
      return res.error ?? 'Wrong email/username or password.';
    }
    // Offline fallback.
    final id = identifier.trim().toLowerCase();
    final local = users
        .where((u) =>
            (u.username.toLowerCase() == id || u.email.toLowerCase() == id) &&
            u.password == password)
        .firstOrNull;
    if (local != null) {
      _startSession(local);
      return null;
    }
    return 'Wrong email/username or password.';
  }

  /// Registers a community member via the backend. Never creates an admin.
  /// Returns null on success, or a human-readable error message.
  Future<String?> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required DateTime? dob,
    required String clubTeam,
    required String nationalTeam,
    required String password,
  }) async {
    final mail = email.trim();
    // Validate up front so we fail fast with a friendly message (the backend
    // re-validates too).
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      return 'Please enter your first and last name.';
    }
    if (!_looksLikeEmail(mail)) return 'Please enter a valid email address.';
    if (phone.trim().isEmpty) return 'Please enter your phone number.';
    if (dob == null) return 'Please pick your date of birth.';
    if (clubTeam.isEmpty) return 'Please choose the club you support.';
    if (nationalTeam.isEmpty) return 'Please choose the national team you support.';
    if (password.length < 3) return 'Password must be at least 3 characters.';

    final payload = {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': mail,
      'phone': phone.trim(),
      'dob': dob.toIso8601String(),
      'clubTeam': clubTeam,
      'nationalTeam': nationalTeam,
      'password': password,
    };
    final res = await AuthApi.instance.register(payload, password);
    if (res.user != null) {
      _startSession(res.user!);
      return null;
    }
    if (res.reachable) {
      return res.error ?? 'Could not create your account.';
    }
    // Offline fallback — create the account locally on this device.
    if (users.any((u) =>
        u.email.toLowerCase() == mail.toLowerCase() ||
        u.username.toLowerCase() == mail.toLowerCase())) {
      return 'An account with that email already exists.';
    }
    _startSession(AppUser(
      username: mail,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: mail,
      phone: phone.trim(),
      dob: dob,
      password: password,
      clubTeam: clubTeam,
      nationalTeam: nationalTeam,
    ));
    return null;
  }

  /// Sets the current user, caches them locally (so session restore + offline
  /// login keep working), and persists the session.
  void _startSession(AppUser user) {
    final i = users.indexWhere(
        (u) => u.username.toLowerCase() == user.username.toLowerCase());
    if (i == -1) {
      users.add(user);
    } else {
      users[i] = user;
    }
    _persist(_kUsers, users);
    currentUser = user;
    _prefs.setString(_kSession, user.username);
    notifyListeners();
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  void logout() {
    currentUser = null;
    _prefs.remove(_kSession);
    notifyListeners();
  }

  void updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? clubTeam,
    String? nationalTeam,
    String? password,
  }) {
    final me = currentUser;
    if (me == null) return;
    final updated = me.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      clubTeam: clubTeam,
      nationalTeam: nationalTeam,
      password: password,
    );
    final i = users.indexWhere((u) => u.username == me.username);
    if (i != -1) users[i] = updated;
    currentUser = updated;
    _persist(_kUsers, users);
    notifyListeners();
  }

  // ── Questions ────────────────────────────────────────────────
  void setQuestionsOpen(bool open, {String? topic}) {
    questionsOpen = open;
    if (topic != null) questionTopic = topic;
    _prefs.setBool(_kQOpen, open);
    _prefs.setString(_kQTopic, questionTopic);
    notifyListeners();
  }

  void addQuestion(String text) {
    questions.insert(
      0,
      Question(
        id: _id(),
        author: currentUser!.username,
        text: text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    _persist(_kQuestions, questions);
    notifyListeners();
  }

  void toggleQuestionVote(String id) {
    final i = questions.indexWhere((q) => q.id == id);
    if (i == -1) return;
    final votes = [...questions[i].votes];
    final me = currentUser!.username;
    votes.contains(me) ? votes.remove(me) : votes.add(me);
    questions[i] = questions[i].copyWith(votes: votes);
    _persist(_kQuestions, questions);
    notifyListeners();
  }

  void toggleMentioned(String id) {
    final i = questions.indexWhere((q) => q.id == id);
    if (i == -1) return;
    questions[i] = questions[i].copyWith(mentioned: !questions[i].mentioned);
    _persist(_kQuestions, questions);
    notifyListeners();
  }

  // ── Suggestions ──────────────────────────────────────────────
  void addSuggestion(String text) {
    suggestions.insert(
      0,
      Suggestion(
        id: _id(),
        author: currentUser!.username,
        text: text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    _persist(_kSuggestions, suggestions);
    notifyListeners();
  }

  void toggleSuggestionVote(String id) {
    final i = suggestions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    final votes = [...suggestions[i].votes];
    final me = currentUser!.username;
    votes.contains(me) ? votes.remove(me) : votes.add(me);
    suggestions[i] = suggestions[i].copyWith(votes: votes);
    _persist(_kSuggestions, suggestions);
    notifyListeners();
  }

  void setSuggestionStatus(String id, SuggestionStatus status) {
    final i = suggestions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    suggestions[i] = suggestions[i].copyWith(status: status);
    _persist(_kSuggestions, suggestions);
    notifyListeners();
  }

  // ── Challenges ───────────────────────────────────────────────
  void addChallenge(String title, String text) {
    challenges.insert(
      0,
      Challenge(
        id: _id(),
        author: currentUser!.username,
        title: title.trim(),
        text: text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    _persist(_kChallenges, challenges);
    notifyListeners();
  }

  void toggleChallengeVote(String id) {
    final i = challenges.indexWhere((c) => c.id == id);
    if (i == -1) return;
    final votes = [...challenges[i].votes];
    final me = currentUser!.username;
    votes.contains(me) ? votes.remove(me) : votes.add(me);
    challenges[i] = challenges[i].copyWith(votes: votes);
    _persist(_kChallenges, challenges);
    notifyListeners();
  }

  void setChallengeStatus(String id, ChallengeStatus status) {
    final i = challenges.indexWhere((c) => c.id == id);
    if (i == -1) return;
    challenges[i] = challenges[i].copyWith(status: status);
    _persist(_kChallenges, challenges);
    notifyListeners();
  }

  // ── Podcast ──────────────────────────────────────────────────
  void addEpisode(String title, String description, String audioUrl) {
    podcasts.insert(
      0,
      PodcastEpisode(
        id: _id(),
        title: title.trim(),
        description: description.trim(),
        audioUrl: audioUrl.trim(),
        createdAt: DateTime.now(),
      ),
    );
    _persist(_kPodcasts, podcasts);
    notifyListeners();
  }

  void removeEpisode(String id) {
    podcasts.removeWhere((e) => e.id == id);
    _persist(_kPodcasts, podcasts);
    notifyListeners();
  }
}

final store = AppStore.instance;
