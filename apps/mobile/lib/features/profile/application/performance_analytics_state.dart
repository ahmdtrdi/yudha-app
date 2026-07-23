import 'package:yudha_mobile/features/profile/domain/entities/performance_analytics.dart';

enum PerformanceAnalyticsStatus { initial, loading, ready, error }

class PerformanceAnalyticsState {
  const PerformanceAnalyticsState({
    required this.status,
    this.analytics,
    this.errorMessage,
  });

  factory PerformanceAnalyticsState.initial() {
    return const PerformanceAnalyticsState(
      status: PerformanceAnalyticsStatus.initial,
    );
  }

  final PerformanceAnalyticsStatus status;
  final PerformanceAnalytics? analytics;
  final String? errorMessage;

  PerformanceAnalyticsState copyWith({
    PerformanceAnalyticsStatus? status,
    PerformanceAnalytics? analytics,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PerformanceAnalyticsState(
      status: status ?? this.status,
      analytics: analytics ?? this.analytics,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
