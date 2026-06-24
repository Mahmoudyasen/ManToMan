import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

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
        AppUser(
          username: 'mantoman',
          displayName: 'Man to Man',
          password: '123',
          isAdmin: true,
          favouriteTeam: 'The Studio',
        ),
        AppUser(
          username: 'mahmoud',
          displayName: 'Mahmoud',
          password: '123',
          favouriteTeam: 'Liverpool',
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
  AppUser? login(String username, String password) {
    final u = users
        .where((u) =>
            u.username.toLowerCase() == username.trim().toLowerCase() &&
            u.password == password)
        .firstOrNull;
    if (u != null) {
      currentUser = u;
      _prefs.setString(_kSession, u.username);
      notifyListeners();
    }
    return u;
  }

  /// Returns null on success, or an error message.
  String? signUp(String username, String displayName, String password) {
    final uname = username.trim();
    if (uname.isEmpty || password.isEmpty) return 'Username and password are required.';
    if (users.any((u) => u.username.toLowerCase() == uname.toLowerCase())) {
      return 'That username is already taken.';
    }
    final user = AppUser(
      username: uname,
      displayName: displayName.trim().isEmpty ? uname : displayName.trim(),
      password: password,
    );
    users.add(user);
    _persist(_kUsers, users);
    currentUser = user;
    _prefs.setString(_kSession, user.username);
    notifyListeners();
    return null;
  }

  void logout() {
    currentUser = null;
    _prefs.remove(_kSession);
    notifyListeners();
  }

  void updateProfile({String? displayName, String? favouriteTeam, String? password}) {
    final me = currentUser;
    if (me == null) return;
    final updated = me.copyWith(
      displayName: displayName,
      favouriteTeam: favouriteTeam,
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
