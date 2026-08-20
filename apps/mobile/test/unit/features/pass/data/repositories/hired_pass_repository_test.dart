import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/pass/data/repositories/hired_pass_repository.dart';

void main() {
  test('maps authoritative daily mission progress', () async {
    final HiredPassRepository repository = HiredPassRepository(
      accessToken: 'token-123',
      baseUrl: 'https://api.example.com',
      client: MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/hired-pass');
        expect(request.headers['authorization'], 'Bearer token-123');
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'passPoints': 100,
              'adFree': true,
              'missions': <Map<String, Object?>>[
                <String, Object?>{
                  'id': '2026-07-practice-daily',
                  'title': 'Latihan harian',
                  'description':
                      'Selesaikan 1 sesi practice untuk mendapatkan 50 Pass Points',
                  'cadence': 'daily',
                  'progress': 1,
                  'target': 1,
                  'passPointsReward': 50,
                  'completed': true,
                },
                <String, Object?>{
                  'id': '2026-07-ranked-daily',
                  'title': 'Ranked harian',
                  'description':
                      'Selesaikan 1 ranked match untuk mendapatkan 50 Pass Points',
                  'cadence': 'daily',
                  'progress': 1,
                  'target': 1,
                  'passPointsReward': 50,
                  'completed': true,
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final status = await repository.fetchStatus();

    expect(status.passPoints, 100);
    expect(status.adFree, isTrue);
    expect(status.missions, hasLength(2));
    expect(status.missions.first.passPointsReward, 50);
    expect(status.missions.first.completed, isTrue);
    expect(status.missions.last.id, '2026-07-ranked-daily');
    expect(status.missions.last.target, 1);
  });

  test('requires an authenticated session', () async {
    final HiredPassRepository repository = HiredPassRepository(
      accessToken: null,
      client: MockClient(
        (_) async => throw StateError('HTTP should not be called'),
      ),
    );

    await expectLater(
      repository.fetchStatus(),
      throwsA(isA<HiredPassApiException>()),
    );
  });

  test('activates the current season with an idempotency key', () async {
    final HiredPassRepository repository = HiredPassRepository(
      accessToken: 'token-123',
      baseUrl: 'https://api.example.com',
      client: MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/hired-pass/beta-activate');
        expect(request.headers['authorization'], 'Bearer token-123');
        expect(request.body, contains('"seasonId":"beta-2026-08"'));
        expect(request.body, contains('"idempotencyKey"'));
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'activated': true,
              'replayed': false,
              'entitlement': <String, Object?>{
                'premiumActive': true,
                'expiresAt': '2026-09-01T00:00:00Z',
              },
            },
          }),
          200,
        );
      }),
    );

    final result = await repository.activateBeta('beta-2026-08');

    expect(result.success, isTrue);
    expect(result.premiumActive, isTrue);
    expect(result.expiresAt, isNotNull);
  });

  test('claims a reward and maps the authoritative balance', () async {
    final HiredPassRepository repository = HiredPassRepository(
      accessToken: 'token-123',
      baseUrl: 'https://api.example.com',
      client: MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/hired-pass/rewards/free-100-coins/claim');
        expect(request.body, contains('"idempotencyKey"'));
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'claimed': true,
              'replayed': false,
              'rewardId': 'free-100-coins',
              'coins': 400,
            },
          }),
          200,
        );
      }),
    );

    final result = await repository.claimReward('free-100-coins');

    expect(result.success, isTrue);
    expect(result.rewardId, 'free-100-coins');
    expect(result.coins, 400);
  });
}
