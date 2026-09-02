class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.pvpRating,
    required this.winRate,
    required this.ratedMatches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.status,
    required this.isCurrentUser,
  });

  final int? rank;
  final String playerId;
  final String playerName;
  final int pvpRating;
  final double? winRate;
  final int ratedMatches;
  final int wins;
  final int losses;
  final int draws;
  final String status;
  final bool isCurrentUser;

  LeaderboardEntry copyWith({
    int? rank,
    String? playerId,
    String? playerName,
    int? pvpRating,
    double? winRate,
    bool clearWinRate = false,
    int? ratedMatches,
    int? wins,
    int? losses,
    int? draws,
    String? status,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      rank: rank ?? this.rank,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      pvpRating: pvpRating ?? this.pvpRating,
      winRate: clearWinRate ? null : winRate ?? this.winRate,
      ratedMatches: ratedMatches ?? this.ratedMatches,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      status: status ?? this.status,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
