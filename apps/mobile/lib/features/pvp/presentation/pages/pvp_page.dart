import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/ads/application/ad_placement_providers.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/arena_visual_theme.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/notifications/presentation/notification_permission_prompt.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
import 'package:yudha_mobile/features/pvp/application/battle_controller.dart';
import 'package:yudha_mobile/features/pvp/application/battle_providers.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_enums.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_question.dart';
import 'package:yudha_mobile/features/pvp/domain/entities/battle_state.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_performance_analyzer.dart';
import 'package:yudha_mobile/features/pvp/domain/services/battle_state_machine.dart';
import 'package:yudha_mobile/features/pvp/presentation/audio/arena_audio_controller.dart';
import 'package:yudha_mobile/features/pvp/presentation/pages/pvp_page/battle_effect_resolver.dart';

part 'pvp_page/question_battle_sheet.dart';
part 'pvp_page/arena_entry_section.dart';
part 'pvp_page/arena_menu_section.dart';
part 'pvp_page/in_battle_section.dart';
part 'pvp_page/result_status_section.dart';

const String _enemyMiniTowerAsset = 'assets/game/arena_turret_coral.webp';
const String _numerikCardAsset = 'assets/game/card_numerik.webp';
const String _verbalCardAsset = 'assets/game/card_verbal.webp';
const String _logikaCardAsset = 'assets/game/card_logika.webp';
const String _twkCardAsset = 'assets/game/card_twk.webp';

String _firstName(String value, {required String fallback}) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized.split(RegExp(r'\s+')).first;
}

bool isPublicPvpResultAdEligible({
  required BattleMode battleMode,
  required OnlineMatchmakingMode matchmakingMode,
}) {
  return battleMode == BattleMode.online &&
      (matchmakingMode == OnlineMatchmakingMode.casual ||
          matchmakingMode == OnlineMatchmakingMode.ranked);
}

/// Fires haptic feedback only when the user keeps haptics enabled in
/// profile settings. Prefers real amplitude-controlled vibration (much more
/// noticeable on devices where predefined HapticFeedback effects are too
/// subtle, e.g. Xiaomi/MIUI) and falls back to HapticFeedback elsewhere.
/// Every call is non-fatal so gameplay is never interrupted.
class GameHaptics {
  const GameHaptics(this.enabled);

  final bool enabled;

  static Future<bool?>? _hasVibratorFuture;

  void selection() => _pulse(
    const Duration(milliseconds: 12),
    48,
    HapticFeedback.selectionClick,
  );

  void light() =>
      _pulse(const Duration(milliseconds: 22), 80, HapticFeedback.lightImpact);

  void medium() => _pulse(
    const Duration(milliseconds: 45),
    168,
    HapticFeedback.mediumImpact,
  );

  void heavy() =>
      _pulse(const Duration(milliseconds: 70), 255, HapticFeedback.heavyImpact);

  void vibrate() =>
      _pulse(const Duration(milliseconds: 400), 255, HapticFeedback.vibrate);

  void _pulse(
    Duration duration,
    int amplitude,
    Future<void> Function() fallback,
  ) {
    if (!enabled) {
      return;
    }
    unawaited(() async {
      try {
        _hasVibratorFuture ??= Vibration.hasVibrator();
        if (await _hasVibratorFuture! == true) {
          await Vibration.vibrate(
            duration: duration.inMilliseconds,
            amplitude: amplitude,
          );
          return;
        }
      } catch (_) {
        // Plugin unavailable (web/desktop/tests) — fall through to haptics.
      }
      try {
        await fallback();
      } catch (_) {}
    }());
  }
}

class PvpPage extends ConsumerStatefulWidget {
  const PvpPage({super.key});

  @override
  ConsumerState<PvpPage> createState() => _PvpPageState();
}

