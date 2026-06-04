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

part 'pvp_page/question_battle_sheet.dart';
part 'pvp_page/arena_entry_section.dart';
part 'pvp_page/arena_menu_section.dart';
part 'pvp_page/in_battle_section.dart';
part 'pvp_page/result_status_section.dart';

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

const double _arenaVerticalLiftFraction = 0.05;
const double _arenaAlignmentLift = _arenaVerticalLiftFraction * 2;

const Alignment _enemyMainAlignment = Alignment(
  0,
  -0.59 - _arenaAlignmentLift,
);
const Alignment _enemyMiniLeftAlignment = Alignment(
  -0.74,
  -0.418 - _arenaAlignmentLift,
);
const Alignment _enemyMiniRightAlignment = Alignment(
  0.74,
  -0.418 - _arenaAlignmentLift,
);
const Alignment _playerMainAlignment = Alignment(
  0,
  0.392 - _arenaAlignmentLift,
);
const Alignment _playerMiniLeftAlignment = Alignment(
  -0.74,
  0.222 - _arenaAlignmentLift,
);
const Alignment _playerMiniRightAlignment = Alignment(
  0.74,
  0.222 - _arenaAlignmentLift,
);

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
      // In-battle and arena menu use their own backgrounds
      final bool needsDark = state.phase == BattlePhase.inBattle;
      return Scaffold(
        backgroundColor: needsDark
            ? const Color(0xFF04060F)
            : const Color(0xFFF6F8FC),
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
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: Text(
          'Battle Arena',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFFF6F8FC),
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
      onPause: () => _showPauseDialog(context: context, controller: controller),
      onBotAnswer: controller.answerBotQuestion,
      onPickQuestion: (BattleQuestion question) async {
        final bool ready = await controller.prepareQuestion(question);
        if (!ready || !context.mounted) {
          return;
        }
        await _showQuestionSheet(
          context: context,
          controller: controller,
          question: question,
        );
      },
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
          onAnswered: (int selectedOptionIndex) async {
            await controller.answerQuestion(
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
}
