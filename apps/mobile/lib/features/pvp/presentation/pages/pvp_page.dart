import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  }) {
    if (state.isLoading) {
      return _ArenaLoadingView(
        mode: state.mode,
        message: state.statusMessage,
        playerAvatarAsset: selectedCharacter.characterVisuals!.idle,
        opponentAvatarAsset: opponentCharacter.characterVisuals!.idle,
        onCancel: state.mode == BattleMode.online
            ? controller.cancelMatchmaking
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
      );
    }

    if (state.phase == BattlePhase.finished) {
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
        onClaimReward: claimReward,
        onPractice: (String category) {
          _triggerResultExitAd(state);
          claimReward();
          controller.resetBattle();
          context.go(AppRoutes.practice, extra: category);
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
  });

  final BattleMode mode;
  final String playerAvatarAsset;
  final String opponentAvatarAsset;
  final String? message;
  final Future<void> Function()? onCancel;

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
                    'Batalkan pencarian',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
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
