import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/backend_player_progress_repository.dart';

void main() {
  test('loads lobby summary from the dedicated backend endpoint', () async {
    final BackendPlayerProgressRepository repository =
        BackendPlayerProgressRepository(
          config: const PlayerProgressApiConfig(
            baseUrl: 'https://api.example.com',
            accessToken: 'token-123',
          ),
          client: MockClient((http.Request request) async {
            expect(request.method, 'GET');
            expect(request.url.toString(), 'https://api.example.com/lobby/summary');
            expect(request.headers['authorization'], 'Bearer token-123');

            return http.Response(
              jsonEncode(<String, Object?>{
                'data': <String, Object?>{
                  'profile': <String, Object?>{
                    'id': 'user-123',
                    'username': 'raka',
                    'fullName': 'Raka Saputra',
                    'rankPoints': 860,
                    'wins': 18,
                    'losses': 4,
                    'draws': 2,
                    'tier': 'elite',
                  },
                  'rankPoints': 860,
                  'streak': 5,
                },
              }),
              200,
            );
          }),
        );

    final snapshot = await repository.fetchCurrentProgress();

    expect(snapshot.playerId, 'user-123');
    expect(snapshot.displayName, 'Raka Saputra');
    expect(snapshot.totalPoints, 860);
    expect(snapshot.wins, 18);
    expect(snapshot.losses, 4);
    expect(snapshot.draws, 2);
  });
}
