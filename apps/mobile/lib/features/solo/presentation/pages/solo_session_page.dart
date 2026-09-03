import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/battle/presentation/audio/arena_audio_controller.dart';
import 'package:yudha_mobile/features/battle/presentation/widgets/battle_arena_widgets.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_controller.dart';
import 'package:yudha_mobile/features/solo/application/solo_session_providers.dart';
import 'package:yudha_mobile/features/solo/domain/solo_contract.dart';
import 'package:yudha_mobile/features/solo/domain/solo_session.dart';

class SoloSessionPage extends ConsumerStatefulWidget {
  const SoloSessionPage({super.key});

  @override
  ConsumerState<SoloSessionPage> createState() => _SoloSessionPageState();
}

class _SoloSessionPageState extends ConsumerState<SoloSessionPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ambientController;
  late final ArenaAudioController _arenaAudio;
  final List<Timer> _effectTimers = <Timer>[];
  bool _audioStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final ProfileSettings settings = ref.read(profileSettingsProvider);
    _arenaAudio = ArenaAudioController(
      enabled: settings.soundEnabled,
      musicLevel: settings.battleMusicVolume,
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final Timer timer in _effectTimers) {
      timer.cancel();
    }
    _ambientController.dispose();
    unawaited(_arenaAudio.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final SoloSessionController sessionController = ref.read(
      soloSessionControllerProvider.notifier,
    );
    if (state == AppLifecycleState.resumed &&
        ref.read(soloSessionControllerProvider).session?.isActive == true) {
      sessionController.resumeActiveTiming();
      unawaited(_arenaAudio.resumeMusic());
      return;
    }
    sessionController.pauseActiveTiming();
    unawaited(_arenaAudio.pauseMusic());
  }

  void _startAudioIfNeeded() {
    if (_audioStarted) return;
    _audioStarted = true;
    unawaited(_arenaAudio.start());
  }

  void _handleSessionAudio(SoloSessionState? previous, SoloSessionState next) {
    if (previous?.openedQuestion?.sessionQuestionId !=
            next.openedQuestion?.sessionQuestionId &&
        next.openedQuestion != null) {
      _arenaAudio.playCardPick();
    }
    if (previous?.feedback == null && next.feedback != null) {
      if (next.feedback!.isCorrect) {
        _arenaAudio.playAnswerCorrect();
      } else {
        _arenaAudio.playAnswerWrong();
      }
    }
    if (previous?.reaction != next.reaction &&
        next.reaction == SoloReaction.attack) {
      _arenaAudio.playCast();
      _effectTimers.add(
        Timer(const Duration(milliseconds: 130), _arenaAudio.playProjectile),
      );
      _effectTimers.add(
        Timer(const Duration(milliseconds: 390), _arenaAudio.playImpact),
      );
    }
    final SoloSession? previousSession = previous?.session;
    final SoloSession? nextSession = next.session;
    if (previousSession?.isActive == true &&
        nextSession != null &&
        !nextSession.isActive) {
      ref.invalidate(learningControllerProvider);
      if (nextSession.towerHp == 0) {
        _arenaAudio.playVictoryStinger();
        _effectTimers.add(
          Timer(const Duration(milliseconds: 1400), _arenaAudio.pauseMusic),
        );
      } else {
        unawaited(_arenaAudio.pauseMusic());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileSettings>(profileSettingsProvider, (
      ProfileSettings? previous,
      ProfileSettings next,
    ) {
      if (previous?.soundEnabled != next.soundEnabled) {
        unawaited(_arenaAudio.setEnabled(next.soundEnabled));
      }
      if (previous?.battleMusicVolume != next.battleMusicVolume) {
        unawaited(_arenaAudio.setMusicLevel(next.battleMusicVolume));
      }
    });
    ref.listen<SoloSessionState>(
      soloSessionControllerProvider,
      _handleSessionAudio,
    );
    final state = ref.watch(soloSessionControllerProvider);
    final controller = ref.read(soloSessionControllerProvider.notifier);
    final session = state.session;
    if (state.loading) {
      return const Scaffold(
        backgroundColor: AppColors.scholarCream,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (session == null) {
      return _MissingSession(message: state.error);
    }
    if (!session.isActive &&
        !state.showFeedback &&
        state.reaction == SoloReaction.idle) {
      return _SoloResult(
        session: session,
        onExit: () {
          ref.invalidate(activeSoloSessionProvider);
          context.go(AppRoutes.solo);
        },
      );
    }
    _startAudioIfNeeded();

    final character = GameEconomyCatalog.characters.firstWhere(
      (item) => item.id == session.characterId,
      orElse: () => GameEconomyCatalog.characters.first,
    );
    String? activeQuestionId = state.openedQuestion?.sessionQuestionId;
    for (final card in session.hand) {
      if (card.openedAt != null) activeQuestionId ??= card.sessionQuestionId;
    }
    return Scaffold(
      backgroundColor: BattleClayPalette.cream,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: <Widget>[
                  _BattleStatus(
                    session: session,
                    submitting: state.submitting,
                    onStop: () => _confirmStop(controller),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _ArenaStage(
                      session: session,
                      character: character,
                      reaction: state.reaction,
                      ambientAnimation: _ambientController,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardTray(
                    hand: session.hand,
                    loading: state.submitting,
                    activeQuestionId: activeQuestionId,
                    compact: MediaQuery.sizeOf(context).height < 720,
                    mechanicMode: session.mechanicMode,
                    onOpen: controller.openCard,
                  ),
                  if (state.error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _ErrorBanner(state.error!),
                  ],
                ],
              ),
            ),
          ),
          if (state.questionVisible && state.openedQuestion != null)
            _QuestionOverlay(
              session: state.session ?? session,
              question: state.openedQuestion!,
              feedback: state.feedback,
              selectedOption: state.selectedOption,
              hintVisible: state.hintVisible,
              hintLoading: state.hintLoading,
              submitting: state.submitting,
              error: state.error,
              onSelect: controller.selectAndSubmit,
              onHint: controller.showHint,
              onTimeout: controller.timeout,
              onBack: controller.closeQuestion,
              onNext: controller.next,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmStop(SoloSessionController controller) async {
    await _arenaAudio.pauseMusic();
    if (!mounted) return;
    double musicVolume = ref.read(profileSettingsProvider).battleMusicVolume;
    final stop = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder:
            (
              BuildContext context,
              void Function(void Function()) setDialogState,
            ) => AlertDialog(
              key: const ValueKey<String>('solo-pause-dialog'),
              title: const Text('Latihan dijeda'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Atur volume musik atau lanjutkan sesi saat kamu siap.',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.music_note_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Volume musik arena',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('${(musicVolume * 100).round()}%'),
                    ],
                  ),
                  Slider(
                    key: const ValueKey<String>('solo-music-volume-slider'),
                    value: musicVolume.clamp(0.0, 1.0),
                    max: 1,
                    divisions: 20,
                    label: '${(musicVolume * 100).round()}%',
                    onChanged: (double value) {
                      setDialogState(() => musicVolume = value);
                      ref
                          .read(profileSettingsProvider.notifier)
                          .setBattleMusicVolume(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Jika latihan diakhiri, jawaban tetap tercatat tetapi sesi tidak memberikan hadiah.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  key: const ValueKey<String>('solo-pause-end'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Akhiri'),
                ),
                FilledButton.icon(
                  key: const ValueKey<String>('solo-pause-resume'),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Lanjut latihan'),
                ),
              ],
            ),
      ),
    );
    if (stop == true) {
      await controller.stop();
    } else {
      await _arenaAudio.resumeMusic();
    }
  }
}

class _ArenaStage extends StatelessWidget {
  const _ArenaStage({
    required this.session,
    required this.character,
    required this.reaction,
    required this.ambientAnimation,
  });

  final SoloSession session;
  final CosmeticItem character;
  final SoloReaction reaction;
  final Animation<double> ambientAnimation;

  @override
  Widget build(BuildContext context) {
    final tower = GameEconomyCatalog.towers.first;
    final visuals = character.characterVisuals!;
    final BattleCharacterPose pose = switch (reaction) {
      SoloReaction.attack => BattleCharacterPose.attack,
      SoloReaction.hit => BattleCharacterPose.hit,
      SoloReaction.idle => BattleCharacterPose.ready,
    };
    final CosmeticItem arena = GameEconomyCatalog.findArena(
      'arena-rimba-yudha',
    )!;
    return BattleArenaFrame(
      arenaKey: const ValueKey<String>('solo-battle-arena'),
      backgroundKey: const ValueKey<String>('solo-arena-background'),
      arenaAsset: arena.assetPath!,
      foregroundBuilder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double championSize = (width * 0.38).clamp(118, 154);
        final double towerSize = (width * 0.48).clamp(150, 205);
        return Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x22002467),
                      Color(0x0014213A),
                      Color(0x4414213A),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              key: const ValueKey<String>('solo-opponent-tower'),
              top: height * 0.03,
              left: (width - towerSize) / 2,
              width: towerSize,
              height: towerSize,
              child: BattleTowerAsset(
                activeAsset: tower.battleAssetPath!,
                destroyedAsset: tower.destroyedAssetPath!,
                destroyed: session.towerHp <= 0,
                ambientAnimation: ambientAnimation,
              ),
            ),
            Positioned(
              bottom: -4,
              left: (width - championSize) / 2,
              width: championSize,
              height: championSize,
              child: BattleChampionStand(
                semanticKey: const ValueKey<String>('solo-player-character'),
                character: visuals,
                pose: pose,
                accent: BattleClayPalette.player,
                destroyed: false,
                ambientAnimation: ambientAnimation,
              ),
            ),
            if (reaction == SoloReaction.attack)
              Positioned.fill(
                child: _SoloAttackEffect(
                  key: ValueKey<int>(session.answeredCount),
                ),
              ),
            if (reaction == SoloReaction.hit)
              const Positioned.fill(child: _SoloHitFlash()),
          ],
        );
      },
    );
  }
}

