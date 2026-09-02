import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

const Object _unchangedLearningRecommendation = Object();

class PlayerProgress {
  const PlayerProgress({
    required this.playerId,
    required this.displayName,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.streak,
    required this.bestStreak,
    required this.dailyMissions,
    this.learningNextAction,
  });

  factory PlayerProgress.initial() {
    return const PlayerProgress(
      playerId: 'you',
      displayName: 'Kamu',
      wins: 0,
      losses: 0,
      draws: 0,
      streak: 0,
      bestStreak: 0,
      dailyMissions: <Map<String, Object?>>[],
    );
  }

  final String playerId;
  final String displayName;
  final int wins;
  final int losses;
  final int draws;
  final int streak;
  final int bestStreak;
  final List<Map<String, Object?>> dailyMissions;
  final LearningRecommendation? learningNextAction;

  int get matchesPlayed => wins + losses + draws;

  double get winRate {
    if (matchesPlayed == 0) {
      return 0;
    }
    return wins / matchesPlayed;
  }

  PlayerProgress copyWith({
    String? playerId,
    String? displayName,
    int? wins,
    int? losses,
    int? draws,
    int? streak,
    int? bestStreak,
    List<Map<String, Object?>>? dailyMissions,
    Object? learningNextAction = _unchangedLearningRecommendation,
  }) {
    return PlayerProgress(
      playerId: playerId ?? this.playerId,
      displayName: displayName ?? this.displayName,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      dailyMissions: dailyMissions ?? this.dailyMissions,
      learningNextAction:
          identical(learningNextAction, _unchangedLearningRecommendation)
          ? this.learningNextAction
          : learningNextAction as LearningRecommendation?,
    );
  }

  PlayerProgress mergeSnapshot(PlayerProgressSnapshot snapshot) {
    final int mergedStreak = snapshot.streak == 0 ? streak : snapshot.streak;
    final int mergedBestStreak = snapshot.streak == 0
        ? bestStreak
        : (snapshot.streak > bestStreak ? snapshot.streak : bestStreak);

    return copyWith(
      playerId: snapshot.playerId,
      displayName: snapshot.displayName,
      wins: snapshot.wins,
      losses: snapshot.losses,
      draws: snapshot.draws,
      streak: mergedStreak,
      bestStreak: mergedBestStreak,
      dailyMissions: snapshot.dailyMissions,
      learningNextAction: snapshot.learningNextAction,
    );
  }
}
