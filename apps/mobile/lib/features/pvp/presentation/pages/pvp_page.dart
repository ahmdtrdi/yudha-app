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
const String _playerAttackAsset = 'assets/game/attack_stright_blue.png';
const String _enemyAttackAsset = 'assets/game/attack_side_red.png';
const String _impactExplosionAsset = 'assets/game/impact_explosion.png';

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
          next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage;
      final bool hasNewStatus =
          next.errorMessage == null &&
          next.statusMessage != null &&
          next.statusMessage != previous?.statusMessage;

      if (!hasNewError && !hasNewStatus) {
        return;
      }

      final String message = hasNewError
          ? next.errorMessage!
          : next.statusMessage!;
      final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
        context,
      );
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
            backgroundColor: hasNewError
                ? const Color(0xFF8F2D2A)
                : AppColors.levelUpTeal,
          ),
        );
    });

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

class _ArenaMenuSection extends StatelessWidget {
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
                          onTap: onStartBot,
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
                          onTap: onStartPlayer,
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
                          onTap: onBackHome,
                        ),
                        SizedBox(height: compact ? 18 : 24),
                        _ArenaTipStrip(playerDisplayName: playerDisplayName),
                      ],
                    ),
                  ),
                );
              },
            ),
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
    required this.onPickQuestion,
  });

  final BattleState state;
  final String playerDisplayName;
  final VoidCallback onPause;
  final ValueChanged<BattleQuestion> onPickQuestion;

  @override
  State<_InBattleSection> createState() => _InBattleSectionState();
}

class _InBattleSectionState extends State<_InBattleSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 760;
        final double bottomHudHeight = compact ? 156 : 184;

        return AnimatedBuilder(
          animation: _ambientController,
          builder: (BuildContext context, Widget? child) {
            final double animationValue = _ambientController.value;
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: _ArenaPanel(
                    playerHp: widget.state.playerHp,
                    opponentHp: widget.state.opponentHp,
                    mode: widget.state.mode,
                    animationValue: animationValue,
                    statusMessage:
                        widget.state.errorMessage ??
                        (widget.state.answeredQuestionIds.isEmpty
                            ? 'Pilih kartu untuk menyerang atau heal.'
                            : widget.state.statusMessage),
                    statusIsError: widget.state.errorMessage != null,
                    statusBottomInset: bottomHudHeight + 8,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _HudStrip(
                    isEnemy: true,
                    playerName: widget.state.opponentName,
                    hp: widget.state.opponentHp,
                    points: widget.state.opponentPoints,
                    compact: compact,
                    animationValue: animationValue,
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
                  child: _HudStrip(
                    isEnemy: false,
                    playerName: widget.playerDisplayName,
                    hp: widget.state.playerHp,
                    points: widget.state.playerPoints,
                    questions: widget.state.availableQuestions.take(4).toList(),
                    onPickQuestion: widget.onPickQuestion,
                    compact: compact,
                    animationValue: animationValue,
                  ),
                ),
              ],
            );
          },
        );
      },
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
                            const SizedBox(width: 12),
                            Icon(
                              Icons.star_rounded,
                              color: const Color(0xFFFFD23F).withAlpha(220),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$points',
                              style: GoogleFonts.nunito(
                                color: Colors.white.withAlpha(190),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
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
        ? _attackAccentForIndex(index)
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
                      filterQuality: FilterQuality.high,
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
                          ? _attackIconForIndex(index)
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

Color _attackAccentForIndex(int index) {
  return switch (index % 3) {
    0 => const Color(0xFFF59E0B),
    1 => const Color(0xFFA855F7),
    _ => const Color(0xFF3EAAFF),
  };
}

IconData _attackIconForIndex(int index) {
  return switch (index % 3) {
    0 => Icons.local_fire_department_rounded,
    1 => Icons.bolt_rounded,
    _ => Icons.smart_toy_rounded,
  };
}

String _questionCardLabel(BattleQuestion question, int index) {
  if (question.effect == QuestionEffect.heal) {
    return 'TWK';
  }

  final String id = question.id.toLowerCase();
  if (id.startsWith('tiu')) {
    return index.isEven ? 'NUMERIK' : 'VERBAL';
  }
  if (id.startsWith('tkp')) {
    return 'SPASIAL';
  }
  if (id.startsWith('twk')) {
    return 'TWK';
  }

  return switch (index % 3) {
    0 => 'NUMERIK',
    1 => 'VERBAL',
    _ => 'SPASIAL',
  };
}

class _ArenaPanel extends StatelessWidget {
  const _ArenaPanel({
    required this.playerHp,
    required this.opponentHp,
    required this.mode,
    required this.animationValue,
    required this.statusMessage,
    required this.statusIsError,
    required this.statusBottomInset,
  });

  final int playerHp;
  final int opponentHp;
  final BattleMode mode;
  final double animationValue;
  final String? statusMessage;
  final bool statusIsError;
  final double statusBottomInset;

  @override
  Widget build(BuildContext context) {
    final bool playerAttack =
        statusMessage?.contains('Musuh menerima') ?? false;
    final bool enemyAttack = statusMessage?.contains('Kamu menerima') ?? false;
    final bool playerHeal = statusMessage?.contains('Kamu memulihkan') ?? false;
    final bool enemyHeal = statusMessage?.contains('Musuh memulihkan') ?? false;
    final bool enemyMiniLeftDown = opponentHp <= 64;
    final bool enemyMiniRightDown = opponentHp <= 32;
    final bool playerMiniLeftDown = playerHp <= 64;
    final bool playerMiniRightDown = playerHp <= 32;
    final String effectKey = statusMessage ?? 'idle-$playerHp-$opponentHp';

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
            alignment: const Alignment(0, -0.59),
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
            alignment: const Alignment(-0.704, -0.418),
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
            alignment: const Alignment(0.704, -0.418),
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
            alignment: const Alignment(0, 0.392),
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
            alignment: const Alignment(-0.704, 0.222),
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
            alignment: const Alignment(0.704, 0.222),
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
            playerAttack: playerAttack,
            enemyAttack: enemyAttack,
            playerHeal: playerHeal,
            enemyHeal: enemyHeal,
            effectKey: effectKey,
          ),
          if (statusMessage != null)
            Positioned(
              left: 18,
              right: 18,
              bottom: statusBottomInset,
              child: _ArenaToast(text: statusMessage!, isError: statusIsError),
            ),
        ],
      ),
    );
  }
}

