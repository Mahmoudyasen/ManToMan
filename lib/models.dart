// ─────────────────────────────────────────────────────────────────
// Plain data models. Everything is JSON-serialisable so the store can
// persist it with shared_preferences (no backend in this prototype).
// ─────────────────────────────────────────────────────────────────

class AppUser {
  /// Login handle. Admin uses a real username ("mantoman"); community members
  /// are registered with their email as the username.
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime? dob;
  final String password;
  final bool isAdmin;
  final String clubTeam; // supported club
  final String nationalTeam; // supported national team

  const AppUser({
    required this.username,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.dob,
    required this.password,
    this.isAdmin = false,
    this.clubTeam = '',
    this.nationalTeam = '',
  });

  /// Friendly name derived from first + last, falling back to the username.
  String get displayName {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? username : n;
  }

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? dob,
    String? password,
    String? clubTeam,
    String? nationalTeam,
  }) =>
      AppUser(
        username: username,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        dob: dob ?? this.dob,
        password: password ?? this.password,
        isAdmin: isAdmin,
        clubTeam: clubTeam ?? this.clubTeam,
        nationalTeam: nationalTeam ?? this.nationalTeam,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'dob': dob?.toIso8601String(),
        'password': password,
        'isAdmin': isAdmin,
        'clubTeam': clubTeam,
        'nationalTeam': nationalTeam,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        username: j['username'] as String,
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        dob: (j['dob'] as String?) != null ? DateTime.tryParse(j['dob'] as String) : null,
        password: j['password'] as String,
        isAdmin: j['isAdmin'] as bool? ?? false,
        clubTeam: j['clubTeam'] as String? ?? '',
        nationalTeam: j['nationalTeam'] as String? ?? '',
      );
}

/// A community question asked while a round is open. Users hope it gets
/// "mentioned" by the admin on the podcast.
class Question {
  final String id;
  final String author;
  final String text;
  final DateTime createdAt;
  final List<String> votes; // usernames who upvoted
  final bool mentioned; // picked by the admin for the podcast

  Question({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    List<String>? votes,
    this.mentioned = false,
  }) : votes = votes ?? [];

  Question copyWith({List<String>? votes, bool? mentioned}) => Question(
        id: id,
        author: author,
        text: text,
        createdAt: createdAt,
        votes: votes ?? this.votes,
        mentioned: mentioned ?? this.mentioned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'votes': votes,
        'mentioned': mentioned,
      };

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        author: j['author'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        votes: (j['votes'] as List?)?.cast<String>() ?? [],
        mentioned: j['mentioned'] as bool? ?? false,
      );
}

/// A suggestion from the community. The admin can move it through stages.
enum SuggestionStatus { fresh, planned, done }

class Suggestion {
  final String id;
  final String author;
  final String text;
  final DateTime createdAt;
  final List<String> votes;
  final SuggestionStatus status;

  Suggestion({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    List<String>? votes,
    this.status = SuggestionStatus.fresh,
  }) : votes = votes ?? [];

  Suggestion copyWith({List<String>? votes, SuggestionStatus? status}) => Suggestion(
        id: id,
        author: author,
        text: text,
        createdAt: createdAt,
        votes: votes ?? this.votes,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'votes': votes,
        'status': status.name,
      };

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        id: j['id'] as String,
        author: j['author'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        votes: (j['votes'] as List?)?.cast<String>() ?? [],
        status: SuggestionStatus.values
            .firstWhere((s) => s.name == j['status'], orElse: () => SuggestionStatus.fresh),
      );
}

/// A challenge thrown at the admin. The admin can accept it.
enum ChallengeStatus { open, accepted, declined }

class Challenge {
  final String id;
  final String author;
  final String title;
  final String text;
  final DateTime createdAt;
  final List<String> votes;
  final ChallengeStatus status;

  Challenge({
    required this.id,
    required this.author,
    required this.title,
    required this.text,
    required this.createdAt,
    List<String>? votes,
    this.status = ChallengeStatus.open,
  }) : votes = votes ?? [];

  Challenge copyWith({List<String>? votes, ChallengeStatus? status}) => Challenge(
        id: id,
        author: author,
        title: title,
        text: text,
        createdAt: createdAt,
        votes: votes ?? this.votes,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'title': title,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'votes': votes,
        'status': status.name,
      };

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        author: j['author'] as String,
        title: j['title'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        votes: (j['votes'] as List?)?.cast<String>() ?? [],
        status: ChallengeStatus.values
            .firstWhere((s) => s.name == j['status'], orElse: () => ChallengeStatus.open),
      );
}

/// A podcast episode broadcast by the admin and played by the community.
class PodcastEpisode {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final DateTime createdAt;

  PodcastEpisode({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'audioUrl': audioUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PodcastEpisode.fromJson(Map<String, dynamic> j) => PodcastEpisode(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        audioUrl: j['audioUrl'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A fixture from API-Football (transient — not persisted).
class Fixture {
  final String home;
  final String away;
  final String homeLogo;
  final String awayLogo;
  final String league;
  final String leagueLogo;
  final String statusShort; // NS, 1H, HT, FT, LIVE...
  final String statusLong;
  final int? goalsHome;
  final int? goalsAway;
  final DateTime? kickoff;
  final int? elapsed;

  const Fixture({
    required this.home,
    required this.away,
    required this.homeLogo,
    required this.awayLogo,
    required this.league,
    required this.leagueLogo,
    required this.statusShort,
    required this.statusLong,
    this.goalsHome,
    this.goalsAway,
    this.kickoff,
    this.elapsed,
  });

  bool get isLive =>
      const {'1H', '2H', 'HT', 'ET', 'BT', 'P', 'LIVE'}.contains(statusShort);
  bool get isFinished => const {'FT', 'AET', 'PEN'}.contains(statusShort);
  bool get notStarted => statusShort == 'NS' || statusShort == 'TBD';

  factory Fixture.fromJson(Map<String, dynamic> j) {
    final fixture = j['fixture'] as Map<String, dynamic>;
    final teams = j['teams'] as Map<String, dynamic>;
    final league = j['league'] as Map<String, dynamic>;
    final goals = j['goals'] as Map<String, dynamic>;
    final status = fixture['status'] as Map<String, dynamic>;
    return Fixture(
      home: teams['home']?['name'] as String? ?? 'Home',
      away: teams['away']?['name'] as String? ?? 'Away',
      homeLogo: teams['home']?['logo'] as String? ?? '',
      awayLogo: teams['away']?['logo'] as String? ?? '',
      league: league['name'] as String? ?? '',
      leagueLogo: league['logo'] as String? ?? '',
      statusShort: status['short'] as String? ?? 'NS',
      statusLong: status['long'] as String? ?? '',
      goalsHome: goals['home'] as int?,
      goalsAway: goals['away'] as int?,
      elapsed: status['elapsed'] as int?,
      kickoff: fixture['date'] != null
          ? DateTime.tryParse(fixture['date'] as String)?.toLocal()
          : null,
    );
  }
}

/// A news article parsed from an RSS feed (transient).
class NewsItem {
  final String title;
  final String link;
  final String source;
  final String summary;
  final String imageUrl;
  final DateTime? published;

  const NewsItem({
    required this.title,
    required this.link,
    required this.source,
    required this.summary,
    required this.imageUrl,
    this.published,
  });
}
