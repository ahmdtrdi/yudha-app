import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/pvp/application/battle_controller.dart';
import 'package:yudha_mobile/features/pvp/application/battle_providers.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';
import 'package:yudha_mobile/features/pvp/presentation/widgets/battle_health_panel.dart';
import 'package:yudha_mobile/features/pvp/presentation/widgets/question_pick_card.dart';

class PvpPage extends ConsumerWidget {
  const PvpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BattleState state = ref.watch(battleControllerProvider);
    final BattleController controller = ref.read(
      battleControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('PvP Battle')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: <Widget>[
              _ModeSelector(
                currentMode: state.mode,
                disabled: state.isBattleActive || state.isLoading,
                onChanged: controller.setMode,
              ),
              const SizedBox(height: 12),
              if (state.statusMessage != null)
                _StatusBanner(text: state.statusMessage!),
              if (state.errorMessage != null)
                _StatusBanner(text: state.errorMessage!, isError: true),
              const SizedBox(height: 8),
              Expanded(
                child: _buildBattleContent(
                  context: context,
                  state: state,
                  controller: controller,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBattleContent({
    required BuildContext context,
    required BattleState state,
    required BattleController controller,
  }) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.phase == BattlePhase.preBattle) {
      return _PreBattleSection(
        mode: state.mode,
        onStart: controller.startBattle,
      );
    }

    if (state.phase == BattlePhase.finished) {
      return _ResultSection(
        state: state,
        onReplay: controller.startBattle,
        onReset: controller.resetBattle,
      );
    }

    return _InBattleSection(
      state: state,
      onPickQuestion: (BattleQuestion question) {
        _showAnswerSheet(
          context: context,
          question: question,
          onAnswerSelected: (int selectedIndex) {
            controller.answerQuestion(
              questionId: question.id,
              selectedOptionIndex: selectedIndex,
            );
          },
        );
      },
    );
  }

  void _showAnswerSheet({
    required BuildContext context,
    required BattleQuestion question,
    required ValueChanged<int> onAnswerSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  question.prompt,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...List<Widget>.generate(
                  question.options.length,
                  (int index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        onAnswerSelected(index);
                        Navigator.of(context).pop();
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(question.options[index]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.currentMode,
    required this.disabled,
    required this.onChanged,
  });

  final BattleMode currentMode;
  final bool disabled;
  final ValueChanged<BattleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BattleMode>(
      segments: const <ButtonSegment<BattleMode>>[
        ButtonSegment<BattleMode>(
          value: BattleMode.bot,
          icon: Icon(Icons.smart_toy_outlined),
          label: Text('Bot'),
        ),
        ButtonSegment<BattleMode>(
          value: BattleMode.online,
          icon: Icon(Icons.person_search_outlined),
          label: Text('Player'),
        ),
      ],
      selected: <BattleMode>{currentMode},
      onSelectionChanged: disabled
          ? null
          : (Set<BattleMode> modes) {
              final BattleMode selectedMode = modes.first;
              onChanged(selectedMode);
            },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color background = isError
        ? Colors.red.shade100
        : Colors.blue.shade50;
    final Color foreground = isError
        ? Colors.red.shade800
        : Colors.blue.shade800;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PreBattleSection extends StatelessWidget {
  const _PreBattleSection({required this.mode, required this.onStart});

  final BattleMode mode;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  mode == BattleMode.bot
                      ? 'Mode: Lawan Bot'
                      : 'Mode: Matchmaking Player',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilih mode lalu tekan mulai untuk memulai battle. '
                  'Soal memiliki bobot damage atau heal yang berbeda.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Mulai Battle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InBattleSection extends StatelessWidget {
  const _InBattleSection({required this.state, required this.onPickQuestion});

  final BattleState state;
  final ValueChanged<BattleQuestion> onPickQuestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        BattleHealthPanel(
          playerLabel: 'Kamu',
          playerHp: state.playerHp,
          opponentLabel: state.opponentName,
          opponentHp: state.opponentHp,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Point Kamu: ${state.playerPoints}'),
            Text('Point ${state.opponentName}: ${state.opponentPoints}'),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: state.availableQuestions.length,
            itemBuilder: (BuildContext context, int index) {
              final BattleQuestion question = state.availableQuestions[index];
              return QuestionPickCard(
                question: question,
                onPick: () => onPickQuestion(question),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.state,
    required this.onReplay,
    required this.onReset,
  });

  final BattleState state;
  final VoidCallback onReplay;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final String resultTitle = switch (state.outcome) {
      BattleOutcome.win => 'Kamu Menang!',
      BattleOutcome.lose => 'Kamu Kalah',
      BattleOutcome.draw => 'Hasil Seri',
      BattleOutcome.inProgress => 'Battle Berjalan',
    };

    final String ratingText = state.ratingDelta >= 0
        ? '+${state.ratingDelta} point'
        : '${state.ratingDelta} point';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  resultTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Perubahan point: $ratingText'),
                const SizedBox(height: 8),
                Text(
                  'Skor akhir: ${state.playerPoints} vs ${state.opponentPoints}',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: onReplay,
                      icon: const Icon(Icons.replay),
                      label: const Text('Main Lagi'),
                    ),
                    OutlinedButton(
                      onPressed: onReset,
                      child: const Text('Kembali ke Pre-Battle'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
