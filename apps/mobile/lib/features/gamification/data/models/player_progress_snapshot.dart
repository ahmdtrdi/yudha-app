class PlayerProgressSnapshot {
  const PlayerProgressSnapshot({
    required this.playerId,
    required this.displayName,
    required this.totalPoints,
    required this.wins,
    required this.losses,
    required this.draws,
  });

  final String playerId;
  final String displayName;
  final int totalPoints;
  final int wins;
  final int losses;
  final int draws;
}
