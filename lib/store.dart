import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services/auth_api.dart';

/// Result of an auth attempt. Exactly one state is true:
/// [success] — logged in; [networkProblem] — couldn't reach the service (show
/// the "check your connection" popup); otherwise [error] holds an inline
/// message (wrong credentials, validation, etc.).
class AuthOutcome {
  final bool success;
  final bool networkProblem;
  final String? error;
  const AuthOutcome.ok()
      : success = true,
        networkProblem = false,
        error = null;
  const AuthOutcome.network()
      : success = false,
        networkProblem = true,
        error = null;
  const AuthOutcome.failure(this.error)
      : success = false,
        networkProblem = false;
}

/// Central app state + persistence. A single instance ([store]) is shared
/// through the widget tree via [ListenableBuilder].
///
/// Auth (login/sign-up) is fully online: it always goes through the backend
/// API and the Azure SQL database — accounts are never cached or verified on
/// the device, so a fresh online login is required each launch. The community
/// content collections below are still cached in shared_preferences.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  late SharedPreferences _prefs;
  bool _ready = false;
  bool get ready => _ready;

  // ── Collections ──────────────────────────────────────────────
  final List<Question> questions = [];
  final List<Suggestion> suggestions = [];
  final List<Challenge> challenges = [];
  final List<PodcastEpisode> podcasts = [];

  bool questionsOpen = false;
  String questionTopic = '';

  AppUser? currentUser;
  bool get isAdmin => currentUser?.isAdmin ?? false;

  // ── Keys ─────────────────────────────────────────────────────
  static const _kQuestions = 'questions';
  static const _kSuggestions = 'suggestions';
  static const _kChallenges = 'challenges';
  static const _kPodcasts = 'podcasts';
  static const _kQOpen = 'questionsOpen';
  static const _kQTopic = 'questionTopic';
  // Stay-logged-in: only the account's database id is stored — never the
  // password. On launch it's re-validated online via the backend.
  static const _kSessionId = 'sessionId';

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
    // The session is not restored here: a saved session holds only the user id
    // and must be re-validated online (see [restoreSession]).
  }

  void _seedIfNeeded() {
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

  // ── Auth (online-only) ───────────────────────────────────────
  /// Unified login against the backend API + Azure SQL (see `backend/app.py`).
  /// [identifier] matches either the username (e.g. the admin's "mantoman") or
  /// a member's email; admin rights come from the stored `is_admin` flag — there
  /// is no separate admin login.
  ///
  /// There is no offline fallback: if the service can't be reached the returned
  /// outcome has [AuthOutcome.networkProblem] set so the UI can prompt the user
  /// to check their connection.
  Future<AuthOutcome> login(String identifier, String password,
      {bool remember = true}) async {
    final res = await AuthApi.instance.login(identifier, password);
    if (res.user != null) {
      _startSession(res.user!, remember: remember);
      return const AuthOutcome.ok();
    }
    if (res.networkProblem) return const AuthOutcome.network();
    return AuthOutcome.failure(res.error ?? 'Wrong email/username or password.');
  }

  /// Registers a community member via the backend. Never creates an admin.
  Future<AuthOutcome> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required DateTime? dob,
    required String clubTeam,
    required String nationalTeam,
    required String password,
    bool remember = true,
  }) async {
    final mail = email.trim();
    // Validate up front so we fail fast with a friendly message (the backend
    // re-validates too).
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      return const AuthOutcome.failure('Please enter your first and last name.');
    }
    if (!_looksLikeEmail(mail)) {
      return const AuthOutcome.failure('Please enter a valid email address.');
    }
    if (phone.trim().isEmpty) {
      return const AuthOutcome.failure('Please enter your phone number.');
    }
    if (dob == null) {
      return const AuthOutcome.failure('Please pick your date of birth.');
    }
    if (clubTeam.isEmpty) {
      return const AuthOutcome.failure('Please choose the club you support.');
    }
    if (nationalTeam.isEmpty) {
      return const AuthOutcome.failure(
          'Please choose the national team you support.');
    }
    if (password.length < 3) {
      return const AuthOutcome.failure('Password must be at least 3 characters.');
    }

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
      _startSession(res.user!, remember: remember);
      return const AuthOutcome.ok();
    }
    if (res.networkProblem) return const AuthOutcome.network();
    return AuthOutcome.failure(res.error ?? 'Could not create your account.');
  }

  /// True when a stay-logged-in session id is stored and should be restored
  /// (online) on launch.
  bool get hasSavedSession => _prefs.getInt(_kSessionId) != null;

  /// Re-validates the saved session against the database. Returns
  /// [AuthOutcome.ok] (and sets [currentUser]) when the account still exists,
  /// [AuthOutcome.network] when the service can't be reached, or
  /// [AuthOutcome.failure] when the session is stale (the saved id is cleared).
  Future<AuthOutcome> restoreSession() async {
    final id = _prefs.getInt(_kSessionId);
    if (id == null) return const AuthOutcome.failure('No session.');
    final res = await AuthApi.instance.me(id);
    if (res.user != null) {
      currentUser = res.user;
      notifyListeners();
      return const AuthOutcome.ok();
    }
    if (res.networkProblem) return const AuthOutcome.network();
    // Account no longer exists — drop the stale session.
    await _prefs.remove(_kSessionId);
    return AuthOutcome.failure(res.error ?? 'Session expired.');
  }

  /// Sets the current user for this session. When [remember] is true the
  /// account's database id is persisted (stay logged in across launches) —
  /// never the password. When false, the login lives only in memory for this
  /// run and any previously saved session is cleared.
  void _startSession(AppUser user, {bool remember = true}) {
    currentUser = user;
    if (remember && user.id != null) {
      _prefs.setInt(_kSessionId, user.id!);
    } else {
      _prefs.remove(_kSessionId);
    }
    notifyListeners();
  }

  bool _looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  void logout() {
    currentUser = null;
    _prefs.remove(_kSessionId);
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
    currentUser = me.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      clubTeam: clubTeam,
      nationalTeam: nationalTeam,
      password: password,
    );
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
