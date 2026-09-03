import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/learning/application/learning_controller.dart';
import 'package:yudha_mobile/features/learning/application/learning_state.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

void main() {
  test('keeps the last dashboard when a refresh fails', () async {
    final _RefreshFailureRepository repository = _RefreshFailureRepository();
    final LearningController controller = LearningController(
      repository: repository,
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);

    final LearningDashboard cached = controller.state.dashboard!;
    await controller.load();

    expect(controller.state.status, LearningViewStatus.error);
    expect(controller.state.dashboard, same(cached));
    expect(controller.state.errorMessage, contains('offline'));
  });
}

class _RefreshFailureRepository implements LearningRepository {
  int calls = 0;

  @override
  Future<LearningDashboard> fetchDashboard() async {
    calls += 1;
    if (calls > 1) throw Exception('offline');
    return LearningDashboard.fromJson(<String, dynamic>{
      'asOf': '2026-09-01T02:00:00.000Z',
      'calculationVersion': 'learning-v2',
      'target': 'cpns',
      'summary': <String, dynamic>{},
      'skillStates': <dynamic>[],
      'trends': <dynamic>[],
      'retention': <dynamic>[],
      'assessment': <String, dynamic>{'status': 'not_available'},
      'activity': <String, dynamic>{},
      'competition': <String, dynamic>{},
    });
  }

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {}
}
