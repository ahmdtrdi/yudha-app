import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';

class BattleQuestion {
  const BattleQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
    required this.weight,
    required this.effect,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctOptionIndex;
  final int weight;
  final QuestionEffect effect;
}