class _PvpPageState extends ConsumerState<PvpPage> {
  _ArenaSetupStep _setupStep = _ArenaSetupStep.arena;
  String? _scheduledArenaSyncId;
  final ResultExitAdSession _resultAdSession = ResultExitAdSession();
  bool _allowResultPop = false;
  bool _resultEconomyRefreshed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(battleControllerProvider.notifier).reconnectIfActive(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final BattleState state = ref.watch(battleControllerProvider);
    if (state.phase != BattlePhase.finished) {
      _resultAdSession.reset();
      _allowResultPop = false;
      _resultEconomyRefreshed = false;
    } else if (state.mode == BattleMode.online &&
        state.progressionPersisted &&
        !_resultEconomyRefreshed) {
      _resultEconomyRefreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(ref.read(gameEconomyProvider.notifier).refresh());
        }
      });
    }
    final BattleController controller = ref.read(
      battleControllerProvider.notifier,
    );
    final String playerDisplayName = ref.watch(
      playerProgressProvider.select((progress) => progress.displayName),
    );
    final String playerFirstName = _firstName(
      playerDisplayName,
      fallback: 'Kamu',
    );
    final GameEconomyState economy = ref.watch(gameEconomyProvider);
    final bool soundEnabled = ref.watch(
      profileSettingsProvider.select((settings) => settings.soundEnabled),
    );
    final bool hapticsEnabled = ref.watch(
      profileSettingsProvider.select((settings) => settings.hapticsEnabled),
    );
    final double musicLevel = ref.watch(
      profileSettingsProvider.select((settings) => settings.battleMusicVolume),
    );
    final ProfileTarget? localTarget = ref.watch(
      profileSettingsProvider.select((settings) => settings.target),
    );
    final ProfileTarget? remoteTarget = ref.watch(
      userProfileProvider.select((state) => state.profile?.target),
    );
    final ProfileTarget? profileTarget = remoteTarget ?? localTarget;
    final CosmeticItem selectedCharacter =
        GameEconomyCatalog.findCharacter(economy.equippedCharacterId) ??
        GameEconomyCatalog.characters.first;
    final CosmeticItem selectedTower =
        GameEconomyCatalog.findTower(economy.equippedTowerId) ??
        GameEconomyCatalog.towers.first;
    final CosmeticItem opponentCharacter = GameEconomyCatalog.characters
        .firstWhere(
          (CosmeticItem item) => item.id != selectedCharacter.id,
          orElse: () => GameEconomyCatalog.characters.first,
        );
    final CosmeticItem savedArena =
        GameEconomyCatalog.findArena(economy.equippedArenaId) ??
        GameEconomyCatalog.arenas.first;
    final CosmeticItem selectedArena =
        GameEconomyCatalog.findArena(profileTarget?.arenaId ?? '') ??
        savedArena;
    _ensureArenaMatchesTarget(profileTarget, economy);
    final bool useServerSnapshot =
        state.mode == BattleMode.online &&
        (state.isMatchActive || state.isBattleFinished);
    final CosmeticItem battlePlayerCharacter = useServerSnapshot
        ? GameEconomyCatalog.findCharacter(
                state.playerCharacterId ?? selectedCharacter.id,
              ) ??
              selectedCharacter
        : selectedCharacter;
    final CosmeticItem battlePlayerTower = useServerSnapshot
        ? GameEconomyCatalog.findTower(
                state.playerTowerId ?? selectedTower.id,
              ) ??
              selectedTower
        : selectedTower;
    final CosmeticItem battleOpponentCharacter = useServerSnapshot
        ? GameEconomyCatalog.findCharacter(
                state.opponentCharacterId ?? opponentCharacter.id,
              ) ??
              opponentCharacter
        : opponentCharacter;
    final CosmeticItem battleOpponentTower =
        GameEconomyCatalog.findTower(
          useServerSnapshot
              ? state.opponentTowerId ?? 'tower-benteng-bara'
              : 'tower-benteng-bara',
        ) ??
        GameEconomyCatalog.towers.last;
    final CosmeticItem battleArena =
        useServerSnapshot && state.battleTarget != null
        ? GameEconomyCatalog.findArena('arena-${state.battleTarget!.name}') ??
              selectedArena
        : selectedArena;

    if (state.phase != BattlePhase.preBattle) {
      final bool needsDark =
          state.phase == BattlePhase.inBattle ||
          state.phase == BattlePhase.roundBreak;
      final Widget content = _buildBattleContent(
        context: context,
        ref: ref,
        state: state,
        controller: controller,
        playerDisplayName: playerFirstName,
        economy: economy,
        selectedCharacter: battlePlayerCharacter,
        selectedTower: battlePlayerTower,
        opponentCharacter: battleOpponentCharacter,
        opponentTower: battleOpponentTower,
        selectedArena: battleArena,
        profileTarget: profileTarget,
        soundEnabled: soundEnabled,
        hapticsEnabled: hapticsEnabled,
        musicLevel: musicLevel,
      );
      final Widget page = _SystemBarStyle(
        darkBackground: needsDark,
        child: Scaffold(
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
        ),
      );
      if (state.phase != BattlePhase.finished) return page;
      return PopScope(
        canPop: _allowResultPop,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          _triggerResultExitAd(state);
          setState(() => _allowResultPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        },
        child: page,
      );
    }

    return _SystemBarStyle(
      darkBackground: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8EC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: <Widget>[
                if (state.statusMessage != null)
                  _StatusBanner(text: state.statusMessage!),
                if (state.errorMessage != null)
                  _StatusBanner(text: state.errorMessage!, isError: true),
                if (state.statusMessage != null || state.errorMessage != null)
                  const SizedBox(height: 6),
                Expanded(
                  child: _buildBattleContent(
                    context: context,
                    ref: ref,
                    state: state,
                    controller: controller,
                    playerDisplayName: playerFirstName,
                    economy: economy,
                    selectedCharacter: battlePlayerCharacter,
                    selectedTower: battlePlayerTower,
                    opponentCharacter: battleOpponentCharacter,
                    opponentTower: battleOpponentTower,
                    selectedArena: battleArena,
                    profileTarget: profileTarget,
                    soundEnabled: soundEnabled,
                    hapticsEnabled: hapticsEnabled,
                    musicLevel: musicLevel,
                  ),
                ),
              ],
            ),
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
    required GameEconomyState economy,
    required CosmeticItem selectedCharacter,
    required CosmeticItem selectedTower,
    required CosmeticItem opponentCharacter,
    required CosmeticItem opponentTower,
    required CosmeticItem selectedArena,
    required ProfileTarget? profileTarget,
    required bool soundEnabled,
    required bool hapticsEnabled,
    required double musicLevel,
  }) {
    if (state.isLoading) {
      return _ArenaLoadingView(
        mode: state.mode,
        message: state.statusMessage,
        roomCode: state.privateRoomCode,
        playerAvatarAsset: selectedCharacter.characterVisuals!.idle,
        opponentAvatarAsset: opponentCharacter.characterVisuals!.idle,
        onCancel: state.mode == BattleMode.online
            ? (state.privateRoomCode != null
                  ? controller.cancelPrivateRoom
                  : controller.cancelMatchmaking)
            : null,
      );
    }

    if (state.phase == BattlePhase.preBattle) {
      return _ArenaEntrySection(
        step: _setupStep,
        playerDisplayName: playerDisplayName,
        economy: economy,
        selectedCharacter: selectedCharacter,
        selectedTower: selectedTower,
        selectedArena: selectedArena,
        profileTarget: profileTarget,
        onSelectCosmetic: (CosmeticItem item) {
          unawaited(
            ref.read(gameEconomyProvider.notifier).equipAuthoritative(item),
          );
        },
        onSelectArena: (CosmeticItem arena) {
          final GameEconomyController economyController = ref.read(
            gameEconomyProvider.notifier,
          );
          unawaited(economyController.selectArenaAuthoritative(arena));
        },
        onLockedArenaTap: (CosmeticItem arena) {
          final String targetLabel = profileTarget?.label ?? '';
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Arena ini terkunci untuk tujuan $targetLabel. '
                  'Pindah tujuan Anda di Pengaturan jika ingin bermain '
                  'di ${arena.name}.',
                ),
              ),
            );
        },
        onOpenStore: () => context.push(AppRoutes.store),
        onTopUp: () => showYCoinTopUpSheet(context),
        onBack: () {
          setState(() => _setupStep = _ArenaSetupStep.arena);
        },
        onContinue: () {
          if (_setupStep == _ArenaSetupStep.arena) {
            setState(() => _setupStep = _ArenaSetupStep.loadout);
            return;
          }
          controller.enterArena();
        },
      );
    }

    if (state.phase == BattlePhase.arenaMenu) {
      return _ArenaMenuSection(
        playerDisplayName: playerDisplayName,
        playerAvatarAsset: selectedCharacter.characterVisuals!.idle,
        selectedArena: selectedArena,
        selectedTower: selectedTower,
        balance: economy.isAuthoritative ? economy.yCoins : null,
        onBackLoadout: () {
          controller.exitArena();
          setState(() => _setupStep = _ArenaSetupStep.loadout);
        },
        onTopUp: () => showYCoinTopUpSheet(context),
        onOpenStore: () => context.push(AppRoutes.store),
        onStartBot: () async {
          await _startOnlineBattle(
            context: context,
            ref: ref,
            controller: controller,
            matchmakingMode: OnlineMatchmakingMode.bot,
          );
        },
        onStartCasual: () async {
          await _startOnlineBattle(
            context: context,
            ref: ref,
            controller: controller,
            matchmakingMode: OnlineMatchmakingMode.casual,
          );
        },
        onStartRanked: () async {
          await _startOnlineBattle(
            context: context,
            ref: ref,
            controller: controller,
            matchmakingMode: OnlineMatchmakingMode.ranked,
          );
        },
        onStartPrivateRoom: () async {
          await _showPrivateRoomDialog(
            context: context,
            controller: controller,
          );
        },
      );
    }

    if (state.phase == BattlePhase.finished) {
      if (state.finishReason == 'surrender') {
        return _SurrenderResultSection(
          state: state,
          playerDisplayName: playerDisplayName,
          onReplay: () => unawaited(controller.startBattle()),
          onReset: controller.resetBattle,
        );
      }

      void claimReward() {
        if (state.rewardClaimed) {
          return;
        }
        if (state.mode == BattleMode.online) {
          unawaited(() async {
            await ref
                .read(playerProgressProvider.notifier)
                .hydrateFromRepository();
            final bool qualifies =
                state.progressionPersisted &&
                (state.onlineMatchmakingMode == OnlineMatchmakingMode.casual ||
                    state.onlineMatchmakingMode ==
                        OnlineMatchmakingMode.ranked);
            if (qualifies && context.mounted) {
              await maybeShowNotificationPermissionPrompt(context, ref);
            }
          }());
        }
        controller.markRewardClaimed();
      }

      return _ResultSection(
        state: state,
        soundEnabled: soundEnabled,
        hapticsEnabled: hapticsEnabled,
        onClaimReward: claimReward,
        onPractice: (String category) {
          _triggerResultExitAd(state);
          claimReward();
          controller.resetBattle();
          context.go(AppRoutes.solo, extra: category);
        },
        onReplay: () {
          _triggerResultExitAd(state);
          unawaited(controller.startBattle());
        },
        onReset: () {
          _triggerResultExitAd(state);
          controller.resetBattle();
        },
        playerDisplayName: playerDisplayName,
      );
    }

    return _InBattleSection(
      state: state,
      playerDisplayName: playerDisplayName,
      playerCharacter: selectedCharacter.characterVisuals!,
      opponentCharacter: opponentCharacter.characterVisuals!,
      playerTowerAsset: selectedTower.battleAssetPath ?? _enemyMiniTowerAsset,
      opponentTowerAsset: opponentTower.battleAssetPath ?? _enemyMiniTowerAsset,
      arenaTheme: ArenaVisualTheme.fromId(selectedArena.id),
      soundEnabled: soundEnabled,
      hapticsEnabled: hapticsEnabled,
      musicLevel: musicLevel,
      onPause: () async {
        controller.pauseRoundClock();
        try {
          await _showPauseDialog(
            context: context,
            controller: controller,
            mode: state.mode,
          );
        } finally {
          controller.resumeRoundClock();
        }
      },
      onRoundReady: controller.beginRound,
      onArenaDisposed: controller.stopRoundClock,
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
            soundEnabled: soundEnabled,
            hapticsEnabled: hapticsEnabled,
          );
        } finally {
          controller.releasePreparedQuestion(question.id);
        }
      },
    );
  }

  void _triggerResultExitAd(BattleState state) {
    final bool isPublicResult = isPublicPvpResultAdEligible(
      battleMode: state.mode,
      matchmakingMode: state.onlineMatchmakingMode,
    );
    if (!isPublicResult) return;
    _resultAdSession.triggerOnce(
      ref.read(adPlacementGateProvider),
      AdPlacement.publicPvpResultExit,
    );
  }

  void _ensureArenaMatchesTarget(
    ProfileTarget? target,
    GameEconomyState economy,
  ) {
    final String? targetArenaId = target?.arenaId;
    if (targetArenaId == null ||
        economy.equippedArenaId == targetArenaId ||
        _scheduledArenaSyncId == targetArenaId) {
      return;
    }

    final CosmeticItem? arena = GameEconomyCatalog.findArena(targetArenaId);
    if (arena == null) {
      return;
    }
    _scheduledArenaSyncId = targetArenaId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ProfileTarget? latestTarget = ref
          .read(profileSettingsProvider)
          .target;
      if (latestTarget?.arenaId != targetArenaId) {
        _scheduledArenaSyncId = null;
        return;
      }

      final GameEconomyController controller = ref.read(
        gameEconomyProvider.notifier,
      );
      unawaited(
        controller.selectArenaAuthoritative(arena).whenComplete(() {
          if (_scheduledArenaSyncId == targetArenaId) {
            _scheduledArenaSyncId = null;
          }
        }),
      );
    });
  }

  Future<void> _showQuestionSheet({
    required BuildContext context,
    required BattleController controller,
    required BattleQuestion question,
    required BattleMode mode,
    required bool soundEnabled,
    required bool hapticsEnabled,
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
            final ({BattlePhase phase, bool cardAvailable, int comboLevel})
            modalState = ref.watch(
              battleControllerProvider.select(
                (BattleState current) => (
                  phase: current.phase,
                  cardAvailable: current.availableQuestions.any(
                    (item) => item.id == question.id,
                  ),
                  comboLevel: current.comboLevel,
                ),
              ),
            );
            if (modalState.phase != BattlePhase.inBattle ||
                !modalState.cardAvailable) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final ModalRoute<void>? route = ModalRoute.of(sheetContext);
                if (route != null && route.isActive) {
                  Navigator.of(sheetContext).removeRoute(route);
                }
              });
            }
            return _QuestionBattleSheet(
              question: question,
              isOnline: mode == BattleMode.online,
              comboLevel: modalState.comboLevel,
              soundEnabled: soundEnabled,
              hapticsEnabled: hapticsEnabled,
              onAnswered: (int selectedOptionIndex) {
                return controller.answerQuestion(
                  questionId: question.id,
                  selectedOptionIndex: selectedOptionIndex,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _startOnlineBattle({
    required BuildContext context,
    required WidgetRef ref,
    required BattleController controller,
    required OnlineMatchmakingMode matchmakingMode,
  }) async {
    try {
      await ref.read(gameEconomyProvider.notifier).syncAuthoritativeLoadout();
    } catch (_) {
      // Ignored: Non-fatal loadout sync failure should not block entering battle.
    }
    controller.setMode(BattleMode.online);
    controller.setOnlineMatchmakingMode(matchmakingMode);
    await controller.startBattle();
  }

  Future<void> _showPrivateRoomDialog({
    required BuildContext context,
    required BattleController controller,
  }) async {
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const _PrivateRoomActionDialog();
      },
    );
    if (action == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(gameEconomyProvider.notifier).syncAuthoritativeLoadout();
    } catch (_) {
      // Ignored: Non-fatal loadout sync failure should not block room setup.
    }
    controller.setMode(BattleMode.online);
    controller.setOnlineMatchmakingMode(OnlineMatchmakingMode.privateRoom);

    if (action == 'create') {
      await controller.createPrivateRoom();
      return;
    }

    if (!context.mounted) {
      return;
    }
    final String? code = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return const _PrivateRoomCodeDialog();
      },
    );
    if (code == null || !context.mounted) {
      return;
    }
    await controller.joinPrivateRoom(code);
  }

  Future<void> _showPauseDialog({
    required BuildContext context,
    required BattleController controller,
    required BattleMode mode,
  }) async {
    final bool online = mode == BattleMode.online;
    double musicVolume = ref.read(profileSettingsProvider).battleMusicVolume;
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            key: const ValueKey<String>('battle-pause-dialog'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFB9D5FF)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xFF0D2A52),
                  blurRadius: 0,
                  offset: Offset(0, 8),
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
                    color: const Color(0xFFDDEBFF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF8DBAFF)),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0xFF2878F0),
                        blurRadius: 0,
                        offset: Offset(0, 4),
                      ),
                    ],
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
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD9DEE7)),
                  ),
                  child: StatefulBuilder(
                    builder:
                        (
                          BuildContext context,
                          void Function(void Function()) setDialogState,
                        ) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.music_note_rounded,
                                    color: Color(0xFF66708A),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Volume musik arena',
                                      style: GoogleFonts.dmSans(
                                        color: const Color(0xFF17233F),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(musicVolume * 100).round()}%',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: const Color(0xFF66708A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 9,
                                  ),
                                ),
                                child: Slider(
                                  value: musicVolume.clamp(0.0, 1.0),
                                  max: 1,
                                  divisions: 20,
                                  activeColor: const Color(0xFF2878F0),
                                  inactiveColor: const Color(0xFFDDE8FA),
                                  label: '${(musicVolume * 100).round()}%',
                                  onChanged: (double value) {
                                    setDialogState(() => musicVolume = value);
                                    ref
                                        .read(profileSettingsProvider.notifier)
                                        .setBattleMusicVolume(value);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                  ),
                ),
                const SizedBox(height: 16),
                _ResultClayAction(
                  key: const ValueKey<String>('battle-pause-resume'),
                  onPressed: () => Navigator.of(context).pop('resume'),
                  icon: Icons.play_arrow_rounded,
                  label: 'Lanjutkan',
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

    if (action == 'menu' && context.mounted) {
      final bool confirmed =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return const _SurrenderConfirmationDialog();
            },
          ) ??
          false;
      if (!confirmed) {
        return;
      }
      await controller.surrenderBattle();
    }
  }
}

