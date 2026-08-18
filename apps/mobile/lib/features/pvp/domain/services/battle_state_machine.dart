import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

abstract final class BattleStateMachine {
  static int effectFromCombo(int comboLevel) {
    return comboLevel.clamp(1, 3) * 5;
  }

  static BattleVisualEffect visualEffectForCategory(String category) {
    return switch (category.toLowerCase()) {
      'verbal' => BattleVisualEffect.wizard,
      'logika' => BattleVisualEffect.robot,
      'twk' => BattleVisualEffect.heal,
      _ => BattleVisualEffect.cannon,
    };
  }

  static String attackLabel(String category) {
    return switch (category.toLowerCase()) {
      'verbal' => 'Wizard Bolt',
      'logika' => 'Robot Slam',
      'numerik' => 'Cannon Strike',
      _ => 'Serangan',
    };
  }
}
