import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/solo/data/solo_repository.dart';

void main() {
  test('preserves the backend nested error message', () async {
    final repository = SoloRepository(
      accessToken: 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'INTERNAL_ERROR',
              'message':
                  'Could not find submit_solo_answer in the schema cache.',
            },
          }),
          500,
        ),
      ),
    );

    await expectLater(
      repository.get('solo-1'),
      throwsA(
        isA<SoloApiException>().having(
          (error) => error.message,
          'message',
          contains('schema cache'),
        ),
      ),
    );
  });

  test('uses the authoritative hint endpoint', () async {
    late http.Request request;
    final repository = SoloRepository(
      accessToken: 'token',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'hint': 'Cari selisihnya.',
              'hintRequestedAt': '2026-09-02T01:00:00Z',
            },
          }),
          200,
        );
      }),
    );

    final hint = await repository.requestHint('solo-1', 'sq-1');

    expect(request.url.path, '/solo/sessions/solo-1/questions/sq-1/hint');
    expect(hint.hint, 'Cari selisihnya.');
  });

  test('submits timing without client-authored hint state', () async {
    late Map<String, dynamic> body;
    final repository = SoloRepository(
      accessToken: 'token',
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'sessionId': 'solo-1',
              'target': 'cpns',
              'questionCount': 20,
              'characterId': 'character-basic-squire',
              'status': 'active',
              'answeredCount': 1,
              'correctCount': 1,
              'towerHp': 95,
              'rewardCoins': 0,
              'hand': <Object?>[],
              'answerResult': <String, Object?>{
                'sessionQuestionId': 'sq-1',
                'attemptId': 'attempt-1',
                'isCorrect': true,
                'timedOut': false,
                'correctOptionIndex': 2,
                'explanation': 'Pembahasan.',
              },
            },
          }),
          200,
        );
      }),
    );

    final response = await repository.answer(
      'solo-1',
      'sq-1',
      2,
      clientActiveResponseTimeMs: 4200,
    );

    expect(body, isNot(contains('usedHint')));
    expect(body['clientActiveResponseTimeMs'], 4200);
    expect(response.feedback.attemptId, 'attempt-1');
  });
}
