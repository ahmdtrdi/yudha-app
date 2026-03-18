import 'package:yudha_mobile/features/gamification/domain/entities/progress_tier.dart';

class PlayerProgress {
  const PlayerProgress({
    required this.playerId,
    required this.displayName,
    required this.totalPoints,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.streak,
    required this.bestStreak,
    required this.lastDelta,
  });

  factory PlayerProgress.initial() {
    return const PlayerProgress(
      playerId: 'you',
      displayName: 'Kamu',
      totalPoints: 520,
      wins: 12,
      losses: 6,
      draws: 2,
      streak: 0,
      bestStreak: 3,
      lastDelta: 0,
    );
  }

  final String playerId;
  final String displayName;
  final int totalPoints;
  final int wins;
  final int losses;
  final int draws;
  final int streak;
  final int bestStreak;
  final int lastDelta;

  int get matchesPlayed => wins + losses + draws;

  double get winRate {
    if (matchesPlayed == 0) {
      return 0;
    }
    return wins / matchesPlayed;
  }

  ProgressTier get tier => ProgressTier.fromPoints(totalPoints);

  PlayerProgress copyWith({
    String? playerId,
    String? displayName,
    int? totalPoints,
    int? wins,
    int? losses,
    int? draws,
    int? streak,
    int? bestStreak,
    int? lastDelta,
  }) {
    return PlayerProgress(
      playerId: playerId ?? this.playerId,
      displayName: displayName ?? this.displayName,
      totalPoints: totalPoints ?? this.totalPoints,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastDelta: lastDelta ?? this.lastDelta,
    );
  }
}
