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
                  'learningSummary': <String, Object?>{
                    'curriculumCoverage': <String, Object?>{
                      'value': 42,
                      'coveredSkillCount': 8,
                      'requiredSkillCount': 19,
                      'confidence': 'medium',
                    },
                  },
                  'learningNextAction': <String, Object?>{
                    'recommendationId': 'recommendation-1',
                    'target': 'cpns',
                    'objective': 'repair_accuracy',
                    'skill': <String, Object?>{
                      'id': 'cpns.tiu.numerik',
                      'label': 'TIU Numerik',
                      'category': 'tiu',
                      'subcategory': 'numerik',
                    },
                    'mechanicMode': 'focus',
                    'reason': <String, Object?>{
                      'headline': 'Perkuat TIU Numerik',
                      'description': 'Akurasi perlu diperbaiki.',
                    },
                    'confidence': 'medium',
                    'availability': <String, Object?>{
                      'runnable': true,
                      'compatibilityAdapter': 'practice_fixed_five',
                      'label': 'Practice 5 soal (kompatibilitas)',
                    },
                  },
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
    expect(snapshot.tier, 'elite');
    expect(snapshot.target, 'cpns');
    expect(snapshot.curriculumCoverage?.value, 42);
    expect(snapshot.curriculumCoverage?.coveredSkillCount, 8);
    expect(snapshot.curriculumCoverage?.requiredSkillCount, 19);
    expect(snapshot.wins, 18);
    expect(snapshot.losses, 4);
    expect(snapshot.draws, 2);
    expect(snapshot.learningNextAction?.skillLabel, 'TIU Numerik');
    expect(snapshot.learningNextAction?.runnable, isTrue);
  });
}
