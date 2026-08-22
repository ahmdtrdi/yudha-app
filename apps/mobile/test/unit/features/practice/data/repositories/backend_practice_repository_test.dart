import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/practice/data/repositories/backend_practice_repository.dart';

void main() {
  test('fetches a paginated practice history batch', () async {
    final BackendPracticeRepository repository = BackendPracticeRepository(
      config: const PracticeApiConfig(
        baseUrl: 'https://api.example.com',
        accessToken: 'token-123',
      ),
      client: MockClient((http.Request request) async {
        expect(request.url.path, '/practice/history');
        expect(request.url.queryParameters, <String, String>{
          'limit': '20',
          'offset': '20',
        });
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'items': <Map<String, Object?>>[
                <String, Object?>{
                  'category': 'kepribadian',
                  'subcategory': null,
                  'answeredCount': 5,
                  'totalQuestions': 5,
                  'accuracy': 80,
                },
              ],
              'limit': 20,
              'offset': 20,
              'total': 41,
            },
          }),
          200,
        );
      }),
    );

    final batch = await repository.fetchHistory(limit: 20, offset: 20);

    expect(batch.items.single.title, 'Kepribadian');
    expect(batch.items.single.scoreLabel, '80%');
    expect(batch.hasMore, isTrue);
  });

  test(
    'includes idempotency keys when submitting and finishing a session',
    () async {
      final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
      final BackendPracticeRepository repository = BackendPracticeRepository(
        config: const PracticeApiConfig(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
        ),
        client: MockClient((http.Request request) async {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          if (request.url.path.endsWith('/answers')) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'data': <String, Object?>{
                  'isCorrect': true,
                  'correctOptionIndex': 0,
                  'scoreGained': 10,
                  'progress': <String, Object?>{
                    'totalQuestions': 1,
                    'answeredCount': 1,
                    'correctCount': 1,
                    'accuracy': 100,
                    'totalScore': 10,
                  },
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{
                'totalQuestions': 1,
                'answeredCount': 1,
                'correctCount': 1,
                'accuracy': 100,
                'totalScore': 10,
              },
            }),
            200,
          );
        }),
      );

      await repository.submitAnswer(
        sessionId: 'session-1',
        sessionQuestionId: 'session-question-1',
        selectedOptionIndex: 0,
        responseTimeMs: 1000,
        usedHint: false,
      );
      await repository.finishSession(sessionId: 'session-1');

      expect(requests, hasLength(2));
      expect(
        requests[0]['idempotencyKey'],
        startsWith('mobile-practice-answer-'),
      );
      expect(
        requests[1]['idempotencyKey'],
        startsWith('mobile-practice-finish-'),
      );
    },
  );

  test('humanizes subcategory identifiers and preserves acronyms', () async {
    final BackendPracticeRepository repository = BackendPracticeRepository(
      config: const PracticeApiConfig(
        baseUrl: 'https://api.example.com',
        accessToken: 'token-123',
      ),
      client: MockClient((http.Request request) async {
        if (request.url.path == '/practice/dashboard') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{
                'summary': <String, Object?>{'averageAccuracy': 75},
                'categories': <Map<String, Object?>>[
                  <String, Object?>{
                    'category': 'wawasan_kebangsaan',
                    'label': 'Wawasan Kebangsaan',
                    'availableQuestions': 12,
                    'subcategories': <Map<String, Object?>>[
                      <String, Object?>{
                        'subcategory': 'uud_1945',
                        'availableQuestions': 6,
                      },
                      <String, Object?>{
                        'subcategory': 'nkri',
                        'availableQuestions': 6,
                      },
                    ],
                  },
                  <String, Object?>{
                    'category': 'tiu',
                    'label': 'tiu',
                    'availableQuestions': 8,
                    'subcategories': <Object?>[],
                  },
                ],
                'recentSessions': <Map<String, Object?>>[
                  <String, Object?>{
                    'category': 'wawasan_kebangsaan',
                    'subcategory': 'uud_1945',
                    'answeredCount': 5,
                    'totalQuestions': 5,
                    'accuracy': 80,
                  },
                ],
              },
            }),
            200,
          );
        }

        expect(request.url.path, '/practice/sessions');
        expect(jsonDecode(request.body), <String, Object?>{
          'category': 'wawasan_kebangsaan',
          'subcategory': 'uud_1945',
        });
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'sessionId': 'session-1',
              'category': 'wawasan_kebangsaan',
              'subcategory': 'uud_1945',
              'totalQuestions': 1,
              'questions': <Map<String, Object?>>[
                <String, Object?>{
                  'questionId': 'question-1',
                  'sessionQuestionId': 'session-question-1',
                  'questionOrder': 1,
                  'category': 'wawasan_kebangsaan',
                  'subcategory': 'uud_1945',
                  'prompt': 'Contoh soal',
                  'options': <String>['Satu', 'Dua'],
                  'hint': 'Contoh petunjuk',
                  'timeLimitSeconds': 60,
                },
              ],
            },
          }),
          201,
        );
      }),
    );

    final dashboard = await repository.fetchDashboard();
    final session = await repository.startSession(
      category: dashboard.topics.first.category,
      subcategory: dashboard.topics.first.subcategory,
    );

    expect(dashboard.topics.first.groupTitle, 'WAWASAN KEBANGSAAN');
    expect(dashboard.topics.first.badgeLabel, 'Wawasan Kebangsaan');
    expect(dashboard.topics.first.name, 'UUD 1945');
    expect(dashboard.topics[1].name, 'NKRI');
    expect(dashboard.topics.last.name, 'TIU');
    expect(
      dashboard.recentActivities.first.title,
      'Wawasan Kebangsaan - UUD 1945',
    );
    expect(session.questions.single.topicName, 'UUD 1945');
  });
}
