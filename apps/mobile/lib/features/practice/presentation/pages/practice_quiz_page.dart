import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_hint_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';

class PracticeQuizPage extends ConsumerWidget {
  const PracticeQuizPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceControllerProvider);
    final controller = ref.read(practiceControllerProvider.notifier);
    final question = state.currentQuestion;

    if (question == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: const Center(child: Text('No question active.')),
      );
    }

    final int index = state.currentQuestionIndex;
    final int total = state.questions.length;
    final bool isLast = index == total - 1;
    final bool isSubmitted = state.isCurrentQuestionSubmitted;
    final bool isCompleted = state.status == PracticeViewStatus.completed;
    final bool hasSelection = state.selectedOptionId != null;

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        backgroundColor: AppColors.warriorNavy,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: Text(
                    '${index + 1} / $total   ${question.topicName.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const Text(
                '38s',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: total > 0 ? (index + 1) / total : 0.0,
            color: AppColors.fireGold,
            backgroundColor: Colors.white.withAlpha(50),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Question Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.warriorNavy.withAlpha(10),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            question.prompt,
                            style: const TextStyle(
                              color: AppColors.textStrong,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            // Extract a pseudo-subtitle if available, else generic. For prototype, we'll map description if present.
                            question.topicName,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hint Section
                    if (state.hintState == PracticeHintState.unlocked)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF7E7), // Solid cream
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.fireGold),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.info_outline,
                                  color: AppColors.fireGold,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PETUNJUK',
                                  style: GoogleFonts.orbitron(
                                    color: AppColors.fireGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              question.hint,
                              style: const TextStyle(
                                color: AppColors.textStrong,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => controller.unlockHint(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF7E7).withAlpha(150),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.fireGold.withAlpha(150),
                              strokeAlign: BorderSide.strokeAlignInside,
                            ), // We could use a CustomPainter for dashed, but solid thin border simulates it well enough for native standard UI
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.help_outline,
                                    color: AppColors.fireGold,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Lihat petunjuk',
                                    style: TextStyle(
                                      color: AppColors.fireGold,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Text(
                                '-5 poin',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Options List
                    ...List<Widget>.generate(question.options.length, (i) {
                      final PracticeOption option = question.options[i];
                      final bool isSelected = state.selectedOptionId == option.id;
                      final String letter = String.fromCharCode(65 + i); // A, B, C...

                      // State colors
                      final Color borderColor = isSelected
                          ? AppColors.warriorNavy
                          : AppColors.warriorNavy.withAlpha(20);
                      final Color bgColor = isSelected
                          ? AppColors.warriorNavy.withAlpha(10)
                          : Colors.white;
                      final Color letterBgColor = isSelected
                          ? AppColors.warriorNavy
                          : AppColors.surfaceLight;
                      final Color letterColor =
                          isSelected ? Colors.white : AppColors.textMuted;
                      final FontWeight textWeight =
                          isSelected ? FontWeight.w800 : FontWeight.w600;

                      // Note: We don't render "showCorrect" during selection in the exact exact Figma reference, it just highlights the selected option for KONFIRMASI.
                      // We will keep it simple and just show selected state until submitted.

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: isSubmitted
                              ? null
                              : () => controller.selectOption(option.id),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: letterBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    letter,
                                    style: GoogleFonts.orbitron(
                                      color: letterColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: TextStyle(
                                      color: AppColors.textStrong,
                                      fontWeight: textWeight,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.scholarCream,
                border: Border(
                  top: BorderSide(color: AppColors.warriorNavy.withAlpha(10)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: hasSelection
                      ? () {
                          if (!isSubmitted) {
                            controller.submitCurrentAnswer();
                          } else {
                            if (isCompleted) {
                              context.pop(); // Return to dashboard
                            } else {
                              controller.nextQuestion();
                            }
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warriorNavy,
                    disabledBackgroundColor:
                        AppColors.warriorNavy.withAlpha(15),
                    disabledForegroundColor: AppColors.warriorNavy.withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    !isSubmitted
                        ? 'KONFIRMASI'
                        : (isCompleted ? 'SELESAI' : 'LANJUT'),
                    style: GoogleFonts.orbitron(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
