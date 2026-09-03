import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

class PlayerProgressSnapshot {
  const PlayerProgressSnapshot({
    required this.playerId,
    required this.displayName,
    required this.wins,
    required this.losses,
    required this.draws,
    this.totalPoints = 0,
    this.tier = 'rookie',
    this.target = 'cpns',
    this.streak = 0,
    this.bestStreak = 0,
    this.dailyMissions = const <Map<String, Object?>>[],
    this.learningNextAction,
    this.curriculumCoverage,
  });

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
  final List<Map<String, Object?>> dailyMissions;
  final LearningRecommendation? learningNextAction;
  final LearningCoverage? curriculumCoverage;
}