class _SoloAttackEffect extends StatelessWidget {
  const _SoloAttackEffect({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 720),
          curve: Curves.easeInOutCubic,
          builder: (BuildContext context, double progress, Widget? child) {
            final Offset start = Offset(
              constraints.maxWidth * 0.5,
              constraints.maxHeight * 0.72,
            );
            final Offset end = Offset(
              constraints.maxWidth * 0.5,
              constraints.maxHeight * 0.26,
            );
            final Offset position = Offset.lerp(start, end, progress)!;
            return Stack(
              children: <Widget>[
                Positioned(
                  left: position.dx - 14,
                  top: position.dy - 14,
                  child: Opacity(
                    opacity: progress < 0.86 ? 1 : (1 - progress) / 0.14,
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      key: ValueKey<String>('solo-attack-projectile'),
                      color: Color(0xFFFFD36A),
                      size: 28,
                      shadows: <Shadow>[
                        Shadow(color: Color(0xFFFF8A38), blurRadius: 12),
                      ],
                    ),
                  ),
                ),
                if (progress > 0.76)
                  Positioned(
                    left: end.dx - 30,
                    top: end.dy - 30,
                    child: Opacity(
                      opacity: ((1 - progress) / 0.24).clamp(0, 1),
                      child: const Icon(
                        Icons.brightness_7_rounded,
                        key: ValueKey<String>('solo-tower-impact'),
                        color: Color(0xFFFFD36A),
                        size: 60,
                      ),
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

class _SoloHitFlash extends StatelessWidget {
  const _SoloHitFlash();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.22, end: 0),
      duration: const Duration(milliseconds: 420),
      builder: (BuildContext context, double opacity, Widget? child) {
        return ColoredBox(
          key: const ValueKey<String>('solo-player-hit-flash'),
          color: const Color(0xFFEF5B62).withValues(alpha: opacity),
        );
      },
    );
  }
}

class _BattleStatus extends StatelessWidget {
  const _BattleStatus({
    required this.session,
    required this.submitting,
    required this.onStop,
  });
  final SoloSession session;
  final bool submitting;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('solo-battle-hud'),
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.scholarCream,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0xFFC8D0DC), offset: Offset(0, 5)),
      ],
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFFFDFDF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.castle_rounded,
            color: Color(0xFFEF5B62),
            size: 20,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    'TOWER',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '${session.towerHp} HP',
                    style: const TextStyle(
                      color: Color(0xFFEF5B62),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: session.towerHp / 100,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFFFE2E2),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFEF5B62)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF123A69),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${session.answeredCount}/${session.questionCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 7),
        IconButton(
          key: const ValueKey<String>('solo-stop'),
          onPressed: submitting ? null : onStop,
          icon: const Icon(Icons.pause_rounded),
          color: AppColors.warriorNavy,
          style: IconButton.styleFrom(backgroundColor: Colors.white),
        ),
      ],
    ),
  );
}

