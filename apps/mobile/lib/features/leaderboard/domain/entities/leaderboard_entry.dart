class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.points,
    required this.winRate,
    required this.totalMatches,
    required this.isCurrentUser,
  });

  final int rank;
  final String playerId;
  final String playerName;
  final int points;
  final double winRate;
  final int totalMatches;
  final bool isCurrentUser;

  LeaderboardEntry copyWith({
    int? rank,
    String? playerId,
    String? playerName,
    int? points,
    double? winRate,
    int? totalMatches,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      rank: rank ?? this.rank,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      points: points ?? this.points,
      winRate: winRate ?? this.winRate,
      totalMatches: totalMatches ?? this.totalMatches,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
