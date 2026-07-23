import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/interview/data/repositories/backend_interview_repository.dart';

void main() {
  group('BackendInterviewRepository', () {
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