class _CardTray extends StatelessWidget {
  const _CardTray({
    required this.hand,
    required this.loading,
    required this.activeQuestionId,
    required this.compact,
    required this.mechanicMode,
    required this.onOpen,
  });
  final List<SoloHandCard> hand;
  final bool loading;
  final String? activeQuestionId;
  final bool compact;
  final SoloMechanicMode mechanicMode;
  final ValueChanged<SoloHandCard> onOpen;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('solo-battle-hand'),
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(8, compact ? 6 : 8, 8, compact ? 7 : 10),
    decoration: const BoxDecoration(color: BattleClayPalette.cream),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Pilih kartu',
              style: GoogleFonts.fredoka(
                fontWeight: FontWeight.w600,
                color: BattleClayPalette.ink,
                fontSize: compact ? 12 : 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                activeQuestionId == null
                    ? 'Jawab untuk menyerang'
                    : (mechanicMode == SoloMechanicMode.focus
                        ? 'Fokus menjawab'
                        : 'Timer kartu tetap berjalan'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: compact ? 9 : 10,
                  color: BattleClayPalette.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 5 : 7),
        BattleDeckPanel(
          panelKey: const ValueKey<String>('solo-battle-deck-panel'),
          compact: compact,
          cards: hand
              .map((SoloHandCard card) {
                final bool isActive =
                    activeQuestionId == card.sessionQuestionId;
                return KeyedSubtree(
                  key: ValueKey<String>('solo-card-${card.sessionQuestionId}'),
                  child: Semantics(
                    label: 'Kartu soal ${card.questionOrder}, ${card.category}',
                    button: true,
                    selected: isActive,
                    child: BattleArenaCard(
                      cardId: card.sessionQuestionId,
                      asset: _cardAsset(card),
                      accent: const Color(0xFF2878F0),
                      compact: compact,
                      enabled: !loading,
                      selected: isActive,
                      onTap: () => onOpen(card),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
    ),
  );
}

String _cardAsset(SoloHandCard card) {
  final value = '${card.category} ${card.subcategory}'.toLowerCase();
  if (value.contains('twk')) return 'assets/game/card_twk.png';
  if (value.contains('akhlak')) return 'assets/game/card_akhlak.png';
  if (value.contains('tkp')) return 'assets/game/card_tkp.png';
  if (value.contains('figural')) return 'assets/game/card_figural.png';
  if (value.contains('numerik')) return 'assets/game/card_numerik.png';
  if (value.contains('verbal')) return 'assets/game/card_verbal.png';
  return 'assets/game/card_logika.png';
}

class _QuestionOverlay extends StatelessWidget {
  const _QuestionOverlay({
    required this.session,
    required this.question,
    required this.feedback,
    required this.selectedOption,
    required this.hintVisible,
    required this.hintLoading,
    required this.submitting,
    required this.error,
    required this.onSelect,
    required this.onHint,
    required this.onTimeout,
    required this.onBack,
    required this.onNext,
  });
  final SoloSession session;
  final SoloQuestion question;
  final SoloAnswerFeedback? feedback;
  final int? selectedOption;
  final bool hintVisible;
  final bool hintLoading;
  final bool submitting;
  final String? error;
  final Future<void> Function(int) onSelect;
  final VoidCallback onHint;
  final VoidCallback onTimeout;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final answered = feedback != null;
    return ColoredBox(
      color: const Color(0x6609162D),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: FractionallySizedBox(
            heightFactor: 0.82,
            widthFactor: 1,
            child: BattleQuestionSheetFrame(
              sheetKey: const ValueKey<String>('solo-question-sheet'),
              accent: AppColors.fireGold,
              child: Column(
                children: <Widget>[
                  Align(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: BattleClayPalette.ink.withAlpha(28),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.fireGold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.extension_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                question.category.toUpperCase(),
                                style: GoogleFonts.fredoka(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Soal ${question.questionOrder}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!answered && session.mechanicMode == SoloMechanicMode.focus)
                          Container(
                            key: const ValueKey<String>('solo-focus-badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF4CAF50),
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.self_improvement_rounded,
                                  size: 14,
                                  color: Color(0xFF2E7D32),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Santai',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (!answered && question.deadlineAt != null)
                          _DeadlineTimer(
                            key: ValueKey<DateTime>(question.deadlineAt!),
                            deadline: question.deadlineAt!,
                            onTimeout: onTimeout,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0xFFD7D9DC),
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              question.prompt,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!answered)
                            hintVisible
                                ? _Hint(
                                    text: question.hint.isEmpty
                                        ? 'Petunjuk belum tersedia untuk soal ini.'
                                        : question.hint,
                                  )
                                : OutlinedButton.icon(
                                    key: const ValueKey<String>(
                                      'solo-show-hint',
                                    ),
                                    onPressed: submitting || hintLoading
                                        ? null
                                        : onHint,
                                    icon: hintLoading
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.help_outline_rounded,
                                            size: 18,
                                          ),
                                    label: const Text('Lihat petunjuk'),
                                  ),
                          if (!answered) const SizedBox(height: 10),
                          if (error != null) ...<Widget>[
                            _ErrorBanner(error!),
                            const SizedBox(height: 10),
                          ],
                          for (
                            int index = 0;
                            index < question.options.length;
                            index++
                          ) ...<Widget>[
                            _Option(
                              index: index,
                              label: question.options[index],
                              selected: selectedOption == index,
                              feedback: answered,
                              correctIndex: feedback?.correctOptionIndex,
                              onTap: () => onSelect(index),
                            ),
                            const SizedBox(height: 9),
                          ],
                          if (answered && feedback!.explanation.isNotEmpty)
                            _Explanation(text: feedback!.explanation),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      14 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            key: const ValueKey<String>('solo-session-action'),
                            onPressed: submitting || !answered ? null : onNext,
                            style: FilledButton.styleFrom(
                              backgroundColor: answered
                                  ? const Color(0xFF2878F0)
                                  : AppColors.fireGold,
                              foregroundColor: answered
                                  ? Colors.white
                                  : AppColors.warriorNavy,
                            ),
                            child: submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    answered ? 'LANJUT' : 'PILIH JAWABAN',
                                    style: GoogleFonts.fredoka(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                        if (!answered)
                          TextButton(
                            key: const ValueKey<String>('solo-back-to-cards'),
                            onPressed: onBack,
                            child: const Text('Kembali ke kartu'),
                          ),
                      ],
                    ),
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

class _DeadlineTimer extends StatefulWidget {
  const _DeadlineTimer({
    super.key,
    required this.deadline,
    required this.onTimeout,
  });
  final DateTime deadline;
  final VoidCallback onTimeout;
  @override
  State<_DeadlineTimer> createState() => _DeadlineTimerState();
}

class _DeadlineTimerState extends State<_DeadlineTimer> {
  Timer? timer;
  late int remaining;
  bool fired = false;

  @override
  void initState() {
    super.initState();
    _tick();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final value = widget.deadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 999);
    if (mounted) setState(() => remaining = value);
    if (value == 0 && !fired) {
      fired = true;
      timer?.cancel();
      widget.onTimeout();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('solo-question-countdown'),
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.fireGold, width: 2),
    ),
    child: Text(
      '$remaining',
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.index,
    required this.label,
    required this.selected,
    required this.feedback,
    required this.correctIndex,
    required this.onTap,
  });
  final int index;
  final String label;
  final bool selected;
  final bool feedback;
  final int? correctIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final correct = feedback && index == correctIndex;
    final wrong = feedback && selected && !correct;
    final color = correct
        ? const Color(0xFF20A778)
        : wrong
        ? const Color(0xFFEF5B62)
        : selected
        ? const Color(0xFF2878F0)
        : const Color(0xFFE0E3E8);
    return Material(
      color: correct
          ? const Color(0xFFDDF7E8)
          : wrong
          ? const Color(0xFFFFE2E2)
          : selected
          ? const Color(0xFFE5EEFF)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey<String>('solo-option-$index'),
        onTap: feedback ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected || correct ? color : const Color(0xFFF0F3F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: selected || correct
                        ? Colors.white
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFDF7E7),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.fireGold),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.info_outline, color: AppColors.fireGold, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, height: 1.35)),
        ),
      ],
    ),
  );
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF2878F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'PEMBAHASAN',
          style: TextStyle(
            color: Color(0xFF2878F0),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE2E2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFB7353B),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _MissingSession extends StatelessWidget {
  const _MissingSession({this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scholarCream,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message ?? 'Sesi Solo belum dimulai.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go(AppRoutes.solo),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SoloResult extends StatelessWidget {
  const _SoloResult({required this.session, required this.onExit});
  final SoloSession session;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) {
    final destroyed = session.policyStopTrigger == 'tower_destroyed';
    final stopped = session.completionReason == 'user_stopped';
    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                destroyed
                    ? Icons.emoji_events_rounded
                    : stopped
                    ? Icons.flag_rounded
                    : Icons.insights_rounded,
                size: 76,
                color: destroyed ? AppColors.fireGold : const Color(0xFF2878F0),
              ),
              const SizedBox(height: 18),
              Text(
                destroyed
                    ? 'MENARA RUNTUH!'
                    : stopped
                    ? 'LATIHAN DIAKHIRI'
                    : 'SESI SELESAI',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  color: AppColors.warriorNavy,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${session.correctCount}/${session.questionCount} benar · ${session.towerHp} HP tersisa',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0xFFD5D9E0), offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  children: <Widget>[
                    const Text(
                      'HADIAH SOLO',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '+${session.rewardCoins} Y-Coin',
                      style: GoogleFonts.fredoka(
                        color: AppColors.fireGold,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: onExit,
                  child: const Text('LATIHAN LAGI'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
