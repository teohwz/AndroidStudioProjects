/// Represents one player's entry in the leaderboard
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int totalPoints;
  final int gamesPlayed;
  final int rank;
  final Map<String, int> gameBreakdown; // e.g. {'quiz': 80, 'puzzle': 40}
  final DateTime? lastPlayedAt;

  LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.totalPoints,
    required this.gamesPlayed,
    this.rank = 0,
    this.gameBreakdown = const {},
    this.lastPlayedAt,
  });

  /// Average points per game
  double get averagePoints =>
      gamesPlayed > 0 ? totalPoints / gamesPlayed : 0;

  /// Medal emoji based on rank
  String get medalEmoji {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  /// Whether user is in the top 3
  bool get isTopThree => rank <= 3 && rank > 0;

  /// Display name initials for avatar fallback
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';
  }

  factory LeaderboardEntry.fromMap(String uid, Map<String, dynamic> map) =>
      LeaderboardEntry(
        uid: uid,
        displayName: map['displayName'] ?? 'Anonymous',
        totalPoints: map['totalPoints'] ?? 0,
        gamesPlayed: map['gamesPlayed'] ?? 0,
        gameBreakdown:
            Map<String, int>.from(map['gameBreakdown'] ?? {}),
        lastPlayedAt: map['lastPlayedAt'] != null
            ? (map['lastPlayedAt'] as dynamic).toDate()
            : null,
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'totalPoints': totalPoints,
        'gamesPlayed': gamesPlayed,
        'gameBreakdown': gameBreakdown,
        'lastPlayedAt': lastPlayedAt,
      };

  /// Returns a copy with updated rank (set after sorting)
  LeaderboardEntry withRank(int newRank) => LeaderboardEntry(
        uid: uid,
        displayName: displayName,
        totalPoints: totalPoints,
        gamesPlayed: gamesPlayed,
        rank: newRank,
        gameBreakdown: gameBreakdown,
        lastPlayedAt: lastPlayedAt,
      );
}
