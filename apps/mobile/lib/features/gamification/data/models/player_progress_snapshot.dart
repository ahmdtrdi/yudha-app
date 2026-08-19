class PlayerProgressSnapshot {
  const PlayerProgressSnapshot({
    required this.playerId,
    required this.displayName,
    required this.totalPoints,
    required this.wins,
    required this.losses,
    required this.draws,
    this.streak = 0,
    this.dailyMissions = const <Map<String, Object?>>[],
  });

  final String playerId;
  final String displayName;
  final int totalPoints;
  final int wins;
  final int losses;
  final int draws;
  final int streak;
  final List<Map<String, Object?>> dailyMissions;
}