class _SurrenderConfirmationDialog extends StatelessWidget {
  const _SurrenderConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        key: const ValueKey<String>('battle-surrender-confirmation'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFFB8B8)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xFFB83F45),
              blurRadius: 0,
              offset: Offset(0, 8),
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
                color: const Color(0xFFFFE4E4),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFB8B8)),
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: Color(0xFFB83F45),
                size: 29,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Yakin ingin menyerah?',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: const Color(0xFF17233F),
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Battle akan langsung berakhir dan kamu kembali ke pilihan mode.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF66708A),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF17233F),
                        side: const BorderSide(color: Color(0xFFD9DEE7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.flag_rounded, size: 18),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF05E5E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      label: Text(
                        'Menyerah',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemBarStyle extends StatelessWidget {
  const _SystemBarStyle({required this.darkBackground, required this.child});

  final bool darkBackground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SystemUiOverlayStyle base = darkBackground
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: base.copyWith(
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}

class _ArenaLoadingView extends StatelessWidget {
  const _ArenaLoadingView({
    required this.mode,
    required this.playerAvatarAsset,
    required this.opponentAvatarAsset,
    this.onCancel,
    this.message,
    this.roomCode,
  });

  final BattleMode mode;
  final String playerAvatarAsset;
  final String opponentAvatarAsset;
  final String? message;
  final String? roomCode;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final bool online = mode == BattleMode.online;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFEAF2FF), Color(0xFFFFF8EC)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            key: const ValueKey<String>('battle-waiting-panel'),
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFB9D5FF)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0xFF2878F0),
                  blurRadius: 0,
                  offset: Offset(0, 8),
                ),
              ],
            ),
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
                          playerAvatarAsset,
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
                          opponentAvatarAsset,
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
                if (roomCode != null && roomCode!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Semantics(
                    label: 'Kode room privat',
                    value: roomCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17233F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2FAE7D)),
                      ),
                      child: Text(
                        roomCode!,
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF7ED0AC),
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                  ),
                ],
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
                if (onCancel != null) ...<Widget>[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const ValueKey<String>('cancel-matchmaking'),
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(
                      roomCode != null && roomCode!.isNotEmpty
                          ? 'Tutup room'
                          : 'Batalkan pencarian',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivateRoomActionDialog extends StatelessWidget {
  const _PrivateRoomActionDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
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
                color: const Color(0xFF2FAE7D).withAlpha(24),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.meeting_room_rounded,
                color: Color(0xFF2FAE7D),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Room Privat',
              style: GoogleFonts.fredoka(
                color: const Color(0xFF17233F),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Main eksklusif bareng temanmu. Room otomatis batal '
              'kalau battle tidak dimulai dalam 15 menit.',
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
                key: const ValueKey<String>('private-room-create'),
                onPressed: () => Navigator.of(context).pop('create'),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2FAE7D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: Text(
                  'Buat Room Baru',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                key: const ValueKey<String>('private-room-join'),
                onPressed: () => Navigator.of(context).pop('join'),
                icon: const Icon(Icons.login_rounded, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2878F0),
                  side: const BorderSide(color: Color(0xFF9FC1F5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: Text(
                  'Gabung dengan Kode',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateRoomCodeDialog extends StatefulWidget {
  const _PrivateRoomCodeDialog();

  @override
  State<_PrivateRoomCodeDialog> createState() => _PrivateRoomCodeDialogState();
}

class _PrivateRoomCodeDialogState extends State<_PrivateRoomCodeDialog> {
  late final TextEditingController _codeController = TextEditingController();
  bool _hasError = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final String code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _hasError = true);
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Gabung Room Privat',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                color: const Color(0xFF17233F),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Masukkan 6 karakter kode dari pembuat room.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF66708A),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _codeController,
              autofocus: true,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              onChanged: (_) {
                if (_hasError) {
                  setState(() => _hasError = false);
                }
              },
              onSubmitted: (_) => _submit(),
              textAlign: TextAlign.center,
              cursorColor: const Color(0xFF2878F0),
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF17233F),
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                errorText: _hasError ? 'Kode harus 6 karakter.' : null,
                filled: true,
                fillColor: Colors.white,
                hintText: 'ABC123',
                hintStyle: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFFB4BAC6),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _hasError
                        ? const Color(0xFFF05E5E)
                        : const Color(0xFFD5DAE3),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF2878F0),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey<String>('private-room-submit'),
                onPressed: _submit,
                icon: const Icon(Icons.sports_esports_rounded, size: 20),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2878F0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: Text(
                  'Gabung Sekarang',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF66708A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Batal',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
