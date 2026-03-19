import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
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
    ref.listen<BattleState>(battleControllerProvider, (
      BattleState? previous,
      BattleState next,
    ) {
      if (next.phase != BattlePhase.inBattle) {
        return;
      }

      final bool hasNewError =
          next.errorMessage != null && next.errorMessage != previous?.errorMessage;
      final bool hasNewStatus = next.errorMessage == null &&
          next.statusMessage != null &&
          next.statusMessage != previous?.statusMessage;

      if (!hasNewError && !hasNewStatus) {
        return;
      }

      final String message = hasNewError ? next.errorMessage! : next.statusMessage!;
      final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        return;
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                hasNewError ? const Color(0xFF8F2D2A) : AppColors.levelUpTeal,
          ),
        );
    });

    final BattleState state = ref.watch(battleControllerProvider);
    final BattleController controller =
        ref.read(battleControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Arena'),
        automaticallyImplyLeading: false,
        leading: state.phase == BattlePhase.finished
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: controller.resetBattle,
              )
            : null,
        actions: state.phase == BattlePhase.inBattle
            ? <Widget>[
                IconButton(
                  onPressed: () => _showSurrenderDialog(
                    context: context,
                    controller: controller,
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Menyerah',
                ),
                const SizedBox(width: 4),
              ]
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: <Widget>[
              if (state.phase == BattlePhase.preBattle &&
                  state.statusMessage != null)
                _StatusBanner(text: state.statusMessage!),
              if (state.phase == BattlePhase.preBattle &&
                  state.errorMessage != null)
                _StatusBanner(text: state.errorMessage!, isError: true),
              if (state.phase == BattlePhase.preBattle) const SizedBox(height: 8),
              Expanded(
                child: _buildBattleContent(
                  context: context,
                  ref: ref,
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
    required WidgetRef ref,
    required BattleState state,
    required BattleController controller,
  }) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.phase == BattlePhase.preBattle) {
      return _PreBattleSection(
        mode: state.mode,
        onModeChanged: controller.setMode,
        onStart: controller.startBattle,
      );
    }

    if (state.phase == BattlePhase.finished) {
      return _ResultSection(
        state: state,
        onClaimReward: () {
          ref
              .read(playerProgressProvider.notifier)
              .applyBattleResult(outcome: state.outcome, ratingDelta: state.ratingDelta);
          controller.markRewardClaimed();
        },
        onReplay: controller.startBattle,
        onReset: controller.resetBattle,
      );
    }

    return _InBattleSection(
      state: state,
      onPickQuestion: (BattleQuestion q) {
        // Simple bottom sheet to answer; this keeps battle flow usable.
        showModalBottomSheet<void>(
          context: context,
          builder: (BuildContext context) {
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    q.prompt,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...List<Widget>.generate(
                    q.options.length,
                    (int i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () {
                          controller.answerQuestion(
                            questionId: q.id,
                            selectedOptionIndex: i,
                          );
                          Navigator.of(context).pop();
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(q.options[i]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSurrenderDialog({
    required BuildContext context,
    required BattleController controller,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Menyerah dari pertandingan?'),
          content: const Text('Progress ronde ini akan dianggap kalah.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8F2D2A),
              ),
              child: const Text('Menyerah'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      controller.surrenderBattle();
    }
  }
}

class _PreBattleSection extends StatefulWidget {
  const _PreBattleSection({
    required this.mode,
    required this.onModeChanged,
    required this.onStart,
  });

  final BattleMode mode;
  final ValueChanged<BattleMode> onModeChanged;
  final VoidCallback onStart;

  @override
  State<_PreBattleSection> createState() => _PreBattleSectionState();
}

class _PreBattleSectionState extends State<_PreBattleSection> {
  final TextEditingController _roomCodeController = TextEditingController();
  String? _createdRoomCode;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  void _startBattle({
    required BuildContext context,
    required bool isBot,
  }) async {
    if (isBot) {
      widget.onStart();
      return;
    }

    final bool allowStart = await _showRoomCodeDialog(context);
    if (allowStart) {
      widget.onStart();
    }
  }

  Future<bool> _showRoomCodeDialog(BuildContext context) async {
    String? localCreatedCode = _createdRoomCode;
    String? validationError;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Masuk Room Player'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Masukkan kode room dari tombol Buat Room.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
                        final Random random = Random();
                        final String code = List<String>.generate(
                          6,
                          (_) => chars[random.nextInt(chars.length)],
                        ).join();

                        setDialogState(() {
                          localCreatedCode = code;
                          _roomCodeController.text = code;
                          validationError = null;
                        });
                      },
                      icon: const Icon(Icons.add_home_work_outlined, size: 18),
                      label: const Text('Buat Room'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _roomCodeController,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (String value) {
                        final String upper = value.toUpperCase();
                        if (validationError != null) {
                          setDialogState(() {
                            validationError = null;
                          });
                        }
                        if (value != upper) {
                          _roomCodeController.value = TextEditingValue(
                            text: upper,
                            selection: TextSelection.collapsed(
                              offset: upper.length,
                            ),
                          );
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'Masukkan kode room',
                        counterText: '',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ).copyWith(errorText: validationError),
                    ),
                    if (localCreatedCode != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'Kode dibuat: $localCreatedCode',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final String roomCode =
                        _roomCodeController.text.trim().toUpperCase();
                    final bool isGeneratedCode =
                        localCreatedCode != null && roomCode == localCreatedCode;

                    if (!isGeneratedCode) {
                      setDialogState(() {
                        validationError =
                            'Code not found. Gunakan kode room yang dibuat.';
                      });
                      return;
                    }

                    _roomCodeController.text = roomCode;
                    _createdRoomCode = localCreatedCode;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Masuk Arena'),
                ),
              ],
            );
          },
        );
      },
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isBot = widget.mode == BattleMode.bot;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 720;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: compact ? 290 : 340,
              child: const _ArenaPreview(),
            ),
            SizedBox(height: compact ? 14 : 18),
            Text(
              'PILIH LAWAN',
              style: GoogleFonts.orbitron(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ModeCard(
                    title: 'BOT',
                    subtitle: 'Latihan vs AI',
                    selected: isBot,
                    icon: Icons.smart_toy_outlined,
                    onTap: () => widget.onModeChanged(BattleMode.bot),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    title: 'PEMAIN',
                    subtitle: 'Tantang lawan nyata',
                    selected: !isBot,
                    icon: Icons.person_outline,
                    onTap: () => widget.onModeChanged(BattleMode.online),
                  ),
                ),
              ],
            ),
            const Spacer(),
            _InfoStrip(
              text: isBot
                  ? 'Soal punya damage dan heal berbeda. Pilih dengan bijak.'
                  : 'Mode player butuh kode room. Tekan masuk arena untuk lanjut.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _startBattle(context: context, isBot: isBot),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warriorNavy,
                  foregroundColor: const Color(0xFFEAF0FB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.textStrong.withAlpha(70),
                    ),
                  ),
                ),
                label: Text(
                  'MASUK ARENA',
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _InBattleSection extends StatelessWidget {
  const _InBattleSection({
    required this.state,
    required this.onPickQuestion,
  });

  final BattleState state;
  final ValueChanged<BattleQuestion> onPickQuestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _HudStrip(
          isEnemy: true,
          playerName: 'Lawan',
          hp: state.opponentHp,
          points: state.opponentPoints,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _ArenaPanel(
            playerHp: state.playerHp,
            opponentHp: state.opponentHp,
            statusMessage: state.answeredQuestionIds.isEmpty
                ? 'Pilih kartu untuk menyerang atau heal.'
                : null,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Text(
                        '$safeHp%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'HP',
                        style: TextStyle(
                          color: Colors.white.withAlpha(190),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: <Widget>[
                      Text(
                        '$points',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'PTS',
                        style: TextStyle(
                          color: Colors.white.withAlpha(190),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
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
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: <Widget>[
          Container(color: const Color(0xFF4B9130)),
          const Positioned.fill(
            child: CustomPaint(painter: _BattlefieldPainter()),
          ),
          _TowerNode(
            alignment: const Alignment(0, -0.72),
            imageAsset: _enemyMainTowerAsset,
            hpValue: (opponentHp * 30).round(),
            hpProgress: opponentHp / 100,
            mainTower: true,
          ),
          _TowerNode(
            alignment: const Alignment(-0.72, -0.62),
            imageAsset: _enemyMiniTowerAsset,
            hpValue: (opponentHp * 15).round(),
            hpProgress: opponentHp / 100,
            mainTower: false,
          ),
          _TowerNode(
            alignment: const Alignment(0.72, -0.62),
            imageAsset: _enemyMiniTowerAsset,
            hpValue: (opponentHp * 15).round(),
            hpProgress: opponentHp / 100,
            mainTower: false,
          ),
          _TowerNode(
            alignment: const Alignment(0, 0.72),
            imageAsset: _playerMainTowerAsset,
            hpValue: (playerHp * 30).round(),
            hpProgress: playerHp / 100,
            mainTower: true,
          ),
          _TowerNode(
            alignment: const Alignment(-0.72, 0.62),
            imageAsset: _playerMiniTowerAsset,
            hpValue: (playerHp * 15).round(),
            hpProgress: playerHp / 100,
            mainTower: false,
          ),
          _TowerNode(
            alignment: const Alignment(0.72, 0.62),
            imageAsset: _playerMiniTowerAsset,
            hpValue: (playerHp * 15).round(),
            hpProgress: playerHp / 100,
            mainTower: false,
          ),
          if (statusMessage != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: _StatusBanner(text: statusMessage!, dark: true),
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
    final double towerImageSize = mainTower ? 66 : 52;
    final double padWidth = mainTower ? 112 : 88;
    final double padHeight = mainTower ? 74 : 62;

    return Align(
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: padWidth,
            height: padHeight,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: mainTower ? 96 : 74,
                    height: mainTower ? 56 : 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9E8C6A).withAlpha(160),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black.withAlpha(28)),
                    ),
                  ),
                ),
                SizedBox(
                  width: towerImageSize,
                  height: towerImageSize,
                  child: Image.asset(imageAsset, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: mainTower ? 64 : 52,
              height: 7,
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
              fontSize: 9,
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
    required this.onClaimReward,
    required this.onReplay,
    required this.onReset,
  });

  final BattleState state;
  final VoidCallback onClaimReward;
  final VoidCallback onReplay;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final bool isVictory = state.outcome == BattleOutcome.win;
    final bool isDefeat = state.outcome == BattleOutcome.lose;
    final Color accent = isVictory
        ? const Color(0xFFFFA34A)
        : isDefeat
        ? const Color(0xFF9EB0D7)
        : AppColors.levelUpTeal;
    final Color scoreAccent = isVictory
        ? const Color(0xFFC47A1A)
        : isDefeat
        ? const Color(0xFFD94646)
        : AppColors.levelUpTeal;
    final String title = switch (state.outcome) {
      BattleOutcome.win => 'VICTORY',
      BattleOutcome.lose => 'DEFEAT',
      BattleOutcome.draw || _ => 'DRAW',
    };
    final String subtitle = switch (state.outcome) {
      BattleOutcome.win => 'Battle completed',
      BattleOutcome.lose => 'Better luck next time',
      BattleOutcome.draw || _ => 'Pertarungan berakhir seri',
    };
    final int totalTurns = state.answeredQuestionIds.isEmpty
        ? 5
        : state.answeredQuestionIds.length;
    final String ratingText = state.ratingDelta >= 0
        ? '+${state.ratingDelta} pts'
        : '${state.ratingDelta} pts';
    final String scoreDivider = isDefeat ? '—' : '—';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 760;
        final bool veryCompact = constraints.maxHeight < 700;
        final double badgeSize = veryCompact
            ? 118
            : compact
            ? 132
            : 156;

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SizedBox(height: compact ? 6 : 10),
            _ResultBadge(
              accent: accent,
              victory: isVictory,
              defeat: isDefeat,
              size: badgeSize,
            ),
            SizedBox(height: compact ? 12 : 18),
            Text(
              title,
              style: GoogleFonts.orbitron(
                color: accent,
                fontSize: veryCompact
                    ? 28
                    : compact
                    ? 30
                    : 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              subtitle,
              style: GoogleFonts.jetBrainsMono(
                color: AppColors.textMuted,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: compact ? 12 : 18),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                compact ? 14 : 18,
                16,
                compact ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.warriorNavy.withAlpha(24),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ScoreColumn(
                          label: 'KAMU',
                          value: '${state.playerPoints}',
                          color: isVictory ? scoreAccent : const Color(0xFF9EB0D7),
                          compact: compact,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          scoreDivider,
                          style: TextStyle(
                            color: AppColors.warriorNavy.withAlpha(80),
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _ScoreColumn(
                          label: 'LAWAN',
                          value: '${state.opponentPoints}',
                          color: isDefeat ? const Color(0xFFD94646) : const Color(0xFFB7C4E3),
                          compact: compact,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Divider(color: AppColors.warriorNavy.withAlpha(20), height: 1),
                  SizedBox(height: compact ? 12 : 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MiniMetric(
                          value: '$totalTurns',
                          label: 'SOAL',
                          compact: compact,
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          value: '${state.playerHp}%',
                          label: 'HP SISA',
                          compact: compact,
                        ),
                      ),
                      Expanded(
                        child: _MiniMetric(
                          value: '${state.opponentHp}%',
                          label: 'HP LAWAN',
                          compact: compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: compact ? 14 : 18,
              ),
              decoration: BoxDecoration(
                color: isVictory
                    ? const Color(0xFFFFF3E6)
                    : isDefeat
                    ? const Color(0xFFFCEAEA)
                    : const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withAlpha(80)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'EXP',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF7E90BC),
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    ratingText.replaceAll('pts', 'exp'),
                    style: GoogleFonts.dmSans(
                      color: isDefeat ? const Color(0xFFB03030) : scoreAccent,
                      fontSize: compact ? 17 : 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            if (!state.rewardClaimed)
              SizedBox(
                width: double.infinity,
                height: compact ? 52 : 58,
                child: FilledButton.icon(
                  onPressed: onClaimReward,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warriorNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: AppColors.warriorNavy.withAlpha(200),
                      ),
                    ),
                  ),
                  label: Text(
                    'CLAIM REWARD',
                    style: GoogleFonts.orbitron(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 14 : 16,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              )
            else
              _RewardClaimedBanner(compact: compact),
            SizedBox(height: compact ? 10 : 12),
            SizedBox(
              width: double.infinity,
              height: compact ? 52 : 58,
              child: OutlinedButton.icon(
                onPressed: onReplay,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.levelUpTeal),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF151515),
                  side: BorderSide(color: AppColors.textStrong.withAlpha(70)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                label: Text(
                  'Play Again',
                  style: GoogleFonts.dmSans(
                    fontSize: compact ? 17 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.lobby),
              child: Text(
                'Back to Lobby',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFAEBEE1),
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
          ],
        );
      },
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({
    required this.accent,
    required this.victory,
    required this.defeat,
    required this.size,
  });

  final Color accent;
  final bool victory;
  final bool defeat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final IconData icon = victory
        ? Icons.verified_rounded
        : defeat
        ? Icons.close_rounded
        : Icons.remove_rounded;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withAlpha(48)),
      ),
      child: Center(
        child: Container(
          width: size * 0.84,
          height: size * 0.84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withAlpha(18),
            border: Border.all(color: accent.withAlpha(110), width: 2),
          ),
          child: Icon(
            icon,
            size: size * 0.35,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.compact,
  });

  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: color.withAlpha(220),
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: compact ? 42 : 50,
            fontWeight: FontWeight.w800,
            height: 0.95,
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.value,
    required this.label,
    required this.compact,
  });

  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: GoogleFonts.orbitron(
            color: AppColors.warriorNavy,
            fontSize: compact ? 16 : 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: const Color(0xFFA6B6D9),
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _RewardClaimedBanner extends StatelessWidget {
  const _RewardClaimedBanner({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 18,
        vertical: compact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F6F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.levelUpTeal.withAlpha(80)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.levelUpTeal,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'Reward claimed',
            style: GoogleFonts.orbitron(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 14 : 16,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
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
    if (dark) {
      final Color darkBackground =
          isError ? const Color(0xFF5D1F2A) : const Color(0xFF173763);
      final Color marker = isError ? AppColors.fireGold : AppColors.levelUpTeal;
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: darkBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isError ? AppColors.fireGold : AppColors.levelUpTeal)
                .withAlpha(170),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: marker,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.scholarCream,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final Color background =
        isError ? const Color(0xFFFFECE8) : const Color(0xFFE4F5F6);
    final Color foreground =
        isError ? const Color(0xFF8F2D2A) : AppColors.levelUpTeal;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withAlpha(80)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaPreview extends StatelessWidget {
  const _ArenaPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(30)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: <Widget>[
            const _ArenaGrid(),
            Positioned.fill(
              child: CustomPaint(painter: _ArenaRingPainter()),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const _AvatarBadge(label: 'Kamu', isEnemy: false),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.warriorNavy.withAlpha(80),
                        ),
                      ),
                      child: Text(
                        'VS',
                        style: GoogleFonts.orbitron(
                          color: AppColors.warriorNavy,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    _AvatarBadge(
                      label: 'Lawan',
                      isEnemy: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArenaGrid extends StatelessWidget {
  const _ArenaGrid();

  @override
  Widget build(BuildContext context) {
    final Color line = AppColors.warriorNavy.withAlpha(26);
    final Color strong = AppColors.warriorNavy.withAlpha(90);

    return Stack(
      children: <Widget>[
        for (double x in <double>[0.17, 0.34, 0.5, 0.66, 0.83])
          Align(
            alignment: Alignment(x * 2 - 1, 0),
            child: Container(width: 1, color: line),
          ),
        for (double y in <double>[0.25, 0.5, 0.75])
          Align(
            alignment: Alignment(0, y * 2 - 1),
            child: Container(height: 1, color: line),
          ),
        Align(
          alignment: Alignment.center,
          child: Container(width: 1.2, color: strong.withAlpha(90)),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(height: 1.2, color: strong.withAlpha(24)),
        ),
        ...<Widget>[
          _CornerBracket(alignment: Alignment.topLeft),
          _CornerBracket(alignment: Alignment.topRight),
          _CornerBracket(alignment: Alignment.bottomLeft),
          _CornerBracket(alignment: Alignment.bottomRight),
        ],
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final bool left = alignment.x < 0;
    final bool top = alignment.y < 0;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 34,
          height: 34,
          child: CustomPaint(
            painter: _BracketPainter(
              left: left,
              top: top,
              color: AppColors.warriorNavy.withAlpha(80),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.label, required this.isEnemy});

  final String label;
  final bool isEnemy;

  @override
  Widget build(BuildContext context) {
    final Color tint = isEnemy ? AppColors.fireGold : AppColors.levelUpTeal;
    final String asset = isEnemy ? _enemyAvatarAsset : _playerAvatarAsset;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 104,
          child: Column(
            children: <Widget>[
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: tint.withAlpha(28),
                  backgroundImage: AssetImage(asset),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 90,
                height: 6,
                decoration: BoxDecoration(
                  color: tint.withAlpha(80),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            color: tint,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color border =
        selected ? AppColors.warriorNavy : AppColors.warriorNavy.withAlpha(40);
    final Color text =
        selected ? AppColors.warriorNavy : AppColors.textMuted;
    final Color iconBg = selected
        ? AppColors.levelUpTeal.withAlpha(28)
        : AppColors.warriorNavy.withAlpha(10);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 2),
            color: selected ? AppColors.warriorNavy.withAlpha(12) : Colors.white,
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.warriorNavy.withAlpha(24),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected ? AppColors.levelUpTeal : text,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.orbitron(
                  color: text,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.levelUpTeal : AppColors.textMuted,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F5F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.levelUpTeal.withAlpha(70)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.levelUpTeal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.levelUpTeal,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattlefieldPainter extends CustomPainter {
  const _BattlefieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint checkerPaint = Paint()..color = Colors.white.withAlpha(15);
    const double tileSize = 28;

    for (double x = 0; x < size.width; x += tileSize) {
      for (double y = 0; y < size.height; y += tileSize) {
        final int tx = (x / tileSize).floor();
        final int ty = (y / tileSize).floor();
        if ((tx + ty).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, tileSize, tileSize),
            checkerPaint,
          );
        }
      }
    }

    final Paint pathPaint = Paint()..color = const Color(0xFFC8A05A);
    final Paint pathShade = Paint()..color = Colors.black.withAlpha(28);
    double laneWidth = size.width * 0.24;
    if (laneWidth < 88) {
      laneWidth = 88;
    } else if (laneWidth > 110) {
      laneWidth = 110;
    }
    final double midY = size.height * 0.5;
    final double riverHeight = size.height * 0.14;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: laneWidth,
        height: size.height,
      ),
      pathPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width,
        height: 68,
      ),
      pathPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 - laneWidth / 2,
        0,
        4,
        size.height,
      ),
      pathShade,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2 + laneWidth / 2 - 4,
        0,
        4,
        size.height,
      ),
      pathShade,
    );

    final Rect riverRect = Rect.fromCenter(
      center: Offset(size.width / 2, midY),
      width: size.width,
      height: riverHeight,
    );
    final Paint riverPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF0AB8D8),
          Color(0xFF18E8FF),
          Color(0xFF0AB8D8),
        ],
      ).createShader(riverRect);
    canvas.drawRect(riverRect, riverPaint);

    final Paint foamPaint = Paint()..color = Colors.white.withAlpha(60);
    for (int i = 0; i < 5; i++) {
      final double cx = (size.width / 5) * i + 24;
      final double cy = midY + ((i.isEven ? -1 : 1) * 6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 42, height: 10),
        foamPaint,
      );
    }

    final Paint riverEdge = Paint()
      ..color = Colors.white.withAlpha(55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, midY - riverHeight / 2),
      Offset(size.width, midY - riverHeight / 2),
      riverEdge,
    );
    canvas.drawLine(
      Offset(0, midY + riverHeight / 2),
      Offset(size.width, midY + riverHeight / 2),
      riverEdge,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArenaRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint ringPaint = Paint()
      ..color = AppColors.warriorNavy.withAlpha(36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Paint softPaint = Paint()
      ..color = AppColors.levelUpTeal.withAlpha(28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Rect outerOval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.72,
      height: size.height * 0.56,
    );
    final Rect innerOval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.46,
      height: size.height * 0.34,
    );

    canvas.drawOval(outerOval, ringPaint);
    canvas.drawOval(innerOval, softPaint);

    final Paint dotPaint = Paint()..color = AppColors.levelUpTeal.withAlpha(110);
    canvas.drawCircle(Offset(size.width / 2, 28), 5, dotPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height - 28), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.left,
    required this.top,
    required this.color,
  });

  final bool left;
  final bool top;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final Path path = Path();

    final double startX = left ? 0 : size.width;
    final double midX = left ? size.width * 0.65 : size.width * 0.35;
    final double startY = top ? 0 : size.height;
    final double midY = top ? size.height * 0.65 : size.height * 0.35;

    path.moveTo(startX, startY);
    path.lineTo(midX, startY);
    path.moveTo(startX, startY);
    path.lineTo(startX, midY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
