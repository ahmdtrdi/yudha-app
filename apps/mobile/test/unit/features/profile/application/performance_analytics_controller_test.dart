import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_controller.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_state.dart';
import 'package:yudha_mobile/features/profile/data/repositories/performance_analytics_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/performance_analytics.dart';

void main() {
  test('loads performance analytics', () async {
    final _FakePerformanceAnalyticsRepository repository =
        _FakePerformanceAnalyticsRepository();
    final PerformanceAnalyticsController controller =
        PerformanceAnalyticsController(repository: repository);

    await controller.load();

    expect(controller.state.status, PerformanceAnalyticsStatus.ready);
    expect(controller.state.analytics?.practice.totalAnswered, 40);
    expect(controller.state.analytics?.battle.totalMatches, 10);
  });

  test('keeps the previous summary when refresh fails', () async {
    final _FakePerformanceAnalyticsRepository repository =
        _FakePerformanceAnalyticsRepository();
    final PerformanceAnalyticsController controller =
        PerformanceAnalyticsController(repository: repository);
    await controller.load();
    repository.shouldFail = true;

    await controller.load();

    expect(controller.state.status, PerformanceAnalyticsStatus.error);
    expect(controller.state.analytics?.practice.totalAnswered, 40);
    expect(controller.state.errorMessage, isNotEmpty);
  });
}

class _FakePerformanceAnalyticsRepository
    implements PerformanceAnalyticsRepository {
  bool shouldFail = false;

  @override
  Future<PerformanceAnalytics> fetchPerformance() async {
    if (shouldFail) {
      throw Exception('Ringkasan performa belum dapat dimuat.');
    }
    return _analyticsFixture;
  }
}

const PerformanceAnalytics _analyticsFixture = PerformanceAnalytics(
  practice: PracticePerformance(
    overallAccuracy: 72.5,
    totalAnswered: 40,
    averageResponseTimeMs: 2450,
    categoryBreakdown: <CategoryPerformance>[
      CategoryPerformance(category: 'TIU', accuracy: 80, totalAnswered: 20),
    ],
    weakSubcategories: <SubcategoryPerformance>[
      SubcategoryPerformance(
        subcategory: 'pelayanan_publik',
        accuracy: 45,
        totalAnswered: 10,
      ),
    ],
  ),
  battle: BattlePerformance(winRate: 0.6, wins: 6, losses: 4, totalMatches: 10),
);
