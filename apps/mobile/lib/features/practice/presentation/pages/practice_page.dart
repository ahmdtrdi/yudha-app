import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/practice/application/practice_providers.dart';
import 'package:yudha_mobile/features/practice/application/practice_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_hint_state.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_option.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_question.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

class PracticePage extends ConsumerWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PracticeState state = ref.watch(practiceControllerProvider);
    final controller = ref.read(practiceControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Session')),
      body: switch (state.status) {
        PracticeViewStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PracticeViewStatus.error => _ErrorState(
          message: state.errorMessage ?? 'Failed to load practice session.',
          onRetry: controller.reload,
        ),
        PracticeViewStatus.ready || PracticeViewStatus.completed => _PracticeBody(
          state: state,
          onRefresh: controller.reload,
          onStartQuestionOfDay: controller.startQuestionOfDay,
          onSelectTopic: controller.selectTopic,
          onSelectOption: controller.selectOption,
          onSubmit: controller.submitCurrentAnswer,
          onNext: controller.nextQuestion,
          onRestart: controller.restartSession,
          onWatchAdHint: controller.setHintToWatchAd,
          onBuyHint: controller.setHintToBuy,
          onUnlockHint: controller.unlockHint,
          onCancelHintUnlock: controller.resetHintState,
        ),
      },
    );
  }
}

class _PracticeBody extends StatelessWidget {
  const _PracticeBody({
    required this.state,
    required this.onRefresh,
    required this.onStartQuestionOfDay,
    required this.onSelectTopic,
    required this.onSelectOption,
    required this.onSubmit,
    required this.onNext,
    required this.onRestart,
    required this.onWatchAdHint,
    required this.onBuyHint,
    required this.onUnlockHint,
    required this.onCancelHintUnlock,
  });

  final PracticeState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onStartQuestionOfDay;
  final Future<void> Function(String topicId) onSelectTopic;
  final void Function(String optionId) onSelectOption;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onWatchAdHint;
  final VoidCallback onBuyHint;
  final VoidCallback onUnlockHint;
  final VoidCallback onCancelHintUnlock;

  @override
  Widget build(BuildContext context) {
    final PracticeQuestion? question = state.currentQuestion;
    final bool hasQuestion = question != null;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _QuestionOfDayCard(
            questionOfDay: state.questionOfDay,
            onStart: onStartQuestionOfDay,
          ),
          const SizedBox(height: 12),
          _TopicSelector(
            topics: state.topics,
            selectedTopicId: state.selectedTopicId,
            onTopicSelected: onSelectTopic,
          ),
          const SizedBox(height: 12),
          if (hasQuestion)
            _QuestionCard(
              question: question,
              index: state.currentQuestionIndex,
              total: state.questions.length,
              selectedOptionId: state.selectedOptionId,
              isSubmitted: state.isCurrentQuestionSubmitted,
              isCompleted: state.status == PracticeViewStatus.completed,
              onOptionTap: onSelectOption,
              onSubmit: onSubmit,
              onNext: onNext,
              onRestart: onRestart,
            )
          else
            const _EmptyQuestionCard(),
          if (hasQuestion) ...<Widget>[
            const SizedBox(height: 12),
            _HintCard(
              hintState: state.hintState,
              hintText: question.hint,
              onWatchAdHint: onWatchAdHint,
              onBuyHint: onBuyHint,
              onUnlockHint: onUnlockHint,
              onCancelHintUnlock: onCancelHintUnlock,
            ),
          ],
          if (state.status == PracticeViewStatus.completed) ...<Widget>[
            const SizedBox(height: 12),
            _SummaryCard(
              score: state.correctAnswers,
              total: state.questions.length,
              onRestart: onRestart,
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _QuestionOfDayCard extends StatelessWidget {
  const _QuestionOfDayCard({required this.questionOfDay, required this.onStart});

  final PracticeQuestion? questionOfDay;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0E4AAE), AppColors.warriorNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Question of the Day',
            style: TextStyle(
              color: AppColors.scholarCream.withAlpha(235),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            questionOfDay?.prompt ?? 'Daily challenge is preparing...',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.scholarCream,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Topic: ${questionOfDay?.topicName ?? '-'}',
            style: TextStyle(
              color: AppColors.scholarCream.withAlpha(220),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: questionOfDay == null ? null : onStart,
            icon: const Icon(Icons.bolt),
            label: const Text('Start Daily Challenge'),
          ),
        ],
      ),
    );
  }
}

class _TopicSelector extends StatelessWidget {
  const _TopicSelector({
    required this.topics,
    required this.selectedTopicId,
    required this.onTopicSelected,
  });

