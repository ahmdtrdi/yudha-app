import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/gamification/data/models/player_progress_snapshot.dart';
import 'package:yudha_mobile/features/gamification/data/repositories/player_progress_repository.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

class PlayerProgressController extends StateNotifier<PlayerProgress> {
  PlayerProgressController({
    PlayerProgressRepository? repository,
    bool shouldHydrate = false,
    void Function(String displayName)? onDisplayNameHydrated,
  }) : _repository = repository,
       _onDisplayNameHydrated = onDisplayNameHydrated,
       super(PlayerProgress.initial()) {
    if (shouldHydrate && repository != null) {
      unawaited(hydrateFromRepository());
    }
  }

  final PlayerProgressRepository? _repository;
  final void Function(String displayName)? _onDisplayNameHydrated;

  void setDisplayName(String displayName) {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = state.copyWith(displayName: trimmed);
  }

  void applyBattleResult({
    required BattleOutcome outcome,
    int ratingDelta = 0,
  }) {
    if (outcome == BattleOutcome.inProgress) {
      return;
    }

    final int updatedPoints = (state.totalPoints + ratingDelta).clamp(0, 99999);
    final int updatedWins = state.wins + (outcome == BattleOutcome.win ? 1 : 0);
    final int updatedLosses =
        state.losses + (outcome == BattleOutcome.lose ? 1 : 0);
    final int updatedDraws =
        state.draws + (outcome == BattleOutcome.draw ? 1 : 0);

    final int nextStreak = switch (outcome) {
      BattleOutcome.win => state.streak + 1,
      BattleOutcome.lose => 0,
      BattleOutcome.draw => state.streak,
      BattleOutcome.inProgress => state.streak,
    };

    state = state.copyWith(
      totalPoints: updatedPoints,
      wins: updatedWins,
      losses: updatedLosses,
      draws: updatedDraws,
      streak: nextStreak,
      bestStreak: nextStreak > state.bestStreak ? nextStreak : state.bestStreak,
      lastDelta: ratingDelta,
    );
  }

  Future<void> hydrateFromRepository() async {
    if (_repository == null) {
      return;
    }

    try {
      final PlayerProgressSnapshot snapshot = await _repository
          .fetchCurrentProgress();
      state = state.mergeSnapshot(snapshot);
      _onDisplayNameHydrated?.call(snapshot.displayName);
    } catch (_) {
      // Keep local fallback state when the profile API is temporarily unavailable.
    }
  }
}