class _BattleEffectOverlay extends StatelessWidget {
  const _BattleEffectOverlay({
    required this.playerAttack,
    required this.enemyAttack,
    required this.playerHeal,
    required this.enemyHeal,
    required this.effectKey,
  });

  final bool playerAttack;
  final bool enemyAttack;
  final bool playerHeal;
  final bool enemyHeal;
  final String effectKey;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: <Widget>[
            if (playerAttack)
              _AttackEffect(
                key: ValueKey<String>('player-attack-$effectKey'),
                asset: _playerAttackAsset,
                fromAlignment: const Alignment(0, 0.392),
                toAlignment: const Alignment(0, -0.59),
                rotationTurns: 0,
                color: const Color(0xFF55AAFF),
              ),
            if (enemyAttack)
              _AttackEffect(
                key: ValueKey<String>('enemy-attack-$effectKey'),
                asset: _enemyAttackAsset,
                fromAlignment: const Alignment(0, -0.59),
                toAlignment: const Alignment(0, 0.392),
                rotationTurns: 0,
                color: const Color(0xFFFF5555),
              ),
            if (playerHeal)
              _HealPulse(
                key: ValueKey<String>('player-heal-$effectKey'),
                alignment: const Alignment(0, 0.392),
              ),
            if (enemyHeal)
              _HealPulse(
                key: ValueKey<String>('enemy-heal-$effectKey'),
                alignment: const Alignment(0, -0.59),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttackEffect extends StatefulWidget {
  const _AttackEffect({
    super.key,
    required this.asset,
    required this.fromAlignment,
    required this.toAlignment,
    required this.rotationTurns,
    required this.color,
  });

  final String asset;
  final Alignment fromAlignment;
  final Alignment toAlignment;
  final double rotationTurns;
  final Color color;

  @override
  State<_AttackEffect> createState() => _AttackEffectState();
}

class _AttackEffectState extends State<_AttackEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
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
        final double raw = _controller.value;
        final double travelT = (raw / 0.68).clamp(0.0, 1.0).toDouble();
        final double curvedTravel = Curves.easeInOutCubic.transform(travelT);
        final Alignment projectileAlignment = Alignment.lerp(
          widget.fromAlignment,
          widget.toAlignment,
          curvedTravel,
        )!;
        final double fadeOut = raw < 0.78 ? 1 : (1 - raw) / 0.22;
        final double projectileScale = 0.74 + (sin(curvedTravel * pi) * 0.18);
        final double impactT = ((raw - 0.58) / 0.42).clamp(0.0, 1.0).toDouble();
        final double impactOpacity = impactT <= 0 ? 0 : (1 - impactT);
        final double impactScale = 0.55 + (impactT * 1.15);

        return Stack(
          children: <Widget>[
            Align(
              alignment: projectileAlignment,
              child: Opacity(
                opacity: fadeOut.clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: projectileScale,
                  child: RotationTransition(
                    turns: AlwaysStoppedAnimation<double>(
                      widget.rotationTurns +
                          (widget.toAlignment.y > widget.fromAlignment.y
                              ? 0.5
                              : 0),
                    ),
                    child: Image.asset(
                      widget.asset,
                      width: 178,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            if (impactOpacity > 0)
              Align(
                alignment: widget.toAlignment,
                child: Transform.scale(
                  scale: impactScale,
                  child: Opacity(
                    opacity: impactOpacity.clamp(0.0, 1.0).toDouble(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Container(
                          width: 126,
                          height: 126,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.color.withAlpha(130),
                              width: 2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: widget.color.withAlpha(120),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          _impactExplosionAsset,
                          width: 96,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HealPulse extends StatefulWidget {
  const _HealPulse({super.key, required this.alignment});

  final Alignment alignment;

  @override
  State<_HealPulse> createState() => _HealPulseState();
}

class _HealPulseState extends State<_HealPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
        final double value = Curves.easeOutCubic.transform(_controller.value);
        final double opacity = (1 - value).clamp(0.0, 1.0).toDouble();
        return Align(
          alignment: widget.alignment,
          child: Transform.scale(
            scale: 0.62 + value * 1.18,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E).withAlpha(44),
                  border: Border.all(color: const Color(0xFF4ADE80), width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF22C55E).withAlpha(110),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF4ADE80),
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
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
                        filterQuality: FilterQuality.high,
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
