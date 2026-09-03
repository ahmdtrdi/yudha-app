import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/learning/application/learning_state.dart';
import 'package:yudha_mobile/features/learning/data/repositories/backend_learning_repository.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';

class LearningController extends StateNotifier<LearningState> {
  LearningController({required LearningRepository repository})
    : _repository = repository,
      super(const LearningState.loading()) {
    load();
  }

  final LearningRepository _repository;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    state = LearningState(
      status: LearningViewStatus.loading,
      dashboard: state.dashboard,
      errorMessage: null,
    );
    try {
      final LearningDashboard dashboard = await _repository.fetchDashboard();
      state = LearningState(
        status: LearningViewStatus.ready,
        dashboard: dashboard,
        errorMessage: null,
      );
    } on LearningUnavailableException catch (error) {
      state = LearningState(
        status: LearningViewStatus.unavailable,
        dashboard: null,
        errorMessage: error.message,
      );
    } catch (error) {
      state = LearningState(
        status: LearningViewStatus.error,
        dashboard: state.dashboard,
        errorMessage: error.toString(),
      );
    } finally {
      _loading = false;
    }
  }

  Future<bool> recordShown(LearningRecommendation recommendation) {
    return _record(recommendation, 'shown');
  }

  Future<bool> accept(LearningRecommendation recommendation) {
    return _record(recommendation, 'accepted');
  }

  Future<bool> dismiss(
    LearningRecommendation recommendation,
    String reason,
  ) async {
    final bool success = await _record(
      recommendation,
      'dismissed',
      dismissalReason: reason,
    );
    if (success) await load();
    return success;
  }

  Future<bool> _record(
    LearningRecommendation recommendation,
    String eventType, {
    String? dismissalReason,
  }) async {
    try {
      await _repository.recordRecommendationEvent(
        recommendationId: recommendation.id,
        eventType: eventType,
        dismissalReason: dismissalReason,
      );
      return true;
    } catch (error) {
      state = LearningState(
        status: state.dashboard == null
            ? LearningViewStatus.error
            : LearningViewStatus.ready,
        dashboard: state.dashboard,
        errorMessage: error.toString(),
      );
      return false;
    }
  }
}