  final List<PracticeTopic> topics;
  final String? selectedTopicId;
  final Future<void> Function(String topicId) onTopicSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Choose Topic',
            style: TextStyle(
              color: AppColors.warriorNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topics.map((PracticeTopic topic) {
              final bool isSelected = topic.id == selectedTopicId;
              return ChoiceChip(
                label: Text(topic.isLocked ? '${topic.name} (Locked)' : topic.name),
                selected: isSelected,
                onSelected: topic.isLocked
                    ? null
                    : (bool selected) {
                        if (selected) {
                          onTopicSelected(topic.id);
                        }
                      },
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.total,
    required this.selectedOptionId,
    required this.isSubmitted,
    required this.isCompleted,
    required this.onOptionTap,
    required this.onSubmit,
    required this.onNext,
    required this.onRestart,
  });

  final PracticeQuestion question;
  final int index;
  final int total;
  final String? selectedOptionId;
  final bool isSubmitted;
  final bool isCompleted;
  final void Function(String optionId) onOptionTap;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final PracticeOption? correctOption = question.correctOption;
    final bool isLast = index == total - 1;
    final bool selectedCorrectly =
        selectedOptionId != null &&
        question.options.any(
          (PracticeOption option) =>
              option.id == selectedOptionId && option.isCorrect,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Question ${index + 1} / $total',
                style: const TextStyle(
                  color: AppColors.warriorNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                question.topicName,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.prompt,
            style: const TextStyle(
              color: AppColors.textStrong,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...question.options.map((PracticeOption option) {
            final bool isSelected = selectedOptionId == option.id;
            final bool showCorrect = isSubmitted && option.isCorrect;
            final bool showIncorrect = isSubmitted && isSelected && !option.isCorrect;

            Color borderColor = AppColors.warriorNavy.withAlpha(35);
            Color fillColor = Colors.white;

            if (isSelected) {
              borderColor = AppColors.warriorNavy;
              fillColor = const Color(0xFFEFF4FF);
            }
            if (showCorrect) {
              borderColor = AppColors.levelUpTeal;
              fillColor = const Color(0xFFEAF8FA);
            }
            if (showIncorrect) {
              borderColor = AppColors.fireGold;
              fillColor = const Color(0xFFFFF4E9);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: isSubmitted ? null : () => onOptionTap(option.id),
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: isSelected
                            ? AppColors.warriorNavy
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          option.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (isSubmitted) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              selectedCorrectly
                  ? 'Correct answer. Great work.'
                  : 'Not quite. Correct: ${correctOption?.label ?? '-'}',
              style: TextStyle(
                color: selectedCorrectly ? AppColors.levelUpTeal : AppColors.fireGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!isSubmitted)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selectedOptionId == null ? null : onSubmit,
                child: const Text('Submit Answer'),
              ),
            )
          else if (!isLast)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onNext,
                child: const Text('Next Question'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isCompleted ? onRestart : onNext,
                child: Text(isCompleted ? 'Restart Session' : 'Finish Session'),
              ),
            ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.hintState,
    required this.hintText,
    required this.onWatchAdHint,
    required this.onBuyHint,
    required this.onUnlockHint,
    required this.onCancelHintUnlock,
  });

  final PracticeHintState hintState;
  final String hintText;
  final VoidCallback onWatchAdHint;
  final VoidCallback onBuyHint;
  final VoidCallback onUnlockHint;
  final VoidCallback onCancelHintUnlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Hint',
            style: TextStyle(
              color: AppColors.warriorNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          switch (hintState) {
            PracticeHintState.locked => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Hint is locked. Choose unlock method:'),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onWatchAdHint,
                        icon: const Icon(Icons.ondemand_video),
                        label: const Text('Watch Ad'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onBuyHint,
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: const Text('Buy Hint'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            PracticeHintState.watchAd => _PendingHintUnlock(
              label: 'Ad reward pending. Complete ad to unlock this hint.',
              actionLabel: 'Unlock Hint',
              onUnlock: onUnlockHint,
              onCancel: onCancelHintUnlock,
            ),
            PracticeHintState.buy => _PendingHintUnlock(
              label: 'Purchase pending. Confirm purchase to unlock this hint.',
              actionLabel: 'Unlock Hint',
              onUnlock: onUnlockHint,
              onCancel: onCancelHintUnlock,
            ),
            PracticeHintState.unlocked => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.levelUpTeal.withAlpha(100)),
              ),
              child: Text(
                hintText,
                style: const TextStyle(
                  color: AppColors.textStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _PendingHintUnlock extends StatelessWidget {
  const _PendingHintUnlock({
    required this.label,
    required this.actionLabel,
    required this.onUnlock,
    required this.onCancel,
  });

  final String label;
  final String actionLabel;
  final VoidCallback onUnlock;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: onUnlock,
                child: Text(actionLabel),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.score,
    required this.total,
    required this.onRestart,
  });

  final int score;
  final int total;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final int percentage = total == 0 ? 0 : ((score / total) * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.levelUpTeal.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Session Complete',
            style: TextStyle(
              color: AppColors.warriorNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Score: $score / $total ($percentage%)',
            style: const TextStyle(
              color: AppColors.textStrong,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Topic'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.fireGold,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyQuestionCard extends StatelessWidget {
  const _EmptyQuestionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(30)),
      ),
      child: const Text(
        'No practice questions available right now.',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
