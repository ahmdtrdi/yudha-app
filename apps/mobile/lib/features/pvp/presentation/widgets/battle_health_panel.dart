import 'package:flutter/material.dart';

class BattleHealthPanel extends StatelessWidget {
  const BattleHealthPanel({
    required this.playerLabel,
    required this.playerHp,
    required this.opponentLabel,
    required this.opponentHp,
    super.key,
  });

  final String playerLabel;
  final int playerHp;
  final String opponentLabel;
  final int opponentHp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _HealthRow(
              label: playerLabel,
              hp: playerHp,
              barColor: Colors.green.shade600,
            ),
            const SizedBox(height: 14),
            _HealthRow(
              label: opponentLabel,
              hp: opponentHp,
              barColor: Colors.red.shade600,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.hp,
    required this.barColor,
  });

  final String label;
  final int hp;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final double value = hp.clamp(0, 100) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text('$hp%'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 12,
            backgroundColor: barColor.withAlpha(36),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
