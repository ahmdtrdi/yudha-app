import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_controller.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

void main() {
  test('applyBattleResult updates points and streak on win', () {
    final PlayerProgressController controller = PlayerProgressController();
    final int startingPoints = controller.state.totalPoints;

    controller.applyBattleResult(outcome: BattleOutcome.win, ratingDelta: 20);

    expect(controller.state.totalPoints, startingPoints + 20);
    expect(controller.state.streak, 1);
    expect(controller.state.wins, 13);
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
    expect(controller.state.losses, 7);
    expect(controller.state.lastDelta, -99999);
  });
}
