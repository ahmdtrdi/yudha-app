import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

enum LearningViewStatus { loading, ready, unavailable, error }

class LearningState {
  const LearningState({
    required this.status,
    required this.dashboard,
    required this.errorMessage,
  });

  const LearningState.loading()
    : status = LearningViewStatus.loading,
      dashboard = null,
      errorMessage = null;

  final LearningViewStatus status;
  final LearningDashboard? dashboard;
  final String? errorMessage;
}
