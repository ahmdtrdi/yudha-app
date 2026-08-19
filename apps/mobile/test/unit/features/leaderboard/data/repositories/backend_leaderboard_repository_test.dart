import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/backend_leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_query.dart';

void main() {
  test(
    'maps leaderboard list and current user rank from backend responses',
    () async {
      final BackendLeaderboardRepository repository =
          BackendLeaderboardRepository(
            config: const LeaderboardApiConfig(
              baseUrl: 'https://api.example.com',
              accessToken: 'token-123',
            ),
            client: MockClient((http.Request request) async {
              if (request.url.path == '/leaderboard/me') {
                return http.Response(
                  jsonEncode(<String, Object?>{
                    'data': <String, Object?>{
                      'rank': 4,
                      'userId': 'user-4',
                      'username': 'Kamu',
                      'rankPoints': 990,
                      'totalMatches': 12,
                      'winrate': 0.78,
                    },
                  }),
                  200,
                );
              }

              expect(request.method, 'GET');
              expect(request.url.path, '/leaderboard');
              expect(request.url.queryParameters['limit'], '8');
              expect(request.url.queryParameters['offset'], '0');
              return http.Response(
                jsonEncode(<String, Object?>{
                  'data': <String, Object?>{
                    'items': <Map<String, Object?>>[
                      <String, Object?>{
                        'rank': 1,
                        'userId': 'user-1',
                        'username': 'Raka',
                        'rankPoints': 1420,
                        'totalMatches': 18,
                        'winrate': 0.82,
                      },
                      <String, Object?>{
                        'rank': 4,
                        'userId': 'user-4',
                        'username': 'Kamu',
                        'rankPoints': 990,
                        'totalMatches': 12,
                        'winrate': 0.78,
                      },
                    ],
                    'limit': 8,
                    'offset': 0,
                    'total': 2,
                  },
                }),
                200,
              );
            }),
          );

      final payload = await repository.fetchPage(
        const LeaderboardQuery(page: 1, pageSize: 8),
      );

      expect(payload.entries, hasLength(2));
      expect(payload.entries.first.rank, 1);
      expect(payload.entries.last.isCurrentUser, isTrue);
      expect(payload.currentUserRank, 4);
      expect(payload.currentUserEntry?.playerId, 'user-4');
      expect(payload.currentUserEntry?.totalMatches, 12);
      expect(payload.currentUserEntry?.isCurrentUser, isTrue);
      expect(payload.hasMore, isFalse);
    },
  );

  test('surfaces backend errors instead of returning mock players', () async {
    final BackendLeaderboardRepository repository =
        BackendLeaderboardRepository(
          config: const LeaderboardApiConfig(
            baseUrl: 'https://api.example.com',
            accessToken: 'token-123',
          ),
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(<String, Object?>{'message': 'Service unavailable'}),
              503,
            ),
          ),
        );

    await expectLater(
      repository.fetchPage(const LeaderboardQuery(page: 1, pageSize: 8)),
      throwsA(isA<LeaderboardApiException>()),
    );
  });
}
