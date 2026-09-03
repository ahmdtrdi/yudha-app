import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';

void main() {
  test('authoritative zero streak replaces local fallback streak', () {
    final PlayerProgress local = PlayerProgress.initial().copyWith(
      streak: 1,
      bestStreak: 1,
    );

    final PlayerProgress merged = local.mergeSnapshot(
      const PlayerProgressSnapshot(
        playerId: 'user-1',
        displayName: 'Yudha',
        wins: 0,
        losses: 0,
        draws: 0,
        streak: 0,
        bestStreak: 0,
      ),
    );

    expect(merged.streak, 0);
    expect(merged.bestStreak, 0);
  });

  test('authoritative current and best streak are both hydrated', () {
    final PlayerProgress merged = PlayerProgress.initial().mergeSnapshot(
      const PlayerProgressSnapshot(
        playerId: 'user-1',
        displayName: 'Yudha',
        wins: 0,
        losses: 0,
        draws: 0,
        streak: 2,
        bestStreak: 5,
      ),
    );

    expect(merged.streak, 2);
    expect(merged.bestStreak, 5);
  });
}
