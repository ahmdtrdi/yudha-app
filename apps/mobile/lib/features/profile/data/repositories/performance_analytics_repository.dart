import 'package:yudha_mobile/features/profile/domain/entities/performance_analytics.dart';

abstract class PerformanceAnalyticsRepository {
  Future<PerformanceAnalytics> fetchPerformance();
}
