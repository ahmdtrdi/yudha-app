import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
const String _enemyMainTowerDestroyedAsset =
    'assets/game/red_maintower_destroyed.png';
const String _enemyMiniTowerDestroyedAsset =
    'assets/game/red_minitower_destroyed.png';
const String _playerMainTowerDestroyedAsset =
    'assets/game/blue_maintower_destroyed.png';
const String _playerMiniTowerDestroyedAsset =
    'assets/game/blue_minitower_destroyed.png';
const String _tiuCardAsset = 'assets/game/tiu_card.png';
const String _twkCardAsset = 'assets/game/twk_card.png';
// Attack effects are now rendered via CustomPainter (no PNG assets needed).

const Alignment _enemyMainAlignment = Alignment(0, -0.59);
const Alignment _enemyMiniLeftAlignment = Alignment(-0.704, -0.418);
const Alignment _enemyMiniRightAlignment = Alignment(0.704, -0.418);
const Alignment _playerMainAlignment = Alignment(0, 0.392);
const Alignment _playerMiniLeftAlignment = Alignment(-0.704, 0.222);
const Alignment _playerMiniRightAlignment = Alignment(0.704, 0.222);

class PvpPage extends ConsumerWidget {
  const PvpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Toast notifications are now handled by _InBattleSectionState.

    final BattleState state = ref.watch(battleControllerProvider);
    final BattleController controller = ref.read(
      battleControllerProvider.notifier,
    );
    final String playerDisplayName = ref.watch(
      playerProgressProvider.select((progress) => progress.displayName),
    );

    if (state.phase != BattlePhase.preBattle) {
      return Scaffold(
        backgroundColor: const Color(0xFF04060F),
        body: SafeArea(
          child: _buildBattleContent(
            context: context,
            ref: ref,
            state: state,
            controller: controller,
            playerDisplayName: playerDisplayName,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Arena'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            children: <Widget>[
              if (state.statusMessage != null)
                _StatusBanner(text: state.statusMessage!),
              if (state.errorMessage != null)
                _StatusBanner(text: state.errorMessage!, isError: true),
              const SizedBox(height: 8),
              Expanded(
                child: _buildBattleContent(
                  context: context,
                  ref: ref,
                  state: state,
                  controller: controller,
                  playerDisplayName: playerDisplayName,
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
    required String playerDisplayName,
  }) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.phase == BattlePhase.preBattle) {
      return _ArenaEntrySection(
        playerDisplayName: playerDisplayName,
        onEnterArena: controller.enterArena,
      );
    }

    if (state.phase == BattlePhase.arenaMenu) {
      return _ArenaMenuSection(
        playerDisplayName: playerDisplayName,
        onBackHome: controller.exitArena,
        onStartBot: () {
          controller.setMode(BattleMode.bot);
          controller.startBattle();
        },
        onStartPlayer: () async {
          controller.setMode(BattleMode.online);
          final bool allowStart = await _showRoomCodeDialog(context);
          if (allowStart) {
            controller.startBattle();
          }
        },
      );
    }

    if (state.phase == BattlePhase.finished) {
      return _ResultSection(
        state: state,
        onClaimReward: () {
          ref
              .read(playerProgressProvider.notifier)
              .applyBattleResult(
                outcome: state.outcome,
                ratingDelta: state.ratingDelta,
              );
          controller.markRewardClaimed();
        },
        onReplay: controller.startBattle,
        onReset: controller.resetBattle,
        playerDisplayName: playerDisplayName,
      );
    }

    return _InBattleSection(
      state: state,
      playerDisplayName: playerDisplayName,
      onPause: () => _showPauseDialog(context: context, controller: controller),
      onBotAnswer: controller.answerBotQuestion,
      onPickQuestion: (BattleQuestion question) => _showQuestionSheet(
        context: context,
        controller: controller,
        question: question,
      ),
    );
  }

  Future<void> _showQuestionSheet({
    required BuildContext context,
    required BattleController controller,
    required BattleQuestion question,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _QuestionBattleSheet(
          question: question,
          onAnswered: (int selectedOptionIndex) {
            controller.answerQuestion(
              questionId: question.id,
              selectedOptionIndex: selectedOptionIndex,
            );
          },
        );
      },
    );
  }

  Future<void> _showPauseDialog({
    required BuildContext context,
    required BattleController controller,
  }) async {
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withAlpha(34)),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withAlpha(160), blurRadius: 28),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  color: AppColors.fireGold,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  'PAUSED',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Arena dihentikan sementara',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop('resume'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.fireGold,
                      foregroundColor: const Color(0xFF1A0A00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: Text(
                      'LANJUT',
                      style: GoogleFonts.orbitron(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('menu'),
                    icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF8888),
                      side: BorderSide(
                        color: const Color(0xFFFF6060).withAlpha(120),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: const Text(
                      'Keluar ke Menu',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'menu') {
      controller.resetBattle();
    }
  }

  Future<bool> _showRoomCodeDialog(BuildContext context) async {
    final TextEditingController roomCodeController = TextEditingController();
    String? localCreatedCode;
    String? validationError;

    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (BuildContext dialogContext, StateSetter setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF101733),
                title: const Text(
                  'VS Player',
                  style: TextStyle(color: Colors.white),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Buat room lalu gunakan kode itu untuk mulai simulasi match player.',
                        style: TextStyle(
                          color: Colors.white.withAlpha(170),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          const String chars =
                              'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
                          final Random random = Random();
                          final String code = List<String>.generate(
                            6,
                            (_) => chars[random.nextInt(chars.length)],
                          ).join();

                          setDialogState(() {
                            localCreatedCode = code;
                            roomCodeController.text = code;
                            validationError = null;
                          });
                        },
                        icon: const Icon(
                          Icons.add_home_work_outlined,
                          size: 18,
                        ),
                        label: const Text('Buat Room'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: roomCodeController,
                        maxLength: 6,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                        onChanged: (String value) {
                          final String upper = value.toUpperCase();
                          if (validationError != null) {
                            setDialogState(() {
                              validationError = null;
                            });
                          }
                          if (value != upper) {
                            roomCodeController.value = TextEditingValue(
                              text: upper,
                              selection: TextSelection.collapsed(
                                offset: upper.length,
                              ),
                            );
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'KODE ROOM',
                          counterText: '',
                          errorText: validationError,
                          hintStyle: TextStyle(
                            color: Colors.white.withAlpha(80),
                            letterSpacing: 1,
                          ),
                          filled: true,
                          fillColor: Colors.white.withAlpha(18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (localCreatedCode != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          'Kode dibuat: $localCreatedCode',
                          style: const TextStyle(
                            color: AppColors.fireGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
                      final String roomCode = roomCodeController.text
                          .trim()
                          .toUpperCase();
                      final bool isGeneratedCode =
                          localCreatedCode != null &&
                          roomCode == localCreatedCode;

                      if (!isGeneratedCode) {
                        setDialogState(() {
                          validationError =
                              'Gunakan kode room yang dibuat dahulu.';
                        });
                        return;
                      }

                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const Text('Mulai Match'),
                  ),
                ],
              );
            },
          );
        },
      );

      return confirmed ?? false;
    } finally {
      roomCodeController.dispose();
    }
  }
}

class _QuestionBattleSheet extends StatefulWidget {
  const _QuestionBattleSheet({
    required this.question,
    required this.onAnswered,
  });

  final BattleQuestion question;
  final ValueChanged<int> onAnswered;

  @override
  State<_QuestionBattleSheet> createState() => _QuestionBattleSheetState();
}

class _QuestionBattleSheetState extends State<_QuestionBattleSheet> {
  static const int _maxSeconds = 10;

