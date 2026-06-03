import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_controller.dart';
import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/player_progress_repository.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

void main() {
  test('applyBattleResult updates points and streak on win', () {
    final PlayerProgressController controller = PlayerProgressController();
    final int startingPoints = controller.state.totalPoints;

    controller.applyBattleResult(outcome: BattleOutcome.win, ratingDelta: 20);

    expect(controller.state.totalPoints, startingPoints + 20);
    expect(controller.state.streak, 1);
    expect(controller.state.wins, 1);
    expect(controller.state.lastDelta, 20);
  });

  test('applyBattleResult resets streak on lose and clamps points', () {
    final PlayerProgressController controller = PlayerProgressController();

    controller.applyBattleResult(outcome: BattleOutcome.win, ratingDelta: 20);
    controller.applyBattleResult(
      outcome: BattleOutcome.lose,
      ratingDelta: -99999,
    );

    expect(controller.state.streak, 0);
    expect(controller.state.totalPoints, 0);
    expect(controller.state.losses, 1);
    expect(controller.state.lastDelta, -99999);
  });

  test('hydrates from repository when authenticated', () async {
    final PlayerProgressController controller = PlayerProgressController(
      repository: _FakePlayerProgressRepository(),
      shouldHydrate: true,
    );

    await Future<void>.delayed(Duration.zero);

    expect(controller.state.playerId, 'user-123');
    expect(controller.state.displayName, 'Raka');
    expect(controller.state.totalPoints, 860);
    expect(controller.state.wins, 18);
    expect(controller.state.losses, 4);
    expect(controller.state.draws, 2);
  });

  test('hydrate keeps local-only streak fields in the projection', () async {
    final PlayerProgressController controller = PlayerProgressController(
      repository: _FakePlayerProgressRepository(),
    );

    controller.applyBattleResult(outcome: BattleOutcome.win, ratingDelta: 20);
    controller.applyBattleResult(outcome: BattleOutcome.win, ratingDelta: 10);

    expect(controller.state.streak, 2);
    expect(controller.state.bestStreak, 2);
    expect(controller.state.lastDelta, 10);

    await controller.hydrateFromRepository();

    expect(controller.state.playerId, 'user-123');
    expect(controller.state.totalPoints, 860);
    expect(controller.state.wins, 18);
    expect(controller.state.streak, 2);
    expect(controller.state.bestStreak, 2);
    expect(controller.state.lastDelta, 10);
  });
}

class _FakePlayerProgressRepository extends PlayerProgressRepository {
  @override
  Future<PlayerProgressSnapshot> fetchCurrentProgress() async {
    return const PlayerProgressSnapshot(
      playerId: 'user-123',
      displayName: 'Raka',
      totalPoints: 860,
      wins: 18,
      losses: 4,
      draws: 2,
    );
  }
}
