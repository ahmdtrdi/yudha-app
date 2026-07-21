import 'dart:async';
import 'dart:math';

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

part 'pvp_page/question_battle_sheet.dart';
part 'pvp_page/arena_entry_section.dart';
part 'pvp_page/arena_menu_section.dart';
part 'pvp_page/in_battle_section.dart';
part 'pvp_page/result_status_section.dart';

const String _enemyAvatarAsset = 'assets/game/arena_hero_coral.png';
const String _playerAvatarAsset = 'assets/game/arena_hero_blue.png';
const String _enemyMainTowerAsset = 'assets/game/arena_tower_coral.png';
const String _enemyMiniTowerAsset = 'assets/game/arena_turret_coral.png';
const String _playerMainTowerAsset = 'assets/game/arena_tower_blue.png';
const String _playerMiniTowerAsset = 'assets/game/arena_turret_blue.png';
const String _numerikCardAsset = 'assets/game/card_numerik.png';
const String _verbalCardAsset = 'assets/game/card_verbal.png';
const String _logikaCardAsset = 'assets/game/card_logika.png';
const String _twkCardAsset = 'assets/game/card_twk.png';

class PvpPage extends ConsumerWidget {
  const PvpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BattleState state = ref.watch(battleControllerProvider);
    final BattleController controller = ref.read(
      battleControllerProvider.notifier,
    );
    final String playerDisplayName = ref.watch(
      playerProgressProvider.select((progress) => progress.displayName),
    );

    if (state.phase != BattlePhase.preBattle) {
      final bool needsDark = state.phase == BattlePhase.inBattle;
      final Widget content = _buildBattleContent(
        context: context,
        ref: ref,
        state: state,
        controller: controller,
        playerDisplayName: playerDisplayName,
      );
      return Scaffold(
        backgroundColor: needsDark
            ? const Color(0xFF0D2A52)
            : const Color(0xFFFFF8EC),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: content),
              if (!state.isLoading &&
                  state.phase == BattlePhase.arenaMenu &&
                  state.errorMessage != null)
                Positioned(
                  top: 10,
                  left: 16,
                  right: 16,
                  child: _StatusBanner(
                    text: state.errorMessage!,
                    isError: true,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EC),
      appBar: AppBar(
        title: Text(
          'Arena Yudha',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: const Color(0xFFFFF8EC),
        foregroundColor: AppColors.textStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
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
      return _ArenaLoadingView(mode: state.mode, message: state.statusMessage);
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
          await controller.startBattle();
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
      onPause: () => _showPauseDialog(
        context: context,
        controller: controller,
        mode: state.mode,
      ),
      onBotAnswer: controller.answerBotQuestion,
      onPickQuestion: (BattleQuestion question) async {
        final bool ready = await controller.prepareQuestion(question);
        if (!ready || !context.mounted) {
          return;
        }
        try {
          await _showQuestionSheet(
            context: context,
            controller: controller,
            question: question,
            mode: state.mode,
          );
        } finally {
          controller.releasePreparedQuestion(question.id);
        }
      },
    );
  }

  Future<void> _showQuestionSheet({
    required BuildContext context,
    required BattleController controller,
    required BattleQuestion question,
    required BattleMode mode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: mode != BattleMode.online,
      enableDrag: mode != BattleMode.online,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final BattlePhase phase = ref.watch(
              battleControllerProvider.select(
                (BattleState current) => current.phase,
              ),
            );
            if (phase != BattlePhase.inBattle) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ModalRoute<void>? route = ModalRoute.of(sheetContext);
                if (route != null && route.isActive) {
                  Navigator.of(sheetContext).removeRoute(route);
                }
              });
            }
            return child!;
          },
          child: _QuestionBattleSheet(
            question: question,
            isOnline: mode == BattleMode.online,
            onAnswered: (int selectedOptionIndex) {
              return controller.answerQuestion(
                questionId: question.id,
                selectedOptionIndex: selectedOptionIndex,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showPauseDialog({
    required BuildContext context,
    required BattleController controller,
    required BattleMode mode,
  }) async {
    final bool online = mode == BattleMode.online;
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDCD5C7)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF17233F).withAlpha(55),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2878F0).withAlpha(20),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    color: Color(0xFF2878F0),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  online ? 'Opsi battle' : 'Battle dijeda',
                  style: GoogleFonts.fredoka(
                    color: const Color(0xFF17233F),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  online
                      ? 'Lawan online tetap dapat bergerak selama menu ini terbuka.'
                      : 'Timer bot berhenti sampai kamu melanjutkan.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF66708A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop('resume'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2878F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    label: Text(
                      'Lanjutkan',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('menu'),
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF05E5E),
                      side: const BorderSide(color: Color(0xFFF2B8B5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    label: Text(
                      online ? 'Menyerah & keluar' : 'Akhiri battle',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
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
      try {
        await controller.surrenderBattle();
      } finally {
        controller.resetBattle();
      }
    }
  }
}

class _ArenaLoadingView extends StatelessWidget {
  const _ArenaLoadingView({required this.mode, this.message});

  final BattleMode mode;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final bool online = mode == BattleMode.online;
    return ColoredBox(
      color: const Color(0xFFFFF8EC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 210,
                height: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned(
                      left: 4,
                      bottom: 0,
                      child: Image.asset(
                        _playerAvatarAsset,
                        width: 106,
                        height: 106,
                        fit: BoxFit.contain,
                        cacheWidth: 280,
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 0,
                      child: Image.asset(
                        _enemyAvatarAsset,
                        width: 106,
                        height: 106,
                        fit: BoxFit.contain,
                        cacheWidth: 280,
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC857),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF17233F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                online ? 'Mencari lawan...' : 'Menyiapkan arena...',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: const Color(0xFF17233F),
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message ??
                    (online
                        ? 'Matchmaking akan dimulai begitu lawan tersedia.'
                        : 'Empat kartu pertamamu sedang dibagikan.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF66708A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF2878F0),
                  backgroundColor: Color(0xFFDDE8FA),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
