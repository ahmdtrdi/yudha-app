import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/pvp/application/battle_controller.dart';
import 'package:yudha_mobile/features/pvp/application/battle_providers.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_state_machine.dart';

const String _enemyAvatarAsset = 'assets/game/red_avatar.png';
const String _playerAvatarAsset = 'assets/game/blue_avatar.png';
const String _enemyMainTowerAsset = 'assets/game/red_maintower.png';
const String _enemyMiniTowerAsset = 'assets/game/red_minitower.png';
const String _playerMainTowerAsset = 'assets/game/blue_maintower.png';
const String _playerMiniTowerAsset = 'assets/game/blue_minitower.png';
const String _enemyCardBackAsset = 'assets/game/enemy_card.png';
const String _tiuCardAsset = 'assets/game/tiu_card.png';
const String _twkCardAsset = 'assets/game/twk_card.png';

class PvpPage extends ConsumerWidget {
  const PvpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BattleState state = ref.watch(battleControllerProvider);
    final BattleController controller = ref.read(
      battleControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Battle Arena')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
  const _StatusBanner({
    required this.text,
    this.isError = false,
    this.dark = false,
  });

  final String text;
  final bool isError;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color background = dark
        ? (isError ? const Color(0xFF5D1F2A) : const Color(0xFF173763))
        : (isError ? const Color(0xFFFFECE8) : const Color(0xFFE9F7FA));
    final Color foreground = dark
        ? AppColors.scholarCream
        : AppColors.textStrong;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isError ? AppColors.fireGold : AppColors.levelUpTeal)
              .withAlpha(170),
        ),
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
        _HudStrip(
          isEnemy: true,
          playerName: state.opponentName,
          hp: state.opponentHp,
          points: state.opponentPoints,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _ArenaPanel(
            playerHp: state.playerHp,
            opponentHp: state.opponentHp,
            statusMessage:
                state.statusMessage ?? 'Pilih kartu untuk menyerang atau heal.',
          ),
        ),
        const SizedBox(height: 6),
        _HudStrip(
          isEnemy: false,
          playerName: 'Kamu',
          hp: state.playerHp,
          points: state.playerPoints,
          questions: state.availableQuestions,
          onPickQuestion: onPickQuestion,
        ),
      ],
    );
  }
}

class _HudStrip extends StatelessWidget {
  const _HudStrip({
    required this.isEnemy,
    required this.playerName,
    required this.hp,
    required this.points,
    this.questions = const <BattleQuestion>[],
    this.onPickQuestion,
  });

  final bool isEnemy;
  final String playerName;
  final int hp;
  final int points;
  final List<BattleQuestion> questions;
  final ValueChanged<BattleQuestion>? onPickQuestion;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = isEnemy
        ? const <Color>[Color(0xFF821C1F), Color(0xFF560B13)]
        : const <Color>[Color(0xFF0F2D68), Color(0xFF0B1E47)];
    final int safeHp = hp.clamp(0, 100);
    final String avatarAsset = isEnemy ? _enemyAvatarAsset : _playerAvatarAsset;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        children: <Widget>[
          if (isEnemy) ...<Widget>[
            SizedBox(
              height: 76,
              child: Row(
                children: List<Widget>.generate(
                  4,
                  (int index) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                          image: const DecorationImage(
                            image: AssetImage(_enemyCardBackAsset),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 17,
                backgroundImage: AssetImage(avatarAsset),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 12,
                        color: Colors.black45,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: safeHp / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isEnemy
                                      ? const <Color>[
                                          Color(0xFFAB1E2A),
                                          Color(0xFFFF6666),
                                        ]
                                      : const <Color>[
                                          Color(0xFF1D62D7),
                                          Color(0xFF58B1FF),
                                        ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$safeHp% | $points',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (!isEnemy) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: questions.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  final BattleQuestion question = questions[index];
                  final bool isDamage =
                      question.effect == QuestionEffect.damage;
                  final String cardAsset = isDamage
                      ? (index.isEven ? _twkCardAsset : _tiuCardAsset)
                      : _tiuCardAsset;
                  final int impact = BattleStateMachine.impactFromWeight(
                    question.weight,
                  );
                  return SizedBox(
                    width: 90,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey<String>('question-card-${question.id}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onPickQuestion?.call(question),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                            image: DecorationImage(
                              image: AssetImage(cardAsset),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: <Widget>[
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(170),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    '$impact',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 6,
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  height: 16,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(180),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    question.prompt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArenaPanel extends StatelessWidget {
  const _ArenaPanel({
    required this.playerHp,
    required this.opponentHp,
    required this.statusMessage,
  });

  final int playerHp;
  final int opponentHp;
  final String statusMessage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF5FAE3E), Color(0xFF4C9A35)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(width: 92, color: const Color(0xFFD2AE63)),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF25C6EA),
                    Color(0xFF4CD8FF),
                    Color(0xFF25C6EA),
                  ],
                ),
              ),
            ),
          ),
          _TowerNode(
            alignment: const Alignment(0, -0.38),
            imageAsset: _enemyMainTowerAsset,
            hpValue: (opponentHp * 30).round(),
            hpProgress: opponentHp / 100,
            mainTower: true,
          ),
          _TowerNode(
            alignment: const Alignment(-0.7, -0.16),
            imageAsset: _enemyMiniTowerAsset,
            hpValue: (opponentHp * 15).round(),
            hpProgress: opponentHp / 100,
            mainTower: false,
          ),
          _TowerNode(
            alignment: const Alignment(0.7, -0.16),
            imageAsset: _enemyMiniTowerAsset,
            hpValue: (opponentHp * 15).round(),
            hpProgress: opponentHp / 100,
            mainTower: false,
          ),
          _TowerNode(
            alignment: const Alignment(0, 0.7),
            imageAsset: _playerMainTowerAsset,
            hpValue: (playerHp * 30).round(),
            hpProgress: playerHp / 100,
            mainTower: true,
          ),
          _TowerNode(
            alignment: const Alignment(-0.7, 0.48),
            imageAsset: _playerMiniTowerAsset,
            hpValue: (playerHp * 15).round(),
            hpProgress: playerHp / 100,
            mainTower: false,
          ),
          _TowerNode(
            alignment: const Alignment(0.7, 0.48),
            imageAsset: _playerMiniTowerAsset,
            hpValue: (playerHp * 15).round(),
            hpProgress: playerHp / 100,
            mainTower: false,
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: _StatusBanner(text: statusMessage, dark: true),
          ),
        ],
      ),
    );
  }
}

class _TowerNode extends StatelessWidget {
  const _TowerNode({
    required this.alignment,
    required this.imageAsset,
    required this.hpValue,
    required this.hpProgress,
    required this.mainTower,
  });

  final Alignment alignment;
  final String imageAsset;
  final int hpValue;
  final double hpProgress;
  final bool mainTower;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: mainTower ? 44 : 34,
            height: mainTower ? 44 : 34,
            child: Image.asset(imageAsset, fit: BoxFit.contain),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: mainTower ? 46 : 36,
              height: 5,
              color: Colors.black45,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: hpProgress.clamp(0, 1),
                  child: Container(color: const Color(0xFF25C67A)),
                ),
              ),
            ),
          ),
          Text(
            '$hpValue',
            style: TextStyle(
              color: Colors.white.withAlpha(235),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
      BattleOutcome.win => 'VICTORY!',
      BattleOutcome.lose => 'DEFEAT',
      BattleOutcome.draw => 'DRAW',
      BattleOutcome.inProgress => 'IN PROGRESS',
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
