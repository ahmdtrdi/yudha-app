import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_state.dart';
import 'package:yudha_mobile/features/profile/data/repositories/performance_analytics_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/performance_analytics.dart';

class PerformanceAnalyticsController
    extends StateNotifier<PerformanceAnalyticsState> {
  PerformanceAnalyticsController({
    required PerformanceAnalyticsRepository repository,
    bool shouldHydrate = false,
  }) : _repository = repository,
       super(PerformanceAnalyticsState.initial()) {
    if (shouldHydrate) {
      unawaited(load());
    }
  }

  final PerformanceAnalyticsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      status: PerformanceAnalyticsStatus.loading,
      clearError: true,
    );
    try {
      final PerformanceAnalytics analytics = await _repository
          .fetchPerformance();
      state = state.copyWith(
        status: PerformanceAnalyticsStatus.ready,
        analytics: analytics,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        status: PerformanceAnalyticsStatus.error,
        errorMessage: error.toString(),
      );
    }
  }
}
