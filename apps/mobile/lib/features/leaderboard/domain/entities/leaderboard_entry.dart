class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.points,
    required this.winRate,
    required this.streak,
    required this.isCurrentUser,
  });

  final String playerId;
  final String playerName;
  final int points;
  final double winRate;
  final int streak;
  final bool isCurrentUser;

  LeaderboardEntry copyWith({
    String? playerId,
    String? playerName,
    int? points,
    double? winRate,
    int? streak,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      points: points ?? this.points,
      winRate: winRate ?? this.winRate,
      streak: streak ?? this.streak,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
