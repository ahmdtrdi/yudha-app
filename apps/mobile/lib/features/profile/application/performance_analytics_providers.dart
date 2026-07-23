import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_controller.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_state.dart';
import 'package:yudha_mobile/features/profile/data/repositories/backend_performance_analytics_repository.dart';
import 'package:yudha_mobile/features/profile/data/repositories/performance_analytics_repository.dart';

final Provider<PerformanceAnalyticsApiConfig>
performanceAnalyticsApiConfigProvider = Provider<PerformanceAnalyticsApiConfig>(
  (Ref ref) => PerformanceAnalyticsApiConfig(
    accessToken: ref.watch(authAccessTokenProvider),
  ),
);

final Provider<PerformanceAnalyticsRepository>
performanceAnalyticsRepositoryProvider =
    Provider<PerformanceAnalyticsRepository>(
      (Ref ref) => BackendPerformanceAnalyticsRepository(
        config: ref.watch(performanceAnalyticsApiConfigProvider),
      ),
    );

final StateNotifierProvider<
  PerformanceAnalyticsController,
  PerformanceAnalyticsState
>
performanceAnalyticsProvider =
    StateNotifierProvider<
      PerformanceAnalyticsController,
      PerformanceAnalyticsState
    >(
      (Ref ref) => PerformanceAnalyticsController(
        repository: ref.watch(performanceAnalyticsRepositoryProvider),
        shouldHydrate: ref.watch(isAuthenticatedProvider),
      ),
    );
