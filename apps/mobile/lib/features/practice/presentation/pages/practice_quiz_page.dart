import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/core/theme/app_typography.dart';
import 'package:yudha_mobile/features/ads/application/ad_placement_providers.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/notifications/presentation/notification_permission_prompt.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_hint_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_session.dart';

class PracticeQuizPage extends ConsumerStatefulWidget {
  const PracticeQuizPage({super.key});

  @override
  ConsumerState<PracticeQuizPage> createState() => _PracticeQuizPageState();
}

class _PracticeQuizPageState extends ConsumerState<PracticeQuizPage> {
  final ResultExitAdSession _adSession = ResultExitAdSession();
  bool _allowCompletedPop = false;

  void _exitCompletedResult() {
    final PracticeState state = ref.read(practiceControllerProvider);
    if (state.status == PracticeViewStatus.completed &&
        state.questions.length == 5) {
      _adSession.triggerOnce(
        ref.read(adPlacementGateProvider),
        AdPlacement.practiceResultExit,
      );
    }
    setState(() => _allowCompletedPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
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
    final bool isSubmitted = state.isCurrentQuestionSubmitted;
    final bool isCompleted = state.status == PracticeViewStatus.completed;
    final bool isSubmitting = state.status == PracticeViewStatus.submitting;
    final bool hasSelection = state.selectedOptionId != null;
    final _QuizActionKind actionKind = !isSubmitted
        ? _QuizActionKind.confirm
        : isCompleted
        ? _QuizActionKind.complete
        : _QuizActionKind.next;

    return PopScope(
      canPop: !isCompleted || _allowCompletedPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && isCompleted) _exitCompletedResult();
      },
      child: Scaffold(
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
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                Text(
                  question.timeLimitSeconds > 0
                      ? '${question.timeLimitSeconds}s'
                      : '--',
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
                      if (isCompleted && state.summary != null) ...<Widget>[
                        _SessionSummaryCard(summary: state.summary!),
                        const SizedBox(height: 16),
                      ],
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
                      if (!question.hintAvailable)
                        const SizedBox.shrink()
                      else if (state.hintState == PracticeHintState.unlocked)
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
                                    style: GoogleFonts.dmSans(
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
                          onTap: state.hintState == PracticeHintState.loading
                              ? null
                              : () async {
                                  final bool loaded = await controller
                                      .unlockHint();
                                  if (!loaded && context.mounted) {
                                    final String message =
                                        ref
                                            .read(practiceControllerProvider)
                                            .errorMessage ??
                                        'Petunjuk gagal dimuat.';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  }
                                },
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
                                    if (state.hintState ==
                                        PracticeHintState.loading)
                                      const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.help_outline,
                                        color: AppColors.fireGold,
                                        size: 18,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      state.hintState ==
                                              PracticeHintState.loading
                                          ? 'Memuat petunjuk'
                                          : 'Lihat petunjuk',
                                      style: TextStyle(
                                        color: AppColors.fireGold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Opsional',
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
                        final bool isSelected =
                            state.selectedOptionId == option.id;
                        final bool isCorrectOption =
                            isSubmitted &&
                            state.correctOptionIndex == option.index;
                        final bool isWrongSelection =
                            isSubmitted && isSelected && !isCorrectOption;
                        final String letter = String.fromCharCode(
                          65 + i,
                        ); // A, B, C...

                        // State colors
                        final Color borderColor = isCorrectOption
                            ? AppColors.levelUpTeal
                            : isWrongSelection
                            ? Colors.redAccent
                            : isSelected
                            ? AppColors.warriorNavy
                            : AppColors.warriorNavy.withAlpha(20);
                        final Color bgColor =
                            isSelected || isCorrectOption || isWrongSelection
                            ? borderColor.withAlpha(18)
                            : Colors.white;
                        final Color letterBgColor =
                            isSelected || isCorrectOption
                            ? borderColor
                            : AppColors.surfaceLight;
                        final Color letterColor = isSelected || isCorrectOption
                            ? Colors.white
                            : AppColors.textMuted;
                        final FontWeight textWeight = isSelected
                            ? FontWeight.w800
                            : FontWeight.w600;

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
                                      style: GoogleFonts.jetBrainsMono(
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
                      if (isSubmitted &&
                          (state.answerExplanation ?? '')
                              .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        _AnswerExplanation(
                          explanation: state.answerExplanation!,
                        ),
                      ],
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
                  height: 62,
                  child: _ClayQuizActionButton(
                    kind: actionKind,
                    isLoading: isSubmitting,
                    onPressed: hasSelection && !isSubmitting
                        ? () async {
                            if (!isSubmitted) {
                              final bool submitted = await controller
                                  .submitCurrentAnswer();
                              if (submitted &&
                                  ref.read(practiceControllerProvider).status ==
                                      PracticeViewStatus.completed) {
                                await ref
                                    .read(playerProgressProvider.notifier)
                                    .hydrateFromRepository();
                                await ref
                                    .read(learningControllerProvider.notifier)
                                    .load();
                                if (context.mounted) {
                                  await maybeShowNotificationPermissionPrompt(
                                    context,
                                    ref,
                                  );
                                }
                              }
                              if (!submitted && context.mounted) {
                                final String message =
                                    ref
                                        .read(practiceControllerProvider)
                                        .errorMessage ??
                                    'Jawaban gagal dikirim.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            } else {
                              if (isCompleted) {
                                _exitCompletedResult();
                              } else {
                                controller.nextQuestion();
                              }
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _QuizActionKind { confirm, next, complete }

class _ClayQuizActionButton extends StatefulWidget {
  const _ClayQuizActionButton({
    required this.kind,
    required this.isLoading,
    required this.onPressed,
  });

  final _QuizActionKind kind;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  State<_ClayQuizActionButton> createState() => _ClayQuizActionButtonState();
}

class _ClayQuizActionButtonState extends State<_ClayQuizActionButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final _QuizActionPalette palette = _isEnabled
        ? _QuizActionPalette.forKind(widget.kind)
        : _QuizActionPalette.disabled;
    final double depth = _isEnabled ? 6 : 3;
    final double pressedOffset = _isPressed ? 4 : 0;

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: _label,
      child: InkWell(
        key: ValueKey<String>('practice-action-${widget.kind.name}'),
        onTap: widget.onPressed,
        onHighlightChanged: _isEnabled
            ? (bool value) => setState(() => _isPressed = value)
            : null,
        borderRadius: BorderRadius.circular(17),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              top: depth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.baseColor,
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              top: pressedOffset,
              right: 0,
              bottom: depth - pressedOffset,
              left: 0,
              child: DecoratedBox(
                key: ValueKey<String>(
                  'practice-action-surface-${widget.kind.name}',
                ),
                decoration: BoxDecoration(
                  color: palette.frontColor,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.foregroundColor,
                          ),
                        )
                      : Text(
                          _label,
                          style: AppTypography.heading(
                            color: palette.foregroundColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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

  String get _label => switch (widget.kind) {
    _QuizActionKind.confirm => 'KONFIRMASI',
    _QuizActionKind.next => 'LANJUT',
    _QuizActionKind.complete => 'SELESAI',
  };
}

class _QuizActionPalette {
  const _QuizActionPalette({
    required this.frontColor,
    required this.baseColor,
    required this.foregroundColor,
  });

  final Color frontColor;
  final Color baseColor;
  final Color foregroundColor;

  static const _QuizActionPalette disabled = _QuizActionPalette(
    frontColor: Color(0xFFEAE6DE),
    baseColor: Color(0xFFCFC8BC),
    foregroundColor: Color(0xFF858897),
  );

  factory _QuizActionPalette.forKind(_QuizActionKind kind) {
    return switch (kind) {
      _QuizActionKind.confirm => const _QuizActionPalette(
        frontColor: AppColors.fireGold,
        baseColor: Color(0xFFD97928),
        foregroundColor: Color(0xFF442B1D),
      ),
      _QuizActionKind.next => const _QuizActionPalette(
        frontColor: Color(0xFF0066DE),
        baseColor: Color(0xFF000180),
        foregroundColor: Colors.white,
      ),
      _QuizActionKind.complete => const _QuizActionPalette(
        frontColor: AppColors.growthLime,
        baseColor: Color(0xFF69AB2D),
        foregroundColor: Color(0xFF173A20),
      ),
    };
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({required this.summary});

  final PracticeSessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warriorNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'SESI SELESAI',
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _SummaryMetric(
                value: '${summary.accuracy.round()}%',
                label: 'Akurasi',
              ),
              _SummaryMetric(
                value: '${summary.correctCount}/${summary.totalQuestions}',
                label: 'Benar',
              ),
              _SummaryMetric(
                value: summary.totalScore.toString(),
                label: 'Skor',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: AppColors.fireGold,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(190),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AnswerExplanation extends StatelessWidget {
  const _AnswerExplanation({required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.levelUpTeal.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'PEMBAHASAN',
            style: TextStyle(
              color: AppColors.levelUpTeal,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            style: const TextStyle(
              color: AppColors.textStrong,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
