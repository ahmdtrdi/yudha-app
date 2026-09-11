import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_controller.dart';
import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/player_progress_repository.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

void main() {
  test(
    'hydration distinguishes pending, failure and successful empty data',
    () async {
      final repository = _PendingProgressRepository();
      final controller = PlayerProgressController(repository: repository);
      addTearDown(controller.dispose);
      final first = controller.hydrateFromRepository();
      expect(controller.state.status, PlayerProgressStatus.loading);
      repository.requests[0].completeError(StateError('offline'));
      await first;
      expect(controller.state.status, PlayerProgressStatus.error);
      expect(controller.state.errorMessage, isNotEmpty);
      final retry = controller.hydrateFromRepository();
      expect(controller.state.status, PlayerProgressStatus.loading);
      expect(controller.state.errorMessage, isNull);
      repository.requests[1].complete(
        await _FakePlayerProgressRepository().fetchCurrentProgress(),
      );
      await retry;
      expect(controller.state.status, PlayerProgressStatus.ready);
      expect(controller.state.dailyMissions, isEmpty);
      expect(controller.state.errorMessage, isNull);
    },
  );

  test(
    'an older request cannot overwrite the latest hydration result',
    () async {
      final repository = _PendingProgressRepository();
      final controller = PlayerProgressController(repository: repository);
      addTearDown(controller.dispose);
      final old = controller.hydrateFromRepository();
      final latest = controller.hydrateFromRepository();
      repository.requests[1].complete(
        await _FakePlayerProgressRepository().fetchCurrentProgress(),
      );
      await latest;
      repository.requests[0].completeError(StateError('outdated failure'));
      await old;
      expect(controller.state.status, PlayerProgressStatus.ready);
      expect(controller.state.playerId, 'user-123');
    },
  );

  test('disposing during hydration does not publish late state', () async {
    final repository = _PendingProgressRepository();
    final controller = PlayerProgressController(repository: repository);
    final pending = controller.hydrateFromRepository();
    controller.dispose();
    repository.requests.single.complete(
      await _FakePlayerProgressRepository().fetchCurrentProgress(),
    );
    await expectLater(pending, completes);
  });

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

  test('hydrate replaces local streak fields with server values', () async {
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
    expect(controller.state.streak, 0);
    expect(controller.state.bestStreak, 0);
    expect(controller.state.lastDelta, 10);
  });
}

class _PendingProgressRepository extends PlayerProgressRepository {
  final requests = <Completer<PlayerProgressSnapshot>>[];
  @override
  Future<PlayerProgressSnapshot> fetchCurrentProgress() {
    final request = Completer<PlayerProgressSnapshot>();
    requests.add(request);
    return request.future;
  }
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
