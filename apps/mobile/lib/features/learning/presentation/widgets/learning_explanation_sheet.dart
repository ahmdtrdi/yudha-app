import 'package:flutter/material.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';

class LearningExplanation {
  const LearningExplanation({
    required this.title,
    required this.definition,
    required this.counts,
    required this.doesNotCount,
    required this.formula,
    required this.example,
    required this.evidenceWindow,
  });

  final String title;
  final String definition;
  final String counts;
  final String doesNotCount;
  final String formula;
  final String example;
  final String evidenceWindow;
}

class LearningInfoButton extends StatelessWidget {
  const LearningInfoButton({
    required this.explanation,
    this.color = AppColors.textMuted,
    super.key,
  });

  final LearningExplanation explanation;
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Apa artinya?',
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    padding: EdgeInsets.zero,
    icon: Icon(Icons.info_outline_rounded, size: 18, color: color),
    onPressed: () => showLearningExplanation(context, explanation),
  );
}

Future<void> showLearningExplanation(
  BuildContext context,
  LearningExplanation explanation,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scholarCream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) =>
          ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x3300215A),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                explanation.title,
                style: const TextStyle(
                  color: AppColors.warriorNavy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                explanation.definition,
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _ExplanationBlock(
                icon: Icons.check_circle_outline_rounded,
                title: 'Yang dihitung',
                body: explanation.counts,
              ),
              _ExplanationBlock(
                icon: Icons.remove_circle_outline_rounded,
                title: 'Yang tidak dihitung',
                body: explanation.doesNotCount,
              ),
              _ExplanationBlock(
                icon: Icons.functions_rounded,
                title: 'Rumus',
                body: explanation.formula,
              ),
              _ExplanationBlock(
                icon: Icons.person_outline_rounded,
                title: 'Contoh dari datamu',
                body: explanation.example,
              ),
              _ExplanationBlock(
                icon: Icons.date_range_outlined,
                title: 'Jendela bukti',
                body: explanation.evidenceWindow,
                isLast: true,
              ),
            ],
          ),
    ),
  );
}

class _ExplanationBlock extends StatelessWidget {
  const _ExplanationBlock({
    required this.icon,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.levelUpTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.levelUpTeal),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.warriorNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
