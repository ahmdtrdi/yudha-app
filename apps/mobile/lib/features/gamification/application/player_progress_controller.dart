import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

class PlayerProgressController extends StateNotifier<PlayerProgress> {
  PlayerProgressController() : super(PlayerProgress.initial());

  void applyBattleResult({
    required BattleOutcome outcome,
    required int ratingDelta,
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
}
