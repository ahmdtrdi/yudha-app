import 'package:flutter/material.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_state_machine.dart';

class QuestionPickCard extends StatelessWidget {
  const QuestionPickCard({
    required this.question,
    required this.onPick,
    super.key,
  });

  final BattleQuestion question;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final bool isDamage = question.effect == QuestionEffect.damage;
    final Color accent = isDamage ? Colors.red.shade600 : Colors.green.shade600;
    final int impact = BattleStateMachine.impactFromWeight(question.weight);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Chip(
                  label: Text(isDamage ? 'Damage' : 'Heal'),
                  backgroundColor: accent.withAlpha(41),
                  side: BorderSide(color: accent.withAlpha(115)),
                ),
                const SizedBox(width: 8),
                Chip(label: Text('Bobot ${question.weight}')),
                const Spacer(),
                Text(
                  'Impact $impact',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.prompt,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.bolt),
                label: const Text('Pilih Soal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
