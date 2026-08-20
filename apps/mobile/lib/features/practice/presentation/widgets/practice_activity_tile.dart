import 'package:flutter/material.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';

class PracticeActivityTile extends StatelessWidget {
  const PracticeActivityTile({required this.activity, super.key});

  final PracticeRecentActivity activity;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (activity.type) {
      PracticeRecentActivityType.insight => Icons.lightbulb_outline,
      PracticeRecentActivityType.interview => Icons.record_voice_over_rounded,
      PracticeRecentActivityType.quiz => Icons.article_outlined,
    };
    final Color scoreColor = switch (activity.type) {
      PracticeRecentActivityType.insight => AppColors.fireGold,
      PracticeRecentActivityType.interview => AppColors.warriorNavy,
      PracticeRecentActivityType.quiz => AppColors.levelUpTeal,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(20)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.warriorNavy.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.scholarCream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.warriorNavy, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  activity.title,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity.scoreLabel,
            style: TextStyle(
              color: scoreColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
