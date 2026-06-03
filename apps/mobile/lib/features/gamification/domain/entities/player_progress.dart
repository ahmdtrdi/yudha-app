import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
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
      totalPoints: 0,
      wins: 0,
      losses: 0,
      draws: 0,
      streak: 0,
      bestStreak: 0,
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

  ProgressTier? get nextTier => tier.nextTier;

  int get currentTierBasePoints => tier.minPoints;

  int get nextTierPoints => nextTier?.minPoints ?? tier.minPoints;

  double get tierProgress {
    final ProgressTier? next = nextTier;
    if (next == null) {
      return 1;
    }

    final int span = next.minPoints - tier.minPoints;
    if (span <= 0) {
      return 1;
    }

    return ((totalPoints - tier.minPoints) / span).clamp(0, 1).toDouble();
  }

  int get pointsUntilNextTier {
    final ProgressTier? next = nextTier;
    if (next == null) {
      return 0;
    }
    return (next.minPoints - totalPoints).clamp(0, next.minPoints);
  }

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

  PlayerProgress mergeSnapshot(PlayerProgressSnapshot snapshot) {
    return copyWith(
      playerId: snapshot.playerId,
      displayName: snapshot.displayName,
      totalPoints: snapshot.totalPoints,
      wins: snapshot.wins,
      losses: snapshot.losses,
      draws: snapshot.draws,
    );
  }
}
