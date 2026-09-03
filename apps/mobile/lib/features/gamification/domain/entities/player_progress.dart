import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

const Object _unchangedLearningRecommendation = Object();
const Object _unchangedCurriculumCoverage = Object();

class PlayerProgress {
  const PlayerProgress({
    required this.playerId,
    required this.displayName,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.totalPoints,
    required this.tier,
    required this.target,
    required this.streak,
    required this.bestStreak,
    required this.lastDelta,
    required this.dailyMissions,
    this.learningNextAction,
    this.curriculumCoverage,
  });

  factory PlayerProgress.initial() {
    return const PlayerProgress(
      playerId: 'you',
      displayName: 'Kamu',
      wins: 0,
      losses: 0,
      draws: 0,
      totalPoints: 0,
      tier: 'rookie',
      target: 'cpns',
      streak: 0,
      bestStreak: 0,
      lastDelta: 0,
      dailyMissions: <Map<String, Object?>>[],
    );
  }

  final String playerId;
  final String displayName;
  final int wins;
  final int losses;
  final int draws;
  final int totalPoints;
  final String tier;
  final String target;
  final int streak;
  final int bestStreak;
  final int lastDelta;
  final List<Map<String, Object?>> dailyMissions;
  final LearningRecommendation? learningNextAction;
  final LearningCoverage? curriculumCoverage;

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
    int? totalPoints,
    String? tier,
    String? target,
    int? streak,
    int? bestStreak,
    int? lastDelta,
    List<Map<String, Object?>>? dailyMissions,
    Object? learningNextAction = _unchangedLearningRecommendation,
    Object? curriculumCoverage = _unchangedCurriculumCoverage,
  }) {
    return PlayerProgress(
      playerId: playerId ?? this.playerId,
      displayName: displayName ?? this.displayName,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      totalPoints: totalPoints ?? this.totalPoints,
      tier: tier ?? this.tier,
      target: target ?? this.target,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastDelta: lastDelta ?? this.lastDelta,
      dailyMissions: dailyMissions ?? this.dailyMissions,
      learningNextAction:
          identical(learningNextAction, _unchangedLearningRecommendation)
          ? this.learningNextAction
          : learningNextAction as LearningRecommendation?,
      curriculumCoverage:
          identical(curriculumCoverage, _unchangedCurriculumCoverage)
          ? this.curriculumCoverage
          : curriculumCoverage as LearningCoverage?,
    );
  }

  PlayerProgress mergeSnapshot(PlayerProgressSnapshot snapshot) {
    return copyWith(
      playerId: snapshot.playerId,
      displayName: snapshot.displayName,
      wins: snapshot.wins,
      losses: snapshot.losses,
      draws: snapshot.draws,
      totalPoints: snapshot.totalPoints,
      tier: snapshot.tier,
      target: snapshot.target,
      streak: snapshot.streak,
      bestStreak: snapshot.bestStreak,
      dailyMissions: snapshot.dailyMissions,
      learningNextAction: snapshot.learningNextAction,
      curriculumCoverage: snapshot.curriculumCoverage,
    );
  }
}