  Timer? _timer;
  int _remainingSeconds = _maxSeconds;
  int? _selectedIndex;
  bool _locked = false;
  bool? _isCorrect;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _submitAnswer(-1, timedOut: true);
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submitAnswer(int selectedIndex, {bool timedOut = false}) async {
    if (_locked) {
      return;
    }

    final bool correct = selectedIndex == widget.question.correctOptionIndex;
    _timer?.cancel();
    setState(() {
      _locked = true;
      _selectedIndex = selectedIndex;
      _isCorrect = correct;
      _feedback = timedOut
          ? 'Waktu habis. Serangan gagal.'
          : correct
          ? 'Jawaban benar. Serangan masuk.'
          : 'Jawaban kurang tepat. Lawan membalas.';
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) {
      return;
    }

    widget.onAnswered(selectedIndex);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDamage = widget.question.effect == QuestionEffect.damage;
    final Color accent = isDamage
        ? const Color(0xFF3EAAFF)
        : const Color(0xFF2ECC6A);
    final int impact = BattleStateMachine.impactFromWeight(
      widget.question.weight,
    );
    final double timerProgress = _remainingSeconds / _maxSeconds;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF141440), Color(0xFF080A22)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: accent, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(170),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: <Widget>[
                              _QuestionBadge(
                                text: isDamage ? 'SERANGAN' : 'HEAL',
                                color: accent,
                              ),
                              _QuestionBadge(
                                text: '$impact POWER',
                                color: AppColors.fireGold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Jawab untuk ${isDamage ? 'menyerang' : 'memulihkan'}',
                            style: GoogleFonts.orbitron(
                              color: AppColors.fireGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _TimerRing(
                      remainingSeconds: _remainingSeconds,
                      progress: timerProgress,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.question.prompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool singleColumn = constraints.maxWidth < 340;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.question.options.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: singleColumn ? 1 : 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: singleColumn ? 4.2 : 2.9,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final bool isSelected = _selectedIndex == index;
                        final bool optionCorrect =
                            index == widget.question.correctOptionIndex;
                        Color border = Colors.white.withAlpha(46);
                        Color background = Colors.white.withAlpha(16);
                        Color textColor = Colors.white;

                        if (_locked && isSelected) {
                          border = optionCorrect
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF87171);
                          background = optionCorrect
                              ? const Color(0xFF22C55E).withAlpha(55)
                              : const Color(0xFFEF4444).withAlpha(46);
                          textColor = border;
                        }

                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _locked ? null : () => _submitAnswer(index),
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  widget.question.options[index],
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _feedback == null
                      ? const SizedBox(height: 20)
                      : Text(
                          _feedback!,
                          key: ValueKey<String>(_feedback!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isCorrect == true
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
                if (widget.question.weight == 3) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fireGold.withAlpha(32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Power round: kartu ini memberi impact terbesar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFCD34D),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _locked ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withAlpha(120),
                    side: BorderSide(color: Colors.white.withAlpha(34)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionBadge extends StatelessWidget {
  const _QuestionBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.remainingSeconds, required this.progress});

  final int remainingSeconds;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final Color color = remainingSeconds <= 3
        ? const Color(0xFFF87171)
        : const Color(0xFF22C55E);

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            strokeWidth: 3.5,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: Colors.white.withAlpha(22),
          ),
          Text(
            '$remainingSeconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaEntrySection extends StatelessWidget {
  const _ArenaEntrySection({
    required this.playerDisplayName,
    required this.onEnterArena,
  });

  final String playerDisplayName;
  final VoidCallback onEnterArena;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 700;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: compact ? 236 : 280,
                  child: _ArenaPreview(playerName: playerDisplayName),
                ),
                SizedBox(height: compact ? 12 : 16),
                _HowToPlayPanel(compact: compact),
                SizedBox(height: compact ? 12 : 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: onEnterArena,
                    icon: const Icon(Icons.sports_esports_rounded, size: 20),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HowToPlayPanel extends StatelessWidget {
  const _HowToPlayPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<({IconData icon, String title, String text})>
    items = <({IconData icon, String title, String text})>[
      (
        icon: Icons.style_rounded,
        title: 'Pilih kartu',
        text:
            'Pilih kartu soal dari tanganmu. Tiap kartu punya damage atau heal berbeda.',
      ),
      (
        icon: Icons.bolt_rounded,
        title: 'Jawab soal',
        text:
            'Jawab benar untuk memberi damage ke menara lawan atau heal menaramu.',
      ),
      (
        icon: Icons.account_balance_rounded,
        title: 'Hancurkan menara',
        text: 'Hancurkan menara utama lawan sebelum menaramu dihancurkan.',
      ),
    ];

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'CARA BERMAIN',
            style: GoogleFonts.orbitron(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          for (int i = 0; i < items.length; i++) ...<Widget>[
            _HowToRow(
              icon: items[i].icon,
              title: items[i].title,
              text: items[i].text,
              accent: i == 0
                  ? AppColors.levelUpTeal
                  : i == 1
                  ? AppColors.fireGold
                  : AppColors.warriorNavy,
            ),
            if (i != items.length - 1) SizedBox(height: compact ? 8 : 8),
          ],
        ],
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  const _HowToRow({
    required this.icon,
    required this.title,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    color: AppColors.warriorNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaMenuSection extends StatefulWidget {
  const _ArenaMenuSection({
    required this.playerDisplayName,
    required this.onBackHome,
    required this.onStartBot,
    required this.onStartPlayer,
  });

  final String playerDisplayName;
  final VoidCallback onBackHome;
  final VoidCallback onStartBot;
  final VoidCallback onStartPlayer;

  @override
  State<_ArenaMenuSection> createState() => _ArenaMenuSectionState();
}

class _ArenaMenuSectionState extends State<_ArenaMenuSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transitionController;
  bool _transitionDone = false;

  @override
  void initState() {
    super.initState();
    _transitionController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1800),
          )
          ..forward().then((_) {
            if (mounted) {
              setState(() {
                _transitionDone = true;
              });
            }
          });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08101F),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ArenaMenuBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxHeight < 720;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, compact ? 18 : 28, 20, 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: max<double>(0, constraints.maxHeight - 36),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _ArenaMenuLogo(compact: compact),
                        SizedBox(height: compact ? 20 : 28),
                        _MenuActionButton(
                          icon: Icons.smart_toy_outlined,
                          title: 'VS Bot',
                          subtitle: 'Lawan AI dan kuasai kartu',
                          colors: const <Color>[
                            Color(0xFF1A3A6B),
                            Color(0xFF2563EB),
                          ],
                          onTap: widget.onStartBot,
                        ),
                        const SizedBox(height: 12),
                        _MenuActionButton(
                          icon: Icons.public_rounded,
                          title: 'VS Player',
                          subtitle: 'Buat room atau join teman',
                          colors: const <Color>[
                            Color(0xFF512DA8),
                            Color(0xFF9333EA),
                          ],
                          onTap: widget.onStartPlayer,
                        ),
                        const SizedBox(height: 12),
                        _MenuActionButton(
                          icon: Icons.home_rounded,
                          title: 'Kembali ke Halaman Utama',
                          subtitle: 'Keluar dari arena',
                          colors: const <Color>[
                            Color(0xFF14532D),
                            Color(0xFF16A34A),
                          ],
                          onTap: widget.onBackHome,
                        ),
                        SizedBox(height: compact ? 18 : 24),
                        _ArenaTipStrip(
                          playerDisplayName: widget.playerDisplayName,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // ── Entrance transition overlay ──
          if (!_transitionDone)
            AnimatedBuilder(
              animation: _transitionController,
              builder: (BuildContext context, Widget? child) {
                final double t = _transitionController.value;
                final double fadeOut = t < 0.7
                    ? 0
                    : ((t - 0.7) / 0.3).clamp(0.0, 1.0);
                final double progressBar = (t / 0.65).clamp(0.0, 1.0);
                final double iconPulse = 1.0 + sin(t * pi * 4) * 0.08;

                return Positioned.fill(
                  child: IgnorePointer(
                    ignoring: fadeOut >= 1.0,
                    child: Opacity(
                      opacity: (1 - fadeOut).clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0xFF0D1B3E),
                              Color(0xFF080E1A),
                              Color(0xFF0E2A1A),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Transform.scale(
                                scale: iconPulse,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFFFFD23F,
                                    ).withAlpha(28),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFFD23F,
                                      ).withAlpha(120),
                                      width: 2,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFD23F,
                                        ).withAlpha(60),
                                        blurRadius: 30,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.military_tech_rounded,
                                    color: Color(0xFFFFD23F),
                                    size: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'YUDHA PvP',
                                style: GoogleFonts.orbitron(
                                  color: const Color(0xFFFFD23F),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color: const Color(
                                        0xFFFFD23F,
                                      ).withAlpha(120),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'MEMASUKI ARENA',
                                style: GoogleFonts.orbitron(
                                  color: Colors.white.withAlpha(120),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: 200,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progressBar,
                                    backgroundColor: Colors.white.withAlpha(20),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFFD23F),
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ArenaMenuLogo extends StatelessWidget {
  const _ArenaMenuLogo({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: compact ? 72 : 88,
          height: compact ? 72 : 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.fireGold.withAlpha(28),
            border: Border.all(
              color: AppColors.fireGold.withAlpha(150),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.fireGold.withAlpha(70),
                blurRadius: 26,
              ),
            ],
          ),
          child: const Icon(
            Icons.military_tech_rounded,
            color: AppColors.fireGold,
            size: 46,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'YUDHA PvP',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            color: AppColors.fireGold,
            fontSize: compact ? 30 : 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ARENA PERTEMPURAN',
          style: TextStyle(
            color: Colors.white.withAlpha(150),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _MenuActionButton extends StatelessWidget {
  const _MenuActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.last.withAlpha(90),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(170),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withAlpha(160),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaTipStrip extends StatelessWidget {
  const _ArenaTipStrip({required this.playerDisplayName});

  final String playerDisplayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Text(
        '$playerDisplayName siap bertarung - jawab cepat, deal damage, rebut victory',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withAlpha(170),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}

class _ArenaMenuBackground extends StatelessWidget {
  const _ArenaMenuBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ArenaMenuBackgroundPainter());
  }
}

class _ArenaMenuBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF0D1B3E),
          Color(0xFF1A0A3A),
          Color(0xFF0E2A1A),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    final Paint gridPaint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..strokeWidth = 1;
    const double gap = 44;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint glowBlue = Paint()
      ..color = const Color(0xFF3EAAFF).withAlpha(42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    final Paint glowGold = Paint()
      ..color = AppColors.fireGold.withAlpha(46)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.18),
      78,
      glowBlue,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.78),
      92,
      glowGold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InBattleSection extends StatefulWidget {
  const _InBattleSection({
    required this.state,
    required this.playerDisplayName,
    required this.onPause,
    required this.onBotAnswer,
    required this.onPickQuestion,
  });

  final BattleState state;
  final String playerDisplayName;
  final VoidCallback onPause;
  final VoidCallback onBotAnswer;
  final ValueChanged<BattleQuestion> onPickQuestion;

  @override
  State<_InBattleSection> createState() => _InBattleSectionState();
}

class _InBattleSectionState extends State<_InBattleSection>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _countdownController;
  final Random _random = Random();

  int _countdownValue = 3;
  bool _countdownDone = false;
  final List<_ToastData> _toasts = <_ToastData>[];
  int _toastIdCounter = 0;
  int _lastToastEventId = 0;
  Timer? _botTimer;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _startCountdown();
  }

  void _startCountdown() {
    _countdownValue = 3;
    _countdownDone = false;
    _animateCountdownTick();
  }

  void _animateCountdownTick() {
    _countdownController.forward(from: 0).then((_) {
      if (!mounted) return;
      if (_countdownValue > 1) {
        setState(() {
          _countdownValue--;
        });
        _animateCountdownTick();
      } else {
        setState(() {
          _countdownValue = 0;
        });
        _countdownController.forward(from: 0).then((_) {
          if (!mounted) return;
          setState(() {
            _countdownDone = true;
          });
          _scheduleBotAttack();
        });
      }
    });
  }

  void _addToast(String text, {bool isError = false}) {
    final int id = _toastIdCounter++;
    setState(() {
      _toasts.add(_ToastData(id: id, text: text, isError: isError));
    });
    Future<void>.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() {
        _toasts.removeWhere((_ToastData t) => t.id == id);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _InBattleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? newStatus = widget.state.statusMessage;
    final String? newError = widget.state.errorMessage;
    final String? toastText = newError ?? newStatus;
    if (toastText != null &&
        widget.state.battleEventId != _lastToastEventId &&
        _countdownDone) {
      _lastToastEventId = widget.state.battleEventId;
      _addToast(toastText, isError: newError != null);
    }

    if (widget.state.phase != BattlePhase.inBattle ||
        widget.state.mode != BattleMode.bot ||
        widget.state.availableQuestions.isEmpty) {
      _botTimer?.cancel();
      _botTimer = null;
      return;
    }

    if (_countdownDone && !(_botTimer?.isActive ?? false)) {
      _scheduleBotAttack();
    }
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _ambientController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  void _scheduleBotAttack() {
    if (!_countdownDone ||
        widget.state.phase != BattlePhase.inBattle ||
        widget.state.mode != BattleMode.bot ||
        widget.state.availableQuestions.isEmpty ||
        (_botTimer?.isActive ?? false)) {
      return;
    }

    final int delayMs = 3300 + _random.nextInt(2600);
    _botTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted ||
          !_countdownDone ||
          widget.state.phase != BattlePhase.inBattle ||
          widget.state.mode != BattleMode.bot ||
          widget.state.availableQuestions.isEmpty) {
        return;
      }
      widget.onBotAnswer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 760;

        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ambientController,
                  builder: (BuildContext context, Widget? child) {
                    return _ArenaPanel(
                      playerHp: widget.state.playerHp,
                      opponentHp: widget.state.opponentHp,
                      mode: widget.state.mode,
                      animationValue: _ambientController.value,
                      visualActor: widget.state.lastActor,
                      visualEffect: widget.state.lastVisualEffect,
                      visualCategory: widget.state.lastEventCategory,
                      eventId: widget.state.battleEventId,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ambientController,
                  builder: (BuildContext context, Widget? child) {
                    return _HudStrip(
                      isEnemy: true,
                      playerName: widget.state.opponentName,
                      hp: widget.state.opponentHp,
                      points: widget.state.opponentPoints,
                      compact: compact,
                      animationValue: _ambientController.value,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: _ArenaIconButton(
                icon: Icons.pause_rounded,
                tooltip: 'Pause',
                onPressed: widget.onPause,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_countdownDone,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _ambientController,
                    builder: (BuildContext context, Widget? child) {
                      return _HudStrip(
                        isEnemy: false,
                        playerName: widget.playerDisplayName,
                        hp: widget.state.playerHp,
                        points: widget.state.playerPoints,
                        questions: widget.state.availableQuestions
                            .take(4)
                            .toList(),
                        onPickQuestion: widget.onPickQuestion,
                        compact: compact,
                        animationValue: _ambientController.value,
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 64,
              left: 16,
              right: 16,
              child: Column(
                children: <Widget>[
                  for (final _ToastData toast in _toasts)
                    _GameToast(
                      key: ValueKey<int>(toast.id),
                      text: toast.text,
                      isError: toast.isError,
                    ),
                ],
              ),
            ),
            if (!_countdownDone)
              AnimatedBuilder(
                animation: _countdownController,
                builder: (BuildContext context, Widget? child) {
                  return _CountdownOverlay(
                    value: _countdownValue,
                    progress: _countdownController.value,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _ToastData {
  const _ToastData({
    required this.id,
    required this.text,
    required this.isError,
  });
  final int id;
  final String text;
  final bool isError;
}

class _GameToast extends StatefulWidget {
  const _GameToast({super.key, required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  State<_GameToast> createState() => _GameToastState();
}

class _GameToastState extends State<_GameToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.isError
        ? const Color(0xFFFF6060)
        : widget.text.contains('benar') || widget.text.contains('memulihkan')
        ? const Color(0xFF4ADE80)
        : widget.text.contains('menerima') || widget.text.contains('Musuh')
        ? const Color(0xFFFF6060)
        : const Color(0xFF60A5FA);
    final Color bgColor = widget.isError
        ? const Color(0xE0501414)
        : widget.text.contains('benar') || widget.text.contains('memulihkan')
        ? const Color(0xE0143214)
        : widget.text.contains('menerima')
        ? const Color(0xE0501414)
        : const Color(0xE0142050);

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          ),
      child: FadeTransition(
        opacity: _controller,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: accent.withAlpha(100)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: accent.withAlpha(150),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          color: Colors.white.withAlpha(232),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.value, required this.progress});
  final int value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final bool isGo = value == 0;
    final String label = isGo ? 'GO!' : '$value';
    final double scaleAnim = isGo
        ? 0.6 + Curves.elasticOut.transform(progress.clamp(0.0, 1.0)) * 0.6
        : 0.3 + Curves.easeOutBack.transform(progress.clamp(0.0, 1.0)) * 0.9;
    final double opacityAnim = progress < 0.8
        ? 1.0
        : (1.0 - (progress - 0.8) / 0.2);
    final Color textColor = isGo ? const Color(0xFFFFD23F) : Colors.white;

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withAlpha(isGo ? 80 : 140),
          child: Center(
            child: Opacity(
              opacity: opacityAnim.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scaleAnim.clamp(0.1, 2.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: GoogleFonts.orbitron(
                        color: textColor,
                        fontSize: isGo ? 72 : 96,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        shadows: <Shadow>[
                          Shadow(
                            color: textColor.withAlpha(180),
                            blurRadius: 40,
                          ),
                          Shadow(
                            color: textColor.withAlpha(100),
                            blurRadius: 80,
                          ),
                          const Shadow(
                            color: Colors.black,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    if (!isGo) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        'BERSIAP',
                        style: GoogleFonts.orbitron(
                          color: Colors.white.withAlpha(150),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArenaIconButton extends StatelessWidget {
  const _ArenaIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(140),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white.withAlpha(235), size: 20),
      ),
    );
  }
}

class _HudStrip extends StatelessWidget {
  const _HudStrip({
    required this.isEnemy,
    required this.playerName,
    required this.hp,
    required this.points,
    required this.animationValue,
    this.compact = false,
    this.questions = const <BattleQuestion>[],
    this.onPickQuestion,
  });

  final bool isEnemy;
  final String playerName;
  final int hp;
  final int points;
  final double animationValue;
  final bool compact;
  final List<BattleQuestion> questions;
  final ValueChanged<BattleQuestion>? onPickQuestion;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = isEnemy
        ? const <Color>[Color(0xC05E080C), Color(0x9A8A3100), Color(0x7321750D)]
        : const <Color>[
            Color(0xB0042C6A),
            Color(0x93257509),
            Color(0x7A04285C),
          ];
    final int safeHp = hp.clamp(0, 100).toInt();
    final int displayHp = safeHp * 30;
    final String avatarAsset = isEnemy ? _enemyAvatarAsset : _playerAvatarAsset;
    final Color sideAccent = isEnemy
        ? const Color(0xFFFF5555)
        : const Color(0xFF55AAFF);
    final Color hpIconColor = isEnemy
        ? const Color(0xFFFF6A6A)
        : const Color(0xFF63B6FF);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
            ),
            border: Border(
              top: isEnemy
                  ? BorderSide.none
                  : BorderSide(color: sideAccent.withAlpha(70)),
              bottom: isEnemy
                  ? BorderSide(color: sideAccent.withAlpha(70))
                  : BorderSide.none,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(88),
                blurRadius: 24,
                offset: Offset(0, isEnemy ? 6 : -6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            12,
            compact ? 7 : 8,
            isEnemy ? 62 : 12,
            compact ? 7 : 10,
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  _ProfileAvatar(
                    asset: avatarAsset,
                    isEnemy: isEnemy,
                    animationValue: animationValue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                playerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  color: Colors.white.withAlpha(235),
                                  fontSize: compact ? 12 : 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _RankChip(
                              label: isEnemy ? 'S' : 'A',
                              color: sideAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        _ProfileHpBar(
                          safeHp: safeHp,
                          isEnemy: isEnemy,
                          animationValue: animationValue,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Icon(
                              isEnemy
                                  ? Icons.favorite_rounded
                                  : Icons.shield_rounded,
                              color: hpIconColor,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$displayHp',
                              style: GoogleFonts.nunito(
                                color: Colors.white.withAlpha(210),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isEnemy) ...<Widget>[
                SizedBox(height: compact ? 7 : 9),
                SizedBox(
                  height: compact ? 92 : 116,
                  child: Row(
                    children: List<Widget>.generate(4, (int index) {
                      if (index >= questions.length) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                          ),
                        );
                      }

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                          child: _BattleCard(
                            question: questions[index],
                            index: index,
                            compact: compact,
                            animationValue: animationValue,
                            onTap: () => onPickQuestion?.call(questions[index]),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.asset,
    required this.isEnemy,
    required this.animationValue,
  });

  final String asset;
  final bool isEnemy;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final Color color = isEnemy
        ? const Color(0xFFFF5555)
        : const Color(0xFF55AAFF);
    final double pulse =
        1 + (sin((animationValue + (isEnemy ? 0 : 0.42)) * pi * 2) * 0.018);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Transform.scale(
          scale: pulse,
          child: Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(190), width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withAlpha(95),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
                BoxShadow(color: Colors.black.withAlpha(180), blurRadius: 10),
              ],
            ),
            child: CircleAvatar(backgroundImage: AssetImage(asset)),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -3,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(180)),
            ),
            child: Icon(
              isEnemy ? Icons.emoji_events_rounded : Icons.shield_rounded,
              color: isEnemy
                  ? const Color(0xFFFFD23F)
                  : const Color(0xFF62C7FF),
              size: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankChip extends StatelessWidget {
  const _RankChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(210),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withAlpha(85)),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileHpBar extends StatelessWidget {
  const _ProfileHpBar({
    required this.safeHp,
    required this.isEnemy,
    required this.animationValue,
  });

  final int safeHp;
  final bool isEnemy;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final Color shineColor = Colors.white.withAlpha(
      36 + (sin(animationValue * pi * 2) * 14).round(),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(130),
          border: Border.all(color: Colors.white.withAlpha(24)),
        ),
        child: Stack(
          children: <Widget>[
            FractionallySizedBox(
              widthFactor: safeHp / 100,
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isEnemy
                        ? const <Color>[Color(0xFF9A141A), Color(0xFFFF5B5B)]
                        : const <Color>[Color(0xFF1552B5), Color(0xFF57B7FF)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              left: 8,
              right: 44,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: shineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleCard extends StatelessWidget {
  const _BattleCard({
    required this.question,
    required this.index,
    required this.compact,
    required this.animationValue,
    required this.onTap,
  });

  final BattleQuestion question;
  final int index;
  final bool compact;
  final double animationValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDamage = question.effect == QuestionEffect.damage;
    final String cardAsset = isDamage ? _tiuCardAsset : _twkCardAsset;
    final int impact = BattleStateMachine.impactFromWeight(question.weight);
    final Color glow = isDamage
        ? _attackAccentForCategory(question.category, index)
        : const Color(0xFF4ADE80);
    final double bob = sin((animationValue + (index * 0.13)) * pi * 2) * -3;
    final double shinePosition = ((animationValue + index * 0.22) % 1) * 3.4;
    final String label = _questionCardLabel(question, index);

    return Transform.translate(
      offset: Offset(0, bob),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('question-card-${question.id}'),
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: glow.withAlpha(160), width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withAlpha(165),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(color: glow.withAlpha(80), blurRadius: 16),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Image.asset(
                      cardAsset,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Colors.black.withAlpha(50),
                            Colors.black.withAlpha(120),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Transform.translate(
                        offset: Offset((-1.4 + shinePosition) * 60, 0),
                        child: Transform.rotate(
                          angle: -0.35,
                          child: FractionallySizedBox(
                            widthFactor: 0.34,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Colors.transparent,
                                    Colors.white.withAlpha(44),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Icon(
                      isDamage
                          ? _attackIconForCategory(question.category, index)
                          : Icons.favorite_rounded,
                      color: glow,
                      size: compact ? 15 : 17,
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 6,
                    child: Text(
                      isDamage ? '$impact' : '+$impact',
                      style: GoogleFonts.nunito(
                        color: glow,
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w900,
                        shadows: <Shadow>[
                          Shadow(color: Colors.black, blurRadius: 5),
                          Shadow(color: glow.withAlpha(180), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Container(
                      height: compact ? 16 : 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(188),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(38)),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: compact ? 8 : 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(height: 3, color: glow.withAlpha(190)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _attackAccentForCategory(String category, int index) {
  return switch (category.toLowerCase()) {
    'verbal' => const Color(0xFFA855F7),
    'logika' => const Color(0xFF3EAAFF),
    'numerik' => const Color(0xFFF59E0B),
    _ => switch (index % 3) {
      0 => const Color(0xFFF59E0B),
      1 => const Color(0xFFA855F7),
      _ => const Color(0xFF3EAAFF),
    },
  };
}

IconData _attackIconForCategory(String category, int index) {
  return switch (category.toLowerCase()) {
    'verbal' => Icons.bolt_rounded,
    'logika' => Icons.smart_toy_rounded,
    'numerik' => Icons.local_fire_department_rounded,
    _ => switch (index % 3) {
      0 => Icons.local_fire_department_rounded,
      1 => Icons.bolt_rounded,
      _ => Icons.smart_toy_rounded,
    },
  };
}

String _questionCardLabel(BattleQuestion question, int index) {
  if (question.effect == QuestionEffect.heal) {
    return 'TWK';
  }

  return switch (question.category.toLowerCase()) {
    'verbal' => 'VERBAL',
    'logika' => 'LOGIKA',
    'numerik' => 'NUMERIK',
    _ => switch (index % 3) {
      0 => 'NUMERIK',
      1 => 'VERBAL',
      _ => 'LOGIKA',
    },
  };
}

class _ArenaPanel extends StatelessWidget {
  const _ArenaPanel({
    required this.playerHp,
    required this.opponentHp,
    required this.mode,
    required this.animationValue,
    required this.visualActor,
    required this.visualEffect,
    required this.visualCategory,
    required this.eventId,
  });

  final int playerHp;
  final int opponentHp;
  final BattleMode mode;
  final double animationValue;
  final BattleActor? visualActor;
  final BattleVisualEffect? visualEffect;
  final String? visualCategory;
  final int eventId;

  @override
  Widget build(BuildContext context) {
    final bool enemyMiniLeftDown = opponentHp <= 64;
    final bool enemyMiniRightDown = opponentHp <= 32;
    final bool playerMiniLeftDown = playerHp <= 64;
    final bool playerMiniRightDown = playerHp <= 32;
    final Alignment visualTarget = _visualTargetAlignment(
      actor: visualActor,
      effect: visualEffect,
      eventId: eventId,
      playerHp: playerHp,
      opponentHp: opponentHp,
    );

    return ClipRRect(
      child: Stack(
        children: <Widget>[
          Container(color: const Color(0xFF4B9130)),
          Positioned.fill(
            child: CustomPaint(
              painter: _BattlefieldPainter(time: animationValue, mode: mode),
            ),
          ),
          _TowerNode(
            alignment: _enemyMainAlignment,
            imageAsset: _enemyMainTowerAsset,
            destroyedAsset: _enemyMainTowerDestroyedAsset,
            hpValue: (opponentHp * 30).round(),
            hpProgress: opponentHp / 100,
            mainTower: true,
            destroyed: opponentHp <= 0,
            animationValue: animationValue,
            animationDelay: 0,
          ),
          _TowerNode(
            alignment: _enemyMiniLeftAlignment,
            imageAsset: _enemyMiniTowerAsset,
            destroyedAsset: _enemyMiniTowerDestroyedAsset,
            hpValue: enemyMiniLeftDown ? 0 : (opponentHp * 15).round(),
            hpProgress: enemyMiniLeftDown ? 0 : opponentHp / 100,
            mainTower: false,
            destroyed: enemyMiniLeftDown,
            animationValue: animationValue,
            animationDelay: 0.08,
          ),
          _TowerNode(
            alignment: _enemyMiniRightAlignment,
            imageAsset: _enemyMiniTowerAsset,
            destroyedAsset: _enemyMiniTowerDestroyedAsset,
            hpValue: enemyMiniRightDown ? 0 : (opponentHp * 15).round(),
            hpProgress: enemyMiniRightDown ? 0 : opponentHp / 100,
            mainTower: false,
            destroyed: enemyMiniRightDown,
            animationValue: animationValue,
            animationDelay: 0.16,
          ),
          _TowerNode(
            alignment: _playerMainAlignment,
            imageAsset: _playerMainTowerAsset,
            destroyedAsset: _playerMainTowerDestroyedAsset,
            hpValue: (playerHp * 30).round(),
            hpProgress: playerHp / 100,
            mainTower: true,
            destroyed: playerHp <= 0,
            animationValue: animationValue,
            animationDelay: 0.24,
          ),
          _TowerNode(
            alignment: _playerMiniLeftAlignment,
            imageAsset: _playerMiniTowerAsset,
            destroyedAsset: _playerMiniTowerDestroyedAsset,
            hpValue: playerMiniLeftDown ? 0 : (playerHp * 15).round(),
            hpProgress: playerMiniLeftDown ? 0 : playerHp / 100,
            mainTower: false,
            destroyed: playerMiniLeftDown,
            animationValue: animationValue,
            animationDelay: 0.32,
          ),
          _TowerNode(
            alignment: _playerMiniRightAlignment,
            imageAsset: _playerMiniTowerAsset,
            destroyedAsset: _playerMiniTowerDestroyedAsset,
            hpValue: playerMiniRightDown ? 0 : (playerHp * 15).round(),
            hpProgress: playerMiniRightDown ? 0 : playerHp / 100,
            mainTower: false,
            destroyed: playerMiniRightDown,
            animationValue: animationValue,
            animationDelay: 0.4,
          ),
          _BattleEffectOverlay(
            actor: visualActor,
            effect: visualEffect,
            category: visualCategory,
            eventId: eventId,
            targetAlignment: visualTarget,
          ),
        ],
      ),
    );
  }
}

class _BattleEffectOverlay extends StatelessWidget {
  const _BattleEffectOverlay({
    required this.actor,
    required this.effect,
    required this.category,
    required this.eventId,
    required this.targetAlignment,
  });

  final BattleActor? actor;
  final BattleVisualEffect? effect;
  final String? category;
  final int eventId;
  final Alignment targetAlignment;

  @override
  Widget build(BuildContext context) {
    if (actor == null || effect == null || eventId <= 0) {
      return const SizedBox.shrink();
    }

    final bool isPlayer = actor == BattleActor.player;
    final Alignment fromAlignment = isPlayer
        ? _playerMainAlignment
        : _enemyMainAlignment;
    final String effectKey = '$eventId-${actor!.name}-${effect!.name}';

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: <Widget>[
            if (effect == BattleVisualEffect.heal)
              _HealEffect(
                key: ValueKey<String>('heal-$effectKey'),
                alignment: targetAlignment,
              )
            else
              _PrototypeAttackEffect(
                key: ValueKey<String>('attack-$effectKey'),
                effect: effect!,
                category: category ?? 'numerik',
                fromAlignment: fromAlignment,
                toAlignment: targetAlignment,
                isEnemy: !isPlayer,
              ),
          ],
        ),
      ),
    );
  }
}

Alignment _visualTargetAlignment({
  required BattleActor? actor,
  required BattleVisualEffect? effect,
  required int eventId,
  required int playerHp,
  required int opponentHp,
}) {
  if (actor == null || effect == null) {
    return _enemyMainAlignment;
  }

  if (effect == BattleVisualEffect.heal) {
    if (actor == BattleActor.player) {
      return playerHp <= 42
          ? _playerMainAlignment
          : eventId.isEven
          ? _playerMiniLeftAlignment
          : _playerMiniRightAlignment;
    }

    return opponentHp <= 42
        ? _enemyMainAlignment
        : eventId.isEven
        ? _enemyMiniLeftAlignment
        : _enemyMiniRightAlignment;
  }

  if (actor == BattleActor.player) {
    if (opponentHp <= 38) {
      return _enemyMainAlignment;
    }
    return eventId.isEven ? _enemyMiniLeftAlignment : _enemyMiniRightAlignment;
  }

  if (playerHp <= 38) {
    return _playerMainAlignment;
  }
  return eventId.isEven ? _playerMiniLeftAlignment : _playerMiniRightAlignment;
}

class _PrototypeAttackEffect extends StatefulWidget {
  const _PrototypeAttackEffect({
    super.key,
    required this.effect,
    required this.category,
    required this.fromAlignment,
    required this.toAlignment,
    required this.isEnemy,
  });

  final BattleVisualEffect effect;
  final String category;
  final Alignment fromAlignment;
  final Alignment toAlignment;
  final bool isEnemy;

  @override
  State<_PrototypeAttackEffect> createState() => _PrototypeAttackEffectState();
}

class _PrototypeAttackEffectState extends State<_PrototypeAttackEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: switch (widget.effect) {
        BattleVisualEffect.robot => const Duration(milliseconds: 2200),
        BattleVisualEffect.wizard => const Duration(milliseconds: 980),
        _ => const Duration(milliseconds: 1500),
      },
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _PrototypeAttackPainter(
            progress: _controller.value,
            effect: widget.effect,
            category: widget.category,
            fromAlignment: widget.fromAlignment,
            toAlignment: widget.toAlignment,
            isEnemy: widget.isEnemy,
          ),
        );
      },
    );
  }
}

class _PrototypeAttackPainter extends CustomPainter {
  const _PrototypeAttackPainter({
    required this.progress,
    required this.effect,
    required this.category,
    required this.fromAlignment,
    required this.toAlignment,
    required this.isEnemy,
  });

  final double progress;
  final BattleVisualEffect effect;
  final String category;
  final Alignment fromAlignment;
  final Alignment toAlignment;
  final bool isEnemy;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset from = Offset(
      (fromAlignment.x + 1) * size.width / 2,
      (fromAlignment.y + 1) * size.height / 2,
    );
    final Offset to = Offset(
      (toAlignment.x + 1) * size.width / 2,
      (toAlignment.y + 1) * size.height / 2,
    );
    final Color sideColor = isEnemy
        ? const Color(0xFFFF5050)
        : const Color(0xFF4AA3FF);

    switch (effect) {
      case BattleVisualEffect.cannon:
        _drawCannon(canvas, from, to, sideColor);
      case BattleVisualEffect.wizard:
        _drawWizard(canvas, from, to, sideColor);
      case BattleVisualEffect.robot:
        _drawRobot(canvas, from, to, sideColor);
      case BattleVisualEffect.heal:
        break;
    }
  }

  void _drawCannon(Canvas canvas, Offset from, Offset to, Color sideColor) {
    final Color accent = const Color(0xFFFFA726);
    final double chargeT = (progress / 0.28).clamp(0.0, 1.0);
    final double flyT = ((progress - 0.25) / 0.45).clamp(0.0, 1.0);
    final double impactT = ((progress - 0.62) / 0.38).clamp(0.0, 1.0);
    final double angle = (to - from).direction;
    final Offset ball = Offset.lerp(
      from,
      to,
      Curves.easeInCubic.transform(flyT),
    )!;

    if (progress < 0.66) {
      _drawCannonTurret(
        canvas: canvas,
        center: from,
        angle: angle,
        sideColor: sideColor,
        chargeT: chargeT,
        opacity: 1 - flyT * 0.7,
      );
    }

    if (flyT > 0 && flyT < 1) {
      for (int i = 0; i < 10; i++) {
        final double t = (flyT - i * 0.035).clamp(0.0, 1.0);
        if (t <= 0) {
          continue;
        }
        final Offset pos = Offset.lerp(
          from,
          to,
          Curves.easeInCubic.transform(t),
        )!;
        final double fade = (1 - i / 10) * (1 - flyT * 0.35);
        canvas.drawCircle(
          pos,
          3 + (10 - i) * 0.8,
          Paint()
            ..color = accent.withAlpha(_alpha(fade * 0.55))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }

      canvas.drawCircle(
        ball,
        28,
        Paint()
          ..color = accent.withAlpha(58)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        ball,
        13,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: <Color>[
              const Color(0xFFFFF2B8),
              accent,
              const Color(0xFF331000),
            ],
          ).createShader(Rect.fromCircle(center: ball, radius: 14)),
      );
    }

    if (impactT > 0) {
      _drawImpact(canvas, to, accent, impactT, fire: true);
    }
  }

  void _drawCannonTurret({
    required Canvas canvas,
    required Offset center,
    required double angle,
    required Color sideColor,
    required double chargeT,
    required double opacity,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.9);
    final Paint sidePaint = Paint()
      ..color = sideColor.withAlpha(_alpha(opacity));

    for (final Offset wheel in const <Offset>[Offset(-17, 14), Offset(17, 14)]) {
      canvas.drawCircle(
        wheel,
        9,
        Paint()..color = const Color(0xFF4A2B1A).withAlpha(_alpha(opacity)),
      );
      canvas.drawCircle(
        wheel,
        5,
        Paint()..color = const Color(0xFF8B5A2B).withAlpha(_alpha(opacity)),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-21, -5, 42, 19),
        const Radius.circular(5),
      ),
      sidePaint,
    );
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, -8, 48, 16),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFB8C1CC).withAlpha(_alpha(opacity)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, -6, 10, 12),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF364151).withAlpha(_alpha(opacity)),
    );
    if (chargeT > 0) {
      canvas.drawCircle(
        const Offset(51, 0),
        8 + chargeT * 13,
        Paint()
          ..color = const Color(0xFFFFD36A).withAlpha(
            _alpha(chargeT * opacity * 0.45),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        const Offset(51, 0),
        4 + chargeT * 5,
        Paint()..color = const Color(0xFFFFF0B0).withAlpha(_alpha(opacity)),
      );
    }
    canvas.restore();
  }

  void _drawWizard(Canvas canvas, Offset from, Offset to, Color sideColor) {
    final Color accent = const Color(0xFFA855F7);
    final double castT = (progress / 0.32).clamp(0.0, 1.0);
    final double boltT = ((progress - 0.24) / 0.24).clamp(0.0, 1.0);
    final double flashT = ((progress - 0.48) / 0.52).clamp(0.0, 1.0);
    final double wizardOpacity = progress < 0.58
        ? 1
        : (1 - (progress - 0.58) / 0.25).clamp(0.0, 1.0);

    if (wizardOpacity > 0) {
      _drawWizardCaster(
        canvas,
        from,
        accent,
        castT,
        wizardOpacity,
      );
    }
    if (boltT > 0) {
      _drawLightning(canvas, from, to, boltT, 1 - flashT * 0.8);
    }
    if (flashT > 0) {
      _drawImpact(canvas, to, const Color(0xFF8DDCFF), flashT, fire: false);
    }
  }

  void _drawWizardCaster(
    Canvas canvas,
    Offset center,
    Color accent,
    double castT,
    double opacity,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (isEnemy) {
      canvas.scale(1, -1);
    }
    canvas.scale(0.9);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 28), width: 34, height: 9),
      Paint()..color = Colors.black.withAlpha(_alpha(opacity * 0.22)),
    );
    final Path robe = Path()
      ..moveTo(-15, 30)
      ..quadraticBezierTo(-17, 4, -8, -13)
      ..lineTo(0, -17)
      ..lineTo(8, -13)
      ..quadraticBezierTo(17, 4, 15, 30)
      ..close();
    canvas.drawPath(
      robe,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            accent.withAlpha(_alpha(opacity)),
            const Color(0xFF291171).withAlpha(_alpha(opacity)),
          ],
        ).createShader(const Rect.fromLTWH(-18, -18, 36, 50)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -19), width: 16, height: 19),
      Paint()..color = const Color(0xFFE8C8A0).withAlpha(_alpha(opacity)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -27), width: 28, height: 7),
      Paint()..color = const Color(0xFF21118F).withAlpha(_alpha(opacity)),
    );
    final Path hat = Path()
      ..moveTo(-13, -27)
      ..lineTo(13, -27)
      ..lineTo(3, -53)
      ..close();
    canvas.drawPath(
      hat,
      Paint()..color = const Color(0xFF3926C9).withAlpha(_alpha(opacity)),
    );

    final Paint staffPaint = Paint()
      ..color = const Color(0xFF9B7320).withAlpha(_alpha(opacity))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(16, 28), const Offset(16, -17), staffPaint);
    canvas.drawCircle(
      const Offset(16, -19),
      6 + castT * 7,
      Paint()
        ..color = const Color(0xFFB7F4FF).withAlpha(
          _alpha(opacity * (0.45 + castT * 0.55)),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      const Offset(16, -19),
      4 + castT * 3,
      Paint()..color = Colors.white.withAlpha(_alpha(opacity)),
    );

    if (castT > 0) {
      canvas.drawCircle(
        const Offset(0, 29),
        22 * castT,
        Paint()
          ..color = accent.withAlpha(_alpha(opacity * (1 - castT) * 0.7))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (int i = 0; i < 4; i++) {
        final double angle = i * pi / 2 + progress * pi * 5;
        final Offset rune = Offset(
          cos(angle) * 22 * castT,
          29 + sin(angle) * 22 * castT,
        );
        canvas.drawCircle(
          rune,
          2.4,
          Paint()
            ..color = const Color(0xFFFFE98A).withAlpha(
              _alpha(opacity * castT),
            ),
        );
      }
    }
    canvas.restore();
  }

  void _drawLightning(Canvas canvas, Offset from, Offset to, double boltT, double fade) {
    const int segments = 10;
    final int visible = max(2, (segments * boltT).round());
    for (int pass = 0; pass < 3; pass++) {
      final Paint paint = Paint()
        ..color = (pass == 0 ? const Color(0xFF70B7FF) : Colors.white)
            .withAlpha(_alpha(fade * (pass == 0 ? 0.34 : 0.88)))
        ..strokeWidth = pass == 0 ? 9 : (pass == 1 ? 4 : 1.8)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final Path path = Path();
      for (int i = 0; i <= visible; i++) {
        final Offset point = _boltPoint(from, to, i / segments, pass);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  Offset _boltPoint(Offset from, Offset to, double t, int branch) {
    final Offset base = Offset.lerp(from, to, t)!;
    final Offset delta = to - from;
    final double length = max(1, delta.distance);
    final Offset normal = Offset(-delta.dy / length, delta.dx / length);
    final double zigzag = sin(t * pi * 7 + branch * 1.7 + category.length) * 20;
    return base + normal * zigzag * sin(t * pi);
  }

  void _drawRobot(Canvas canvas, Offset from, Offset to, Color sideColor) {
    final double walkT = (progress / 0.68).clamp(0.0, 1.0);
    final double windupT = ((progress - 0.68) / 0.12).clamp(0.0, 1.0);
    final double slamT = ((progress - 0.80) / 0.20).clamp(0.0, 1.0);
    final Offset current = Offset.lerp(
      from,
      to,
      Curves.easeInOutCubic.transform(walkT),
    )!;
    final double bob = sin(progress * pi * 18) * 3 * (1 - slamT);
    final double stomp =
        -windupT * (isEnemy ? -12 : 12) + slamT * (isEnemy ? 16 : -16);
    final double opacity = progress < 0.92
        ? 1
        : (1 - (progress - 0.92) / 0.08).clamp(0.0, 1.0);

    _drawRobotBody(
      canvas,
      current + Offset(0, bob + stomp),
      sideColor,
      opacity,
      windupT,
      slamT,
    );

    if (slamT > 0) {
      _drawImpact(canvas, to, const Color(0xFFFF8A2A), slamT, fire: true);
      for (int i = 0; i < 6; i++) {
        final double angle = i * pi / 3 + progress;
        final double length = 20 + 42 * (1 - slamT);
        final Offset end = to + Offset(
          cos(angle) * length,
          sin(angle) * length * 0.65,
        );
        canvas.drawLine(
          to,
          end,
          Paint()
            ..color = const Color(0xFF7A2D12).withAlpha(
              _alpha((1 - slamT) * 0.65),
            )
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _drawRobotBody(
    Canvas canvas,
    Offset center,
    Color sideColor,
    double opacity,
    double windupT,
    double slamT,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (isEnemy) {
      canvas.scale(1, -1);
    }
    canvas.scale(0.66);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 28), width: 46, height: 10),
      Paint()..color = Colors.black.withAlpha(_alpha(opacity * 0.22)),
    );
    final int legSwap = (progress * 12).floor().isEven ? 1 : -1;
    final Paint dark = Paint()..color = _darken(sideColor).withAlpha(_alpha(opacity));
    final Paint mid = Paint()..color = sideColor.withAlpha(_alpha(opacity));
    final Paint light = Paint()..color = _lighten(sideColor).withAlpha(_alpha(opacity));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-14, 8, 10, 18 + legSwap * 3),
        const Radius.circular(3),
      ),
      mid,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 8, 10, 18 - legSwap * 3),
        const Radius.circular(3),
      ),
      mid,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -18, 36, 30),
        const Radius.circular(6),
      ),
      mid,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -18, 36, 10),
        const Radius.circular(5),
      ),
      light,
    );
    canvas.drawCircle(
      const Offset(0, -3),
      6,
      Paint()
        ..color = (windupT > 0 || slamT > 0
                ? const Color(0xFFFFD23F)
                : const Color(0xFF66E6FF))
            .withAlpha(_alpha(opacity)),
    );

    final double armRaise = windupT * -0.75 + slamT * 0.9;
    for (final int side in const <int>[-1, 1]) {
      canvas.save();
      canvas.translate(side * 23, -10);
      canvas.rotate(side * armRaise);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, 0, 10, 22),
          const Radius.circular(4),
        ),
        dark,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-7, 18, 14, 8),
          const Radius.circular(3),
        ),
        dark,
      );
      canvas.restore();
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -40, 26, 24),
        const Radius.circular(5),
      ),
      light,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -33, 18, 7),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFB7F4FF).withAlpha(_alpha(opacity)),
    );
    canvas.drawLine(
      const Offset(0, -40),
      const Offset(0, -49),
      Paint()
        ..color = const Color(0xFFB8C4D6).withAlpha(_alpha(opacity))
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      const Offset(0, -51),
      3,
      Paint()..color = const Color(0xFFB7F4FF).withAlpha(_alpha(opacity)),
    );
    canvas.restore();
  }

  void _drawImpact(
    Canvas canvas,
    Offset center,
    Color color,
    double t, {
    required bool fire,
  }) {
    final double fade = (1 - t).clamp(0.0, 1.0);
    final double flashFade = (1 - t * 2).clamp(0.0, 1.0);
    if (flashFade > 0) {
      canvas.drawCircle(
        center,
        16 + t * 48,
        Paint()
          ..color = Colors.white.withAlpha(_alpha(flashFade * 0.55))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawCircle(
      center,
      18 + t * (fire ? 58 : 70),
      Paint()
        ..shader = RadialGradient(
          colors: fire
              ? <Color>[
                  const Color(0xFFFFF0B0).withAlpha(_alpha(fade * 0.88)),
                  color.withAlpha(_alpha(fade * 0.65)),
                  Colors.transparent,
                ]
              : <Color>[
                  Colors.white.withAlpha(_alpha(fade * 0.72)),
                  color.withAlpha(_alpha(fade * 0.5)),
                  Colors.transparent,
                ],
        ).createShader(Rect.fromCircle(center: center, radius: 78)),
    );

    for (int ring = 0; ring < 3; ring++) {
      final double rt = ((t - ring * 0.1) / (1 - ring * 0.1)).clamp(0.0, 1.0);
      if (rt <= 0) {
        continue;
      }
      canvas.drawCircle(
        center,
        18 + rt * (86 + ring * 22),
        Paint()
          ..color = color.withAlpha(_alpha((1 - rt) * 0.72))
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4 - ring) * (1 - rt),
      );
    }

    for (int i = 0; i < 10; i++) {
      final double angle = i * pi * 0.2 + progress * 4;
      final double distance = t * (46 + i * 5);
      canvas.drawCircle(
        center + Offset(cos(angle) * distance, sin(angle) * distance),
        2.2 + (1 - t) * 3,
        Paint()..color = color.withAlpha(_alpha(fade * 0.85)),
      );
    }
  }

  int _alpha(double value) {
    return (value.clamp(0.0, 1.0) * 255).round();
  }

  Color _darken(Color color) {
    return Color.fromARGB(
      color.alpha,
      (color.red * 0.62).round(),
      (color.green * 0.62).round(),
      (color.blue * 0.62).round(),
    );
  }

  Color _lighten(Color color) {
    return Color.fromARGB(
      color.alpha,
      min(255, (color.red * 1.22).round()),
      min(255, (color.green * 1.22).round()),
      min(255, (color.blue * 1.22).round()),
    );
  }

  @override
  bool shouldRepaint(covariant _PrototypeAttackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.effect != effect ||
        oldDelegate.fromAlignment != fromAlignment ||
        oldDelegate.toAlignment != toAlignment ||
        oldDelegate.isEnemy != isEnemy;
  }
}

class _ProjectileAttackEffect extends StatefulWidget {
  const _ProjectileAttackEffect({
    super.key,
    required this.fromAlignment,
    required this.toAlignment,
    required this.color,
    required this.trailColor,
  });

  final Alignment fromAlignment;
  final Alignment toAlignment;
  final Color color;
  final Color trailColor;

  @override
  State<_ProjectileAttackEffect> createState() =>
      _ProjectileAttackEffectState();
}

class _ProjectileAttackEffectState extends State<_ProjectileAttackEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ProjectilePainter(
            progress: _controller.value,
            fromAlignment: widget.fromAlignment,
            toAlignment: widget.toAlignment,
            color: widget.color,
            trailColor: widget.trailColor,
          ),
        );
      },
    );
  }
}

class _ProjectilePainter extends CustomPainter {
  const _ProjectilePainter({
    required this.progress,
    required this.fromAlignment,
    required this.toAlignment,
    required this.color,
    required this.trailColor,
  });

  final double progress;
  final Alignment fromAlignment;
  final Alignment toAlignment;
  final Color color;
  final Color trailColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset from = Offset(
      (fromAlignment.x + 1) / 2 * size.width,
      (fromAlignment.y + 1) / 2 * size.height,
    );
    final Offset to = Offset(
      (toAlignment.x + 1) / 2 * size.width,
      (toAlignment.y + 1) / 2 * size.height,
    );

    final double travelPhase = 0.6;
    final double travelT = (progress / travelPhase).clamp(0.0, 1.0);
    final double curvedTravel = Curves.easeInOutCubic.transform(travelT);
    final Offset current = Offset.lerp(from, to, curvedTravel)!;

    // ── Screen flash on impact ──
    final double impactT = ((progress - 0.52) / 0.48).clamp(0.0, 1.0);
    if (impactT > 0 && impactT < 0.3) {
      final double flashOpacity = (1 - impactT / 0.3) * 0.15;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = color.withAlpha((flashOpacity * 255).round()),
      );
    }

    // ── Trail particles ──
    if (travelT < 1.0) {
      for (int i = 0; i < 8; i++) {
        final double trailDelay = i * 0.04;
        final double trailProgress = ((curvedTravel - trailDelay)).clamp(
          0.0,
          1.0,
        );
        if (trailProgress <= 0) continue;
        final Offset trailPos = Offset.lerp(from, to, trailProgress)!;
        final double trailFade = (1 - (i / 8.0)) * (1 - travelT);
        final double jitterX = sin(i * 2.3 + progress * 20) * 6;
        final double jitterY = cos(i * 3.1 + progress * 15) * 4;
        canvas.drawCircle(
          trailPos + Offset(jitterX, jitterY),
          3.5 + (8 - i) * 0.8,
          Paint()
            ..color = trailColor.withAlpha((trailFade * 140).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // ── Projectile orb ──
    if (travelT < 1.0) {
      final double orbSize = 16 + sin(curvedTravel * pi) * 6;
      final double fadeOut = progress < 0.55
          ? 1.0
          : max(0, 1 - (progress - 0.55) / 0.15);
      // Outer glow
      canvas.drawCircle(
        current,
        orbSize * 2.2,
        Paint()
          ..color = color.withAlpha((fadeOut * 60).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      // Mid glow
      canvas.drawCircle(
        current,
        orbSize * 1.4,
        Paint()
          ..color = color.withAlpha((fadeOut * 150).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      // Core
      canvas.drawCircle(
        current,
        orbSize * 0.7,
        Paint()..color = Colors.white.withAlpha((fadeOut * 230).round()),
      );
    }

    // ── Impact: expanding shockwave rings ──
    if (impactT > 0) {
      final double impactFade = max(0, 1 - impactT);

      // Ring 1 — fast expanding
      final double ring1Radius = 20 + impactT * 120;
      canvas.drawCircle(
        to,
        ring1Radius,
        Paint()
          ..color = color.withAlpha((impactFade * 160).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * impactFade
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Ring 2 — slower
      final double ring2T = ((impactT - 0.08) / 0.92).clamp(0.0, 1.0);
      if (ring2T > 0) {
        final double ring2Fade = max(0, 1 - ring2T);
        final double ring2Radius = 14 + ring2T * 80;
        canvas.drawCircle(
          to,
          ring2Radius,
          Paint()
            ..color = color.withAlpha((ring2Fade * 120).round())
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * ring2Fade,
        );
      }

      // Ring 3 — slowest, widest
      final double ring3T = ((impactT - 0.15) / 0.85).clamp(0.0, 1.0);
      if (ring3T > 0) {
        final double ring3Fade = max(0, 1 - ring3T);
        canvas.drawCircle(
          to,
          10 + ring3T * 140,
          Paint()
            ..color = color.withAlpha((ring3Fade * 60).round())
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * ring3Fade
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      // Central fireball glow
      if (impactT < 0.5) {
        final double fireT = impactT / 0.5;
        final double fireFade = 1 - fireT;
        canvas.drawCircle(
          to,
          12 + fireT * 40,
          Paint()
            ..color = color.withAlpha((fireFade * 100).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
        );
        canvas.drawCircle(
          to,
          8 + fireT * 20,
          Paint()
            ..color = Colors.white.withAlpha((fireFade * 180).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      // Scatter sparks
      for (int i = 0; i < 6; i++) {
        final double angle = i * pi / 3 + impactT * 2;
        final double dist = impactT * 60 + i * 8;
        final double sparkFade = max(0, 1 - impactT * 1.2);
        if (sparkFade <= 0) continue;
        final Offset sparkPos =
            to + Offset(cos(angle) * dist, sin(angle) * dist);
        canvas.drawCircle(
          sparkPos,
          2.5 + (1 - impactT) * 2,
          Paint()
            ..color = color.withAlpha((sparkFade * 200).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProjectilePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _HealEffect extends StatefulWidget {
  const _HealEffect({super.key, required this.alignment});

  final Alignment alignment;

  @override
  State<_HealEffect> createState() => _HealEffectState();
}

class _HealEffectState extends State<_HealEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _HealEffectPainter(
            progress: _controller.value,
            alignment: widget.alignment,
          ),
        );
      },
    );
  }
}

class _HealEffectPainter extends CustomPainter {
  const _HealEffectPainter({required this.progress, required this.alignment});

  final double progress;
  final Alignment alignment;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(
      (alignment.x + 1) / 2 * size.width,
      (alignment.y + 1) / 2 * size.height,
    );
    final double fade = max(0, 1 - progress);

    // ── Expanding heal rings ──
    for (int i = 0; i < 3; i++) {
      final double ringDelay = i * 0.12;
      final double ringT = ((progress - ringDelay) / (1 - ringDelay)).clamp(
        0.0,
        1.0,
      );
      final double ringFade = max(0, 1 - ringT);
      final double radius = 18 + ringT * (60 + i * 20);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF4ADE80).withAlpha((ringFade * 140).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * ringFade
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ── Central glow ──
    if (progress < 0.6) {
      final double glowT = progress / 0.6;
      final double glowFade = 1 - glowT;
      canvas.drawCircle(
        center,
        14 + glowT * 30,
        Paint()
          ..color = const Color(0xFF22C55E).withAlpha((glowFade * 80).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawCircle(
        center,
        8 + glowT * 14,
        Paint()
          ..color = Colors.white.withAlpha((glowFade * 150).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // ── Rising heal particles ──
    for (int i = 0; i < 8; i++) {
      final double pDelay = i * 0.06;
      final double pT = ((progress - pDelay) / (1 - pDelay)).clamp(0.0, 1.0);
      if (pT <= 0) continue;
      final double pFade = max(0, 1 - pT);
      final double angle = i * pi / 4;
      final double dist = 14 + pT * 50;
      final Offset pos =
          center +
          Offset(cos(angle) * dist * 0.6, -pT * 55 + sin(angle) * dist * 0.3);
      canvas.drawCircle(
        pos,
        3 + (1 - pT) * 3,
        Paint()
          ..color = const Color(0xFF4ADE80).withAlpha((pFade * 200).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // ── + symbol ──
    if (fade > 0.3) {
      final double symbolFade = ((fade - 0.3) / 0.7).clamp(0.0, 1.0);
      final double symbolScale =
          0.5 + Curves.easeOutBack.transform(min(1, progress * 2)) * 0.7;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(symbolScale);
      final Paint plusPaint = Paint()
        ..color = const Color(0xFF4ADE80).withAlpha((symbolFade * 230).round())
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-14, 0), const Offset(14, 0), plusPaint);
      canvas.drawLine(const Offset(0, -14), const Offset(0, 14), plusPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HealEffectPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _TowerNode extends StatelessWidget {
  const _TowerNode({
    required this.alignment,
    required this.imageAsset,
    required this.destroyedAsset,
    required this.hpValue,
    required this.hpProgress,
    required this.mainTower,
    required this.destroyed,
    required this.animationValue,
    required this.animationDelay,
  });

  final Alignment alignment;
  final String imageAsset;
  final String destroyedAsset;
  final int hpValue;
  final double hpProgress;
  final bool mainTower;
  final bool destroyed;
  final double animationValue;
  final double animationDelay;

  @override
  Widget build(BuildContext context) {
    final double towerImageSize = mainTower ? 88 : 66;
    final double padWidth = mainTower ? 118 : 88;
    final double padHeight = mainTower ? 96 : 76;
    final double bob = destroyed
        ? 0
        : sin((animationValue + animationDelay) * pi * 2) * 4;
    final Color hpColor = hpProgress <= 0.32
        ? const Color(0xFFEF4444)
        : hpProgress <= 0.64
        ? const Color(0xFFFFD23F)
        : const Color(0xFF25C67A);

    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: padWidth,
              height: padHeight,
              child: Center(
                child: SizedBox(
                  width: towerImageSize,
                  height: towerImageSize,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: Tween<double>(begin: 0.86, end: 1).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: Opacity(
                      key: ValueKey<String>(
                        destroyed ? destroyedAsset : imageAsset,
                      ),
                      opacity: destroyed ? 0.72 : 1,
                      child: Image.asset(
                        destroyed ? destroyedAsset : imageAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: mainTower ? 76 : 56,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  border: Border.all(color: Colors.white.withAlpha(28)),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: hpProgress.clamp(0.0, 1.0).toDouble(),
                    child: Container(color: hpColor),
                  ),
                ),
              ),
            ),
            Text(
              '$hpValue',
              style: GoogleFonts.nunito(
                color: Colors.white.withAlpha(235),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                shadows: <Shadow>[
                  Shadow(color: Colors.black.withAlpha(220), blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
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
    required this.playerDisplayName,
  });

  final BattleState state;
  final VoidCallback onClaimReward;
  final VoidCallback onReplay;
  final VoidCallback onReset;
  final String playerDisplayName;

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
      BattleOutcome.win => 'VICTORY!',
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
    const String scoreDivider = '-';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 760;
        final bool veryCompact = constraints.maxHeight < 700;
        final double badgeSize = veryCompact
            ? 118
            : compact
            ? 132
            : 156;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
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
                            label: playerDisplayName.toUpperCase(),
                            value: '${state.playerPoints}',
                            color: isVictory
                                ? scoreAccent
                                : const Color(0xFF9EB0D7),
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
                            color: isDefeat
                                ? const Color(0xFFD94646)
                                : const Color(0xFFB7C4E3),
                            compact: compact,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 12 : 18),
                    Divider(
                      color: AppColors.warriorNavy.withAlpha(20),
                      height: 1,
                    ),
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
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.levelUpTeal,
                  ),
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
                onPressed: onReset,
                child: Text(
                  'Menu Arena',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFAEBEE1),
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
            ],
          ),
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
          child: Icon(icon, size: size * 0.35, color: accent),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _ArenaToast extends StatelessWidget {
  const _ArenaToast({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color accent = isError
        ? const Color(0xFFFFD23F)
        : const Color(0xFF22D3EE);
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(126),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withAlpha(120)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: accent.withAlpha(150), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      color: Colors.white.withAlpha(232),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      final Color darkBackground = isError
          ? const Color(0xFF5D1F2A)
          : const Color(0xFF173763);
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
              decoration: BoxDecoration(color: marker, shape: BoxShape.circle),
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

    final Color background = isError
        ? const Color(0xFFFFECE8)
        : const Color(0xFFE4F5F6);
    final Color foreground = isError
        ? const Color(0xFF8F2D2A)
        : AppColors.levelUpTeal;

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
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaPreview extends StatelessWidget {
  const _ArenaPreview({required this.playerName});

  final String playerName;

  @override
  Widget build(BuildContext context) {
    final String safePlayerName = playerName.trim().isEmpty
        ? 'Kamu'
        : playerName;
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
            Positioned.fill(child: CustomPaint(painter: _ArenaRingPainter())),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _AvatarBadge(label: safePlayerName, isEnemy: false),
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
                    _AvatarBadge(label: 'Lawan', isEnemy: true),
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
        SizedBox(
          width: 104,
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: tint,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _BattlefieldPainter extends CustomPainter {
  const _BattlefieldPainter({required this.time, required this.mode});

  final double time;
  final BattleMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final Rect bounds = Offset.zero & size;
    final double tick = time * pi * 2;
    final double riverOffset = time * 80;

    final Paint grassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF4F9B35), Color(0xFF3E852B)],
      ).createShader(bounds);
    canvas.drawRect(bounds, grassPaint);

    const double tileSize = 28;
    final Paint tilePaint = Paint()..color = Colors.white.withAlpha(12);
    final Paint tileShadePaint = Paint()..color = Colors.black.withAlpha(5);
    for (double x = 0; x < width; x += tileSize) {
      for (double y = 0; y < height; y += tileSize) {
        final int tx = (x / tileSize).floor();
        final int ty = (y / tileSize).floor();
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          (tx + ty).isEven ? tilePaint : tileShadePaint,
        );
      }
    }

    _drawCloudShadow(canvas, size, 0.04, 0.18, 0.44, 0.09, 0.10, time);
    _drawCloudShadow(canvas, size, 0.52, 0.08, 0.36, 0.07, 0.08, time + 0.3);
    _drawCloudShadow(canvas, size, 0.26, 0.72, 0.50, 0.10, 0.07, time + 0.6);

    final double laneWidth = (width * 0.22).clamp(92.0, 110.0).toDouble();
    final double midY = height * 0.46;
    final double crossHeight = 68;
    final Paint pathPaint = Paint()..color = const Color(0xFFCBA65F);
    final Paint pathShade = Paint()..color = Colors.black.withAlpha(24);

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(width / 2, height / 2),
        width: laneWidth,
        height: height,
      ),
      pathPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(width / 2 - laneWidth / 2, 0, 5, height),
      pathShade,
    );
    canvas.drawRect(
      Rect.fromLTWH(width / 2 + laneWidth / 2 - 5, 0, 5, height),
      pathShade,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(width / 2, midY),
        width: width,
        height: crossHeight,
      ),
      pathPaint,
    );
    canvas.drawRect(Rect.fromLTWH(0, midY - 34, width, 5), pathShade);
    canvas.drawRect(Rect.fromLTWH(0, midY + 29, width, 5), pathShade);

    final double scale = min(
      width / 420,
      height / 560,
    ).clamp(0.82, 1.25).toDouble();
    _drawStonePad(canvas, size, 0.148, 0.291, 84 * scale, 72 * scale);
    _drawStonePad(canvas, size, 0.852, 0.291, 84 * scale, 72 * scale);
    _drawStonePad(canvas, size, 0.148, 0.611, 84 * scale, 72 * scale);
    _drawStonePad(canvas, size, 0.852, 0.611, 84 * scale, 72 * scale);
    _drawStonePad(canvas, size, 0.5, 0.205, 116 * scale, 112 * scale);
    _drawStonePad(canvas, size, 0.5, 0.696, 116 * scale, 112 * scale);

    final double riverHeight = (height * 0.11).clamp(54.0, 78.0).toDouble();
    final Rect riverRect = Rect.fromCenter(
      center: Offset(width / 2, midY),
      width: width,
      height: riverHeight + 16,
    );
    final Paint riverPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF0AB8D8),
          Color(0xFF18E8FF),
          Color(0xFF18E8FF),
          Color(0xFF0AB8D8),
        ],
        stops: <double>[0, 0.35, 0.65, 1],
      ).createShader(riverRect);

    final Path riverPath = Path();
    riverPath.moveTo(0, midY - riverHeight / 2);
    for (double x = 0; x <= width; x += 3) {
      riverPath.lineTo(
        x,
        midY - riverHeight / 2 + sin((x + riverOffset) * 0.07) * 5,
      );
    }
    riverPath.lineTo(width, midY + riverHeight / 2);
    for (double x = width; x >= 0; x -= 3) {
      riverPath.lineTo(
        x,
        midY + riverHeight / 2 + sin((x + riverOffset * 0.8) * 0.09) * 4,
      );
    }
    riverPath.close();
    canvas.drawPath(riverPath, riverPaint);

    final Paint foamPaint = Paint()..color = Colors.white.withAlpha(78);
    for (int i = 0; i < 5; i++) {
      final double cx = ((i * 90 + riverOffset * 3.5) % (width + 60)) - 30;
      final double cy = midY + sin(i * 1.3) * 7;
      final double pulse = 0.72 + sin(tick * 3 + i) * 0.16;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(-0.18);
      canvas.scale(pulse, pulse);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 44, height: 10),
        foamPaint,
      );
      canvas.restore();
    }

    final Paint riverEdge = Paint()
      ..color = Colors.white.withAlpha(46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Path topEdge = Path()..moveTo(0, midY - riverHeight / 2);
    for (double x = 0; x <= width; x += 3) {
      topEdge.lineTo(
        x,
        midY - riverHeight / 2 + sin((x + riverOffset) * 0.07) * 5,
      );
    }
    canvas.drawPath(topEdge, riverEdge);

    final Paint bridgePaint = Paint()..color = const Color(0xFF7A6A4A);
    final Paint bridgeGlow = Paint()..color = const Color(0xFFE8B840);
    for (final Offset offset in <Offset>[
      Offset(width / 2 - 40, midY - 22),
      Offset(width / 2 + 16, midY - 22),
      Offset(width / 2 - 40, midY + 4),
      Offset(width / 2 + 16, midY + 4),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(offset.dx, offset.dy, 24, 18),
          const Radius.circular(3),
        ),
        bridgePaint,
      );
    }
    final double bridgePulse = 1 + 0.12 * sin(tick * 2.5);
    canvas.drawCircle(
      Offset(width / 2 - 46, midY - 8),
      7 * bridgePulse,
      bridgeGlow,
    );
    canvas.drawCircle(
      Offset(width / 2 + 46, midY - 8),
      7 * bridgePulse,
      bridgeGlow,
    );

    final double flicker = 0.86 + 0.14 * sin(tick * 12 + 1);
    _drawTorch(canvas, 8, midY - riverHeight / 2 - 36, flicker);
    _drawTorch(canvas, 8, midY + riverHeight / 2 + 36, flicker * 0.92);
    _drawTorch(canvas, width - 8, midY - riverHeight / 2 - 36, flicker * 0.96);
    _drawTorch(canvas, width - 8, midY + riverHeight / 2 + 36, flicker);

    _drawSideTrees(canvas, size, time);

    _drawAmbientSpark(canvas, size, 0.18, 0.82, time, const Color(0xFF7DD3FC));
    _drawAmbientSpark(
      canvas,
      size,
      0.82,
      0.23,
      time + 0.35,
      const Color(0xFFFCD34D),
    );
    _drawAmbientSpark(
      canvas,
      size,
      0.52,
      0.50,
      time + 0.62,
      const Color(0xFF86EFAC),
    );

    if (mode == BattleMode.online) {
      _drawModeBadge(canvas, size);
    }
  }

  void _drawCloudShadow(
    Canvas canvas,
    Size size,
    double xRatio,
    double yRatio,
    double wRatio,
    double hRatio,
    double alpha,
    double phase,
  ) {
    final double width = size.width * wRatio;
    final double height = size.height * hRatio;
    final double x =
        ((size.width * xRatio + phase * 38) % (size.width + width)) - width;
    final double y = size.height * yRatio;
    final Rect rect = Rect.fromCenter(
      center: Offset(x + width / 2, y + height / 2),
      width: width,
      height: height,
    );
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.black.withAlpha((alpha * 255).round()),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawOval(rect, paint);
  }

  void _drawStonePad(
    Canvas canvas,
    Size size,
    double xRatio,
    double yRatio,
    double width,
    double height,
  ) {
    final Rect rect = Rect.fromCenter(
      center: Offset(size.width * xRatio, size.height * yRatio),
      width: width,
      height: height,
    );
    final RRect rounded = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(8),
    );
    final Paint padPaint = Paint()..color = const Color(0xFF9E8C6A);
    final Paint gridPaint = Paint()
      ..color = Colors.black.withAlpha(26)
      ..strokeWidth = 1;
    canvas.drawRRect(rounded, padPaint);
    canvas.save();
    canvas.clipRRect(rounded);
    for (double x = rect.left; x < rect.right; x += 18) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }
    for (double y = rect.top; y < rect.bottom; y += 18) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }
    canvas.restore();
  }

  void _drawTorch(Canvas canvas, double x, double y, double flicker) {
    final Paint corePaint = Paint()
      ..color = const Color(0xFFFFAA00).withAlpha(230);
    final Paint glowPaint = Paint()
      ..color = const Color(0xFFFFAA00).withAlpha(56);
    canvas.save();
    canvas.drawCircle(Offset(x, y), 16 * flicker, glowPaint);
    canvas.drawCircle(Offset(x, y), 5 * flicker, corePaint);
    canvas.restore();
  }

  void _drawAmbientSpark(
    Canvas canvas,
    Size size,
    double xRatio,
    double yRatio,
    double phase,
    Color color,
  ) {
    final double progress = phase % 1;
    final Offset center = Offset(
      size.width * xRatio + sin(progress * pi * 2) * 12,
      size.height * yRatio - progress * 54,
    );
    final Paint paint = Paint()
      ..color = color.withAlpha(((1 - progress) * 110).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, 3 + progress * 2, paint);
  }

  void _drawSideTrees(Canvas canvas, Size size, double time) {
    final List<({double x, double y, double scale, Color dark, Color mid})>
    trees = <({double x, double y, double scale, Color dark, Color mid})>[
      (
        x: 0.02,
        y: 0.15,
        scale: 0.86,
        dark: const Color(0xFF14532D),
        mid: const Color(0xFF2F8D3A),
      ),
      (
        x: 0.02,
        y: 0.37,
        scale: 0.78,
        dark: const Color(0xFF166534),
        mid: const Color(0xFF3CA44A),
      ),
      (
        x: 0.02,
        y: 0.78,
        scale: 0.9,
        dark: const Color(0xFF14532D),
        mid: const Color(0xFF2F8D3A),
      ),
      (
        x: 0.98,
        y: 0.15,
        scale: 0.8,
        dark: const Color(0xFF14532D),
        mid: const Color(0xFF35A047),
      ),
      (
        x: 0.98,
        y: 0.39,
        scale: 0.92,
        dark: const Color(0xFF166534),
        mid: const Color(0xFF3CA44A),
      ),
      (
        x: 0.98,
        y: 0.78,
        scale: 0.84,
        dark: const Color(0xFF14532D),
        mid: const Color(0xFF2F8D3A),
      ),
    ];

    for (int i = 0; i < trees.length; i++) {
      final tree = trees[i];
      final double sway = sin(time * pi * 2 + i * 1.4) * 1.8;
      final Offset base = Offset(size.width * tree.x, size.height * tree.y);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.scale(tree.scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, 2, 6, 20),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF6B3F1D),
      );
      canvas.translate(sway, 0);
      canvas.drawCircle(Offset.zero, 13, Paint()..color = tree.dark);
      canvas.drawCircle(const Offset(0, -9), 11, Paint()..color = tree.mid);
      canvas.drawCircle(
        const Offset(0, -17),
        8,
        Paint()..color = const Color(0xFF57C65D),
      );
      canvas.restore();
    }
  }

  void _drawModeBadge(Canvas canvas, Size size) {
    final Rect rect = Rect.fromCenter(
      center: Offset(size.width / 2, 14),
      width: 78,
      height: 18,
    );
    final Paint paint = Paint()..color = const Color(0xAA9333EA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      paint,
    );
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 10),
          )
          ..pushStyle(
            ui.TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          )
          ..addText('VS PLAYER');
    final ui.Paragraph paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: rect.width));
    canvas.drawParagraph(
      paragraph,
      Offset(rect.left, rect.top + (rect.height - paragraph.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BattlefieldPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.mode != mode;
  }
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

    final Paint dotPaint = Paint()
      ..color = AppColors.levelUpTeal.withAlpha(110);
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
