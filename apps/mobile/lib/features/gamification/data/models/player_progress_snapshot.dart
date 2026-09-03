import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

class PlayerProgressSnapshot {
  const PlayerProgressSnapshot({
    required this.playerId,
    required this.displayName,
    required this.wins,
    required this.losses,
    required this.draws,
    this.streak = 0,
    this.dailyMissions = const <Map<String, Object?>>[],
    this.learningNextAction,
  });

  final String playerId;
  final String displayName;
  final int wins;
  final int losses;
  final int draws;
  final int streak;
  final List<Map<String, Object?>> dailyMissions;
  final LearningRecommendation? learningNextAction;
}
