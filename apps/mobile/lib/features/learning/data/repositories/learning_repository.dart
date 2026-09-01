import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

abstract class LearningRepository {
  Future<LearningDashboard> fetchDashboard();

  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  });
}
