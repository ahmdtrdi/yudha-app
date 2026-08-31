import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/interview/data/repositories/backend_interview_repository.dart';
import 'package:yudha_mobile/features/interview/data/repositories/interview_repository.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';

void main() {
  group('BackendInterviewRepository', () {
    test(
      'maps the authenticated company catalog with nullable roles',
      () async {
        final BackendInterviewRepository repository =
            BackendInterviewRepository(
              config: const InterviewApiConfig(
                baseUrl: 'https://api.example.com',
                accessToken: 'token-123',
              ),
              client: MockClient((http.Request request) async {
                expect(request.method, 'GET');
                expect(request.url.path, '/interview/companies');
                expect(request.headers['authorization'], 'Bearer token-123');
                return http.Response(
                  jsonEncode(<String, Object?>{
                    'companies': <Map<String, Object?>>[
                      <String, Object?>{
                        'id': 'bank-indonesia',
                        'name': 'Bank Indonesia',
                        'defaultRole': 'Asisten Manajer',
                      },
                      <String, Object?>{
                        'id': 'injourney',
                        'name': 'PT Aviasi Pariwisata Indonesia (Persero)',
                        'defaultRole': null,
                      },
                    ],
                  }),
                  200,
                );
              }),
            );

        final companies = await repository.listCompanies();

        expect(companies, hasLength(2));
        expect(companies.first.id, 'bank-indonesia');
        expect(companies.first.defaultRole, 'Asisten Manajer');
        expect(companies.last.defaultRole, isNull);
      },
    );

    test('returns an empty company catalog', () async {
      final BackendInterviewRepository repository = BackendInterviewRepository(
        config: const InterviewApiConfig(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
        ),
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'companies': <Object?>[]}), 200),
        ),
      );

      await expectLater(repository.listCompanies(), completion(isEmpty));
    });

    test('rejects malformed company catalog responses', () async {
      final BackendInterviewRepository repository = BackendInterviewRepository(
        config: const InterviewApiConfig(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
        ),
        client: MockClient(
          (_) async => http.Response(jsonEncode({'companies': 'invalid'}), 200),
        ),
      );

      await expectLater(
        repository.listCompanies(),
        throwsA(isA<InterviewApiException>()),
      );
    });

    test('requires authentication before loading companies', () async {
      final BackendInterviewRepository repository = BackendInterviewRepository(
        config: const InterviewApiConfig(baseUrl: 'https://api.example.com'),
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        repository.listCompanies(),
        throwsA(
          isA<InterviewApiException>().having(
            (InterviewApiException error) => error.message,
            'message',
            contains('Sesi login'),
          ),
        ),
      );
    });

    test('reports company-specific connection failures', () async {
      final BackendInterviewRepository repository = BackendInterviewRepository(
        config: const InterviewApiConfig(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
        ),
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        repository.listCompanies(),
        throwsA(
          isA<InterviewApiException>().having(
            (InterviewApiException error) => error.message,
            'message',
            contains('Daftar perusahaan'),
          ),
        ),
      );
    });

    test('maps the complete text interview lifecycle contract', () async {
      final List<String> requestedPaths = <String>[];
      final BackendInterviewRepository repository = BackendInterviewRepository(
        config: const InterviewApiConfig(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
        ),
        client: MockClient((http.Request request) async {
          requestedPaths.add(request.url.path);
          expect(request.headers['authorization'], 'Bearer token-123');
          if (request.url.path == '/interview/sessions') {
            expect(jsonDecode(request.body), <String, Object?>{
              'mode': 'coaching',
              'targetRole': 'Officer Development Program',
              'companyId': 'bank-mandiri',
              'language': 'id',
              'responseStyle': 'text',
            });
            return http.Response(
              jsonEncode(<String, Object?>{
                'sessionId': 'sess-1',
                'status': 'active',
                'openingQuestion': <String, Object?>{
                  'turnId': 'question-1',
                  'text': 'Perkenalkan diri Anda.',
                  'audioAvailable': false,
                },
              }),
              201,
            );
          }
          if (request.url.path == '/interview/sessions/sess-1/turns') {
            expect(
              (jsonDecode(request.body)
                  as Map<String, dynamic>)['idempotencyKey'],
              'answer-key-1',
            );
            return http.Response(
              jsonEncode(<String, Object?>{
                'sessionId': 'sess-1',
                'status': 'active',
                'evaluation': <String, Object?>{
                  'overallScore': 80,
                  'strengths': <String>['Jelas'],
                  'improvements': <String>['Tambah contoh'],
                },
                'nextQuestion': <String, Object?>{
                  'turnId': 'question-2',
                  'text': 'Mengapa memilih Bank Mandiri?',
                  'audioAvailable': false,
                },
              }),
              201,
            );
          }
          if (request.url.path == '/interview/sessions/sess-1/complete') {
            return http.Response(
              jsonEncode(<String, Object?>{
                'sessionId': 'sess-1',
                'status': 'completed',
                'finalSummary': <String, Object?>{
                  'overallScore': 80,
                  'strengths': <String>['Jelas'],
                  'improvements': <String>['Tambah contoh'],
                  'answerCount': 1,
                },
              }),
              201,
            );
          }
          return http.Response('Not found', 404);
        }),
      );

      final start = await repository.startSession(
        InterviewLaunchConfig.bumnDefault(),
      );
      final turn = await repository.submitAnswer(
        sessionId: start.sessionId,
        answer: 'Saya ingin berkontribusi.',
        idempotencyKey: 'answer-key-1',
      );
      final summary = await repository.completeSession(start.sessionId);

      expect(start.openingQuestion.text, 'Perkenalkan diri Anda.');
      expect(turn.evaluation?.overallScore, 80);
      expect(turn.nextQuestion?.id, 'question-2');
      expect(summary.answerCount, 1);
      expect(requestedPaths, <String>[
        '/interview/sessions',
        '/interview/sessions/sess-1/turns',
        '/interview/sessions/sess-1/complete',
      ]);
    });

    test('uploads recorded audio and maps its transcript', () async {
      final BackendInterviewRepository repository = BackendInterviewRepository(
        config: const InterviewApiConfig(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
        ),
        client: MockClient((http.Request request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/interview/sessions/sess-1/speech/transcriptions',
          );
          expect(request.headers['authorization'], 'Bearer token-123');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          return http.Response(
            jsonEncode(<String, Object?>{
              'transcript': <String, Object?>{
                'text': 'Hasil transkripsi suara.',
              },
            }),
            201,
          );
        }),
      );

      final String transcript = await repository.transcribeAnswerAudio(
        sessionId: 'sess-1',
        audioBytes: <int>[1, 2, 3, 4],
        filename: 'recording.m4a',
      );

      expect(transcript, 'Hasil transkripsi suara.');
    });

    test('marks failed answer claims as requiring a fresh key', () async {
      final BackendInterviewRepository repository = BackendInterviewRepository(
        config: const InterviewApiConfig(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
        ),
        client: MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, Object?>{
              'message':
                  'The previous interview answer processing failed. Submit a new request.',
            }),
            503,
          );
        }),
      );

      expect(
        () => repository.submitAnswer(
          sessionId: 'sess-1',
          answer: 'Jawaban',
          idempotencyKey: 'failed-key',
        ),
        throwsA(isA<InterviewAnswerRetryRequiredException>()),
      );
    });

    test(
      'maps interview session summaries from backend list endpoint',
      () async {
        final BackendInterviewRepository repository =
            BackendInterviewRepository(
              config: const InterviewApiConfig(
                baseUrl: 'https://api.example.com',
                accessToken: 'token-123',
              ),
              client: MockClient((http.Request request) async {
                expect(request.method, 'GET');
                expect(
                  request.url.toString(),
                  'https://api.example.com/interview/sessions',
                );
                return http.Response(
                  jsonEncode(<String, Object?>{
                    'sessions': <Map<String, Object?>>[
                      <String, Object?>{
                        'sessionId': 'sess-1',
                        'status': 'completed',
                        'companyId': 'bumn_taspen',
                        'targetRole': 'Management Trainee',
                        'mode': 'coaching',
                        'language': 'id',
                        'responseStyle': 'text',
                        'finalSummary': <String, Object?>{
                          'overallScore': 87,
                          'dimensions': <String, Object?>{
                            'relevance': 88,
                            'clarity': 86,
                            'structure': 84,
                            'confidence': 82,
                            'impact': 80,
                            'authenticity': 90,
                          },
                          'strengths': <String>['Jelas'],
                          'improvements': <String>['Lebih konkret'],
                          'answerCount': 3,
                        },
                        'createdAt': '2026-06-03T02:10:00.000Z',
                        'updatedAt': '2026-06-03T02:20:00.000Z',
                      },
                    ],
                  }),
                  200,
                );
              }),
            );

        final sessions = await repository.listSessions();

        expect(sessions, hasLength(1));
        expect(sessions.first.sessionId, 'sess-1');
        expect(sessions.first.companyId, 'bumn_taspen');
        expect(sessions.first.finalSummary?.overallScore, 87);
        expect(sessions.first.finalSummary?.dimensions.relevance, 88);
        expect(sessions.first.finalSummary?.dimensions.authenticity, 90);
        expect(sessions.first.finalSummary?.answerCount, 3);
      },
    );

    test(
      'maps interview session detail transcript from backend detail endpoint',
      () async {
        final BackendInterviewRepository
        repository = BackendInterviewRepository(
          config: const InterviewApiConfig(
            baseUrl: 'https://api.example.com',
            accessToken: 'token-123',
          ),
          client: MockClient((http.Request request) async {
            expect(request.method, 'GET');
            expect(
              request.url.toString(),
              'https://api.example.com/interview/sessions/sess-1',
            );
            return http.Response(
              jsonEncode(<String, Object?>{
                'sessionId': 'sess-1',
                'status': 'completed',
                'companyId': 'bumn_taspen',
                'targetRole': 'Management Trainee',
                'mode': 'coaching',
                'responseStyle': 'text',
                'turns': <Map<String, Object?>>[
                  <String, Object?>{
                    'turnId': 'turn-q-1',
                    'role': 'question',
                    'text': 'Perkenalkan diri Anda.',
                    'createdAt': '2026-06-03T02:10:00.000Z',
                  },
                  <String, Object?>{
                    'turnId': 'turn-a-1',
                    'role': 'answer',
                    'text': 'Saya senang belajar.',
                    'createdAt': '2026-06-03T02:11:00.000Z',
                    'evaluation': <String, Object?>{
                      'overallScore': 81,
                      'dimensions': <String, Object?>{
                        'relevance': 82,
                        'clarity': 80,
                        'structure': 78,
                        'confidence': 76,
                        'impact': 74,
                        'authenticity': 84,
                      },
                      'candidateFacts': <String>['Senang belajar'],
                      'strengths': <String>['Ringkas'],
                      'improvements': <String>['Tambah contoh'],
                      'coachNote': 'Coba beri contoh yang lebih konkret.',
                      'suggestedRewrite':
                          'Saya senang belajar dan cepat menerapkan hal baru.',
                    },
                  },
                ],
                'finalSummary': <String, Object?>{
                  'overallScore': 81,
                  'strengths': <String>['Ringkas'],
                  'improvements': <String>['Tambah contoh'],
                  'answerCount': 1,
                },
              }),
              200,
            );
          }),
        );

        final detail = await repository.getSession('sess-1');

        expect(detail.sessionId, 'sess-1');
        expect(detail.messages, hasLength(2));
        expect(detail.messages.first.text, 'Perkenalkan diri Anda.');
        expect(detail.messages.last.evaluation?.coachNote, isNotEmpty);
        expect(detail.messages.last.evaluation?.dimensions.structure, 78);
        expect(detail.messages.last.evaluation?.candidateFacts, <String>[
          'Senang belajar',
        ]);
        expect(detail.messages.last.evaluation?.suggestedRewrite, isNotEmpty);
        expect(detail.finalSummary?.answerCount, 1);
      },
    );
  });
}
