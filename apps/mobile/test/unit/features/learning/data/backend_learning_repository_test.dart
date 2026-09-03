import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/learning/data/repositories/backend_learning_repository.dart';

void main() {
  test('fetches the approved 30-day dashboard without coercing null', () async {
    final BackendLearningRepository repository = BackendLearningRepository(
      config: const LearningApiConfig(
        baseUrl: 'https://api.example.test',
        accessToken: 'token',
      ),
      client: MockClient((http.Request request) async {
        expect(request.url.path, '/learning/dashboard');
        expect(request.url.queryParameters['window'], '30d');
        return http.Response(
          jsonEncode(<String, dynamic>{'data': _dashboardJson()}),
          200,
        );
      }),
    );

    final dashboard = await repository.fetchDashboard();

    expect(dashboard.accuracy.value, isNull);
    expect(dashboard.accuracy.attemptCount, 0);
  });

  test('records deterministic recommendation lifecycle idempotency', () async {
    final BackendLearningRepository repository = BackendLearningRepository(
      config: const LearningApiConfig(
        baseUrl: 'https://api.example.test',
        accessToken: 'token',
      ),
      client: MockClient((http.Request request) async {
        expect(
          request.url.path,
          '/learning/recommendations/recommendation-1/events',
        );
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['eventType'], 'accepted');
        expect(
          body['idempotencyKey'],
          'mobile-learning-accepted-recommendation-1',
        );
        return http.Response(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{'eventType': 'accepted'},
          }),
          200,
        );
      }),
    );

    await repository.recordRecommendationEvent(
      recommendationId: 'recommendation-1',
      eventType: 'accepted',
    );
  });

  test('maps rollout 503 to an unavailable state error', () async {
    final BackendLearningRepository repository = BackendLearningRepository(
      config: const LearningApiConfig(
        baseUrl: 'https://api.example.test',
        accessToken: 'token',
      ),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{'message': 'LEARNING_V2_DISABLED'}),
          503,
        ),
      ),
    );

    await expectLater(
      repository.fetchDashboard(),
      throwsA(isA<LearningUnavailableException>()),
    );
  });

  test('extracts nested error message from backend error responses', () async {
    final BackendLearningRepository repository = BackendLearningRepository(
      config: const LearningApiConfig(
        baseUrl: 'https://api.example.test',
        accessToken: 'token',
      ),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'INTERNAL_ERROR',
              'message': 'Detail kendala server',
            },
          }),
          500,
        ),
      ),
    );

    await expectLater(
      repository.fetchDashboard(),
      throwsA(
        isA<LearningApiException>().having(
          (LearningApiException e) => e.message,
          'message',
          'Detail kendala server',
        ),
      ),
    );
  });
}

Map<String, dynamic> _dashboardJson() => <String, dynamic>{
  'asOf': '2026-09-01T02:00:00.000Z',
  'calculationVersion': 'learning-v1',
  'target': 'cpns',
  'nextAction': null,
  'summary': <String, dynamic>{
    'curriculumCoverage': <String, dynamic>{
      'value': null,
      'coveredSkillCount': 0,
      'requiredSkillCount': 4,
      'confidence': 'low',
    },
    'unseenIndependentAccuracy': <String, dynamic>{
      'value': null,
      'correctCount': 0,
      'attemptCount': 0,
      'uniqueQuestionCount': 0,
      'confidence': 'low',
      'asOf': '2026-09-01T02:00:00.000Z',
    },
    'pace': <String, dynamic>{
      'value': null,
      'baselineType': null,
      'attemptCount': 0,
      'confidence': 'low',
    },
  },
  'skillStates': <dynamic>[],
  'trends': <dynamic>[],
  'retention': <dynamic>[],
  'assessment': <String, dynamic>{'status': 'not_available'},
  'activity': <String, dynamic>{},
  'competition': <String, dynamic>{'accuracy': <String, dynamic>{}},
};
