import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/profile/data/repositories/backend_performance_analytics_repository.dart';

void main() {
  group('BackendPerformanceAnalyticsRepository', () {
    test('maps authenticated practice and battle analytics', () async {
      final BackendPerformanceAnalyticsRepository repository =
          BackendPerformanceAnalyticsRepository(
            config: const PerformanceAnalyticsApiConfig(
              baseUrl: 'https://api.example.test',
              accessToken: 'token-123',
            ),
            client: MockClient((http.Request request) async {
              expect(request.method, 'GET');
              expect(
                request.url.toString(),
                'https://api.example.test/analytics',
              );
              expect(request.headers['authorization'], 'Bearer token-123');
              return http.Response(
                jsonEncode(<String, Object?>{
                  'data': <String, Object?>{
                    'practice': <String, Object?>{
                      'accuracy': 72.5,
                      'sampleSize': 40,
                      'averageResponseTimeMs': 2450,
                      'categoryBreakdown': <Map<String, Object?>>[
                        <String, Object?>{
                          'category': 'TIU',
                          'accuracy': 80,
                          'sampleSize': 20,
                        },
                      ],
                      'subcategoryBreakdown': <Map<String, Object?>>[
                        <String, Object?>{
                          'subcategory': 'pelayanan_publik',
                          'accuracy': 45,
                          'sampleSize': 10,
                        },
                      ],
                    },
                    'publicMatches': <String, Object?>{
                      'winRate': 60,
                      'wins': 6,
                      'losses': 4,
                      'sampleSize': 10,
                    },
                  },
                }),
                200,
              );
            }),
          );

      final analytics = await repository.fetchPerformance();

      expect(analytics.practice.overallAccuracy, 72.5);
      expect(analytics.practice.averageResponseTimeMs, 2450);
      expect(analytics.practice.categoryBreakdown.single.category, 'TIU');
      expect(analytics.practice.categoryBreakdown.single.totalAnswered, 20);
      expect(
        analytics.practice.weakSubcategories.single.subcategory,
        'pelayanan_publik',
      );
      expect(analytics.battle.winRate, 0.6);
      expect(analytics.battle.totalMatches, 10);
    });

    test('requires an authenticated session', () async {
      final BackendPerformanceAnalyticsRepository repository =
          BackendPerformanceAnalyticsRepository(
            config: const PerformanceAnalyticsApiConfig(
              baseUrl: 'https://api.example.test',
            ),
          );

      expect(
        repository.fetchPerformance,
        throwsA(isA<PerformanceAnalyticsApiException>()),
      );
    });
  });
}
