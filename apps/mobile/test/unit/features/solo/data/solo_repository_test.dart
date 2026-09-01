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
}
