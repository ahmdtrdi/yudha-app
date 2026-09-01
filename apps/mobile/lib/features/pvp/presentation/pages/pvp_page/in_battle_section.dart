part of '../pvp_page.dart';

const int _arenaHandSize = 3;

enum _CharacterPose { idle, ready, attack, hit }

abstract final class _BattleClayPalette {
  static const Color navy = Color(0xFF0D2A52);
  static const Color navyEdge = Color(0xFF061A34);
  static const Color arenaFrame = Color(0xFF244963);
  static const Color cream = Color(0xFFFFF8EC);
  static const Color neutralEdge = Color(0xFFD5D0C5);
  static const Color ink = Color(0xFF17233F);
  static const Color mutedInk = Color(0xFF66708A);
  static const Color player = Color(0xFF2878F0);
  static const Color rival = Color(0xFFF05E5E);
}

class _BattleEffectEvent {
  const _BattleEffectEvent({
    required this.actor,
    required this.kind,
    required this.category,
    required this.amount,
    required this.targetsPlayer,
    required this.isHeal,
    required this.projectileLevel,
  });

  final BattleActor actor;
  final BattleVisualEffect kind;
  final String category;
  final int amount;
  final bool targetsPlayer;
  final bool isHeal;
  final int projectileLevel;
}

class _InBattleSection extends StatefulWidget {
  const _InBattleSection({
    required this.state,
    required this.playerDisplayName,
    required this.playerCharacter,
    required this.opponentCharacter,
    required this.playerTowerAsset,
    required this.playerDestroyedTowerAsset,
    required this.opponentTowerAsset,
    required this.opponentDestroyedTowerAsset,
    required this.arenaAsset,
    required this.arenaTheme,
    required this.soundEnabled,
    required this.hapticsEnabled,
    required this.musicLevel,
    required this.onPause,
    required this.onRoundReady,
    required this.onArenaDisposed,
    required this.onPickQuestion,
  });

  final BattleState state;
  final String playerDisplayName;
  final CharacterVisualAssets playerCharacter;
  final CharacterVisualAssets opponentCharacter;
  final String playerTowerAsset;
  final String playerDestroyedTowerAsset;
  final String opponentTowerAsset;
  final String opponentDestroyedTowerAsset;
  final String arenaAsset;
  final ArenaVisualTheme arenaTheme;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final double musicLevel;
  final Future<void> Function() onPause;
  final VoidCallback onRoundReady;
  final VoidCallback onArenaDisposed;
  final Future<void> Function(BattleQuestion question) onPickQuestion;

  @override
  State<_InBattleSection> createState() => _InBattleSectionState();
}

class _InBattleSectionState extends State<_InBattleSection>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ambientController;
  late final AnimationController _effectController;
  late final AnimationController _shakeController;
  late final AnimationController _hitFlashController;
  late final AnimationController _lowHpController;
  late final ArenaAudioController _arenaAudio;

  Timer? _countdownTimer;
  Timer? _noticeTimer;
  Timer? _answerResultTimer;
  final List<Timer> _effectSoundTimers = <Timer>[];
  final List<_BattleEffectEvent> _pendingEffects = <_BattleEffectEvent>[];
  int _countdownValue = 3;
  bool _countdownDone = false;
  bool _interactionLocked = false;
  bool _pauseOpen = false;
  List<BattleQuestion> _hand = const <BattleQuestion>[];
  String? _selectedQuestionId;
  bool? _answerResultCorrect;
  String? _notice;
  bool _noticeIsError = false;
  bool _imagesPrecached = false;
  bool _playerQuestionReady = false;
  _CharacterPose _playerPose = _CharacterPose.idle;
  _CharacterPose _opponentPose = _CharacterPose.idle;
  Timer? _playerPoseTimer;
  Timer? _opponentPoseTimer;
  bool _playerHitQueued = false;
  bool _opponentHitQueued = false;
  bool _rushModeAnnounced = false;
  double _shakeIntensity = 0.0;

  BattleActor? _effectActor;
  BattleVisualEffect? _effectKind;
  String _effectCategory = 'numerik';
  int _effectAmount = 0;
  bool _effectTargetsPlayer = false;
  bool _effectIsHeal = false;
  int _effectProjectileLevel = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arenaAudio = ArenaAudioController(
      enabled: widget.soundEnabled,
      musicLevel: widget.musicLevel,
    );
    unawaited(_arenaAudio.start());
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..addStatusListener(_handleEffectStatus);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _hitFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _lowHpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _hand = _buildDeckHand(widget.state.availableQuestions);
    _arenaAudio.playCountdown();
    _startCountdownTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_imagesPrecached) {
      return;
    }
    _imagesPrecached = true;
    for (final String asset in <String>[
      widget.playerCharacter.idle,
      widget.playerCharacter.ready,
      widget.playerCharacter.attack,
      widget.playerCharacter.hit,
      widget.opponentCharacter.idle,
      widget.opponentCharacter.ready,
      widget.opponentCharacter.attack,
      widget.opponentCharacter.hit,
    ]) {
      unawaited(
        precacheImage(
          ResizeImage.resizeIfNeeded(360, null, AssetImage(asset)),
          context,
        ),
      );
    }
    for (final String asset in <String>[
      ...widget.playerCharacter.projectiles,
      ...widget.opponentCharacter.projectiles,
    ]) {
      unawaited(
        precacheImage(
          ResizeImage.resizeIfNeeded(240, null, AssetImage(asset)),
          context,
        ),
      );
    }
    for (final String asset in <String>[
      widget.playerTowerAsset,
      widget.playerDestroyedTowerAsset,
      widget.opponentTowerAsset,
      widget.opponentDestroyedTowerAsset,
      widget.arenaAsset,
    ]) {
      unawaited(
        precacheImage(
          ResizeImage.resizeIfNeeded(320, null, AssetImage(asset)),
          context,
        ),
      );
    }
    for (final String asset in <String>[
      _numerikCardAsset,
      _verbalCardAsset,
      _logikaCardAsset,
      _twkCardAsset,
      _akhlakCardAsset,
      _figuralCardAsset,
      _tkpCardAsset,
    ]) {
      unawaited(
        precacheImage(
          ResizeImage.resizeIfNeeded(144, null, AssetImage(asset)),
          context,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _InBattleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.soundEnabled != oldWidget.soundEnabled) {
      unawaited(_arenaAudio.setEnabled(widget.soundEnabled));
    }
    if (widget.musicLevel != oldWidget.musicLevel) {
      unawaited(_arenaAudio.setMusicLevel(widget.musicLevel));
    }
    _rebuildHand();

    if (widget.state.selfAnswerResultId != oldWidget.state.selfAnswerResultId &&
        widget.state.lastSelfAnswerCorrect != null) {
      _showAnswerResult(correct: widget.state.lastSelfAnswerCorrect!);
    }

    final int playerDelta = widget.state.playerHp - oldWidget.state.playerHp;
    final int opponentDelta =
        widget.state.opponentHp - oldWidget.state.opponentHp;
    final bool startingNextRound =
        oldWidget.state.phase == BattlePhase.roundBreak &&
        widget.state.phase == BattlePhase.inBattle;
    if (startingNextRound && _countdownDone) {
      widget.onRoundReady();
    }
    if (!startingNextRound && (playerDelta != 0 || opponentDelta != 0)) {
      _prepareBattleEffect(
        playerDelta: playerDelta,
        opponentDelta: opponentDelta,
      );
    }

    if (oldWidget.state.phase != BattlePhase.roundBreak &&
        widget.state.phase == BattlePhase.roundBreak) {
      _countdownValue = 3;
      _countdownDone = false;
      _interactionLocked = false;
      _selectedQuestionId = null;
      _playerQuestionReady = false;
      _arenaAudio.playCountdown();
      _startCountdownTimer();
    }

    final int oldSeconds = oldWidget.state.roundSecondsRemaining;
    final int currentSeconds = widget.state.roundSecondsRemaining;
    if (widget.state.phase == BattlePhase.inBattle &&
        oldSeconds > 30 &&
        currentSeconds <= 30 &&
        !_rushModeAnnounced) {
      _rushModeAnnounced = true;
      GameHaptics(widget.hapticsEnabled).heavy();
    } else if (widget.state.phase != BattlePhase.inBattle) {
      _rushModeAnnounced = false;
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    if (_countdownDone || _pauseOpen) {
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 680), (
      Timer timer,
    ) {
      if (!mounted || _pauseOpen) {
        timer.cancel();
        return;
      }
      if (_countdownValue > 0) {
        setState(() {
          _countdownValue -= 1;
        });
        if (_countdownValue > 0) {
          _arenaAudio.playCountdown();
          GameHaptics(widget.hapticsEnabled).light();
        }
        return;
      }

      timer.cancel();
      setState(() {
        _countdownDone = true;
      });
      _arenaAudio.playCountdown();
      GameHaptics(widget.hapticsEnabled).medium();
      // The first music attempt can silently lose the race against the
      // countdown SFX burst on Android; nudge playback back on track here.
      unawaited(_arenaAudio.ensureMusic());
      widget.onRoundReady();
    });
  }

  void _rebuildHand() {
    _hand = _buildDeckHand(widget.state.availableQuestions);
  }

  List<BattleQuestion> _buildDeckHand(List<BattleQuestion> questions) {
    final List<String> categoryOrder = _arenaDeckOrder(
      widget.state.battleTarget,
    );
    final List<BattleQuestion> decks = <BattleQuestion>[];
    final Set<String> selectedIds = <String>{};

    for (final String category in categoryOrder) {
      for (final BattleQuestion question in questions) {
        if (_arenaQuestionDeckKey(question, widget.state.battleTarget) ==
                category &&
            selectedIds.add(question.id)) {
          decks.add(question);
          break;
        }
      }
    }

    // The server is authoritative for the three-card hand. Taxonomy metadata
    // may temporarily contain a legacy value, but the client must never hide
    // a card that was already dealt. Fill any unresolved slot from the
    // remaining server hand while preserving the three-card limit.
    for (final BattleQuestion question in questions) {
      if (decks.length == _arenaHandSize) break;
      if (selectedIds.add(question.id)) decks.add(question);
    }

    return decks.take(_arenaHandSize).toList(growable: false);
  }

  void _prepareBattleEffect({
    required int playerDelta,
    required int opponentDelta,
  }) {
    final bool playerChanged = playerDelta != 0;
    final int delta = playerChanged ? playerDelta : opponentDelta;
    final bool isHeal = delta > 0;
    final BattleActor actor = resolveBattleEffectActor(
      playerDelta: playerDelta,
      opponentDelta: opponentDelta,
    );
    final BattleVisualEffect kind = isHeal
        ? BattleVisualEffect.heal
        : widget.state.lastVisualEffect ?? BattleVisualEffect.cannon;
    _pendingEffects.add(
      _BattleEffectEvent(
        actor: actor,
        kind: kind,
        category: widget.state.lastEventCategory ?? 'numerik',
        amount: delta.abs(),
        targetsPlayer: playerChanged,
        isHeal: isHeal,
        projectileLevel: widget.state.lastProjectileLevel,
      ),
    );
    _playNextBattleEffect();
  }

  void _handleEffectStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    _effectController.reset();
    if (_pendingEffects.isEmpty) {
      setState(() {
        _effectActor = null;
        _effectKind = null;
      });
      return;
    }
    _playNextBattleEffect();
  }

  void _playNextBattleEffect() {
    if (!mounted || _effectController.isAnimating || _pendingEffects.isEmpty) {
      return;
    }

    final _BattleEffectEvent event = _pendingEffects.removeAt(0);
    setState(() {
      _effectActor = event.actor;
      _effectKind = event.kind;
      _effectCategory = event.category;
      _effectAmount = event.amount;
      _effectTargetsPlayer = event.targetsPlayer;
      _effectIsHeal = event.isHeal;
      _effectProjectileLevel = event.projectileLevel;
    });
    _playAttackPose(event.actor);
    for (final Timer timer in _effectSoundTimers) {
      timer.cancel();
    }
    _effectSoundTimers.clear();
    _arenaAudio.playCast();
    _effectSoundTimers.add(
      Timer(const Duration(milliseconds: 230), () {
        if (event.isHeal) {
          _arenaAudio.playHeal();
        } else {
          _arenaAudio.playProjectile();
        }
      }),
    );
    if (!event.isHeal) {
      _effectSoundTimers.add(
        Timer(const Duration(milliseconds: 860), () {
          _arenaAudio.playImpact();
          _triggerHitJuice(
            targetsPlayer: event.targetsPlayer,
            projectileLevel: event.projectileLevel,
            amount: event.amount,
          );
          _playHitPose(
            event.targetsPlayer ? BattleActor.player : BattleActor.opponent,
          );
        }),
      );
    }
    _effectController.forward(from: 0);
  }

  void _playAttackPose(BattleActor actor) {
    final Timer? currentTimer = actor == BattleActor.player
        ? _playerPoseTimer
        : _opponentPoseTimer;
    currentTimer?.cancel();
    setState(() {
      if (actor == BattleActor.player) {
        _playerPose = _CharacterPose.attack;
      } else {
        _opponentPose = _CharacterPose.attack;
      }
    });

    final Timer timer = Timer(const Duration(milliseconds: 780), () {
      if (!mounted) {
        return;
      }
      final bool hitQueued = actor == BattleActor.player
          ? _playerHitQueued
          : _opponentHitQueued;
      if (hitQueued) {
        if (actor == BattleActor.player) {
          _playerHitQueued = false;
        } else {
          _opponentHitQueued = false;
        }
        _startHitPose(actor);
        return;
      }
      setState(() => _setRestingPose(actor));
    });
    if (actor == BattleActor.player) {
      _playerPoseTimer = timer;
    } else {
      _opponentPoseTimer = timer;
    }
  }

  void _playHitPose(BattleActor actor) {
    final _CharacterPose pose = actor == BattleActor.player
        ? _playerPose
        : _opponentPose;
    if (pose == _CharacterPose.attack) {
      if (actor == BattleActor.player) {
        _playerHitQueued = true;
      } else {
        _opponentHitQueued = true;
      }
      return;
    }
    _startHitPose(actor);
  }

  void _startHitPose(BattleActor actor) {
    final Timer? currentTimer = actor == BattleActor.player
        ? _playerPoseTimer
        : _opponentPoseTimer;
    currentTimer?.cancel();
    setState(() {
      if (actor == BattleActor.player) {
        _playerPose = _CharacterPose.hit;
      } else {
        _opponentPose = _CharacterPose.hit;
      }
    });
    final Timer timer = Timer(const Duration(milliseconds: 480), () {
      if (!mounted) {
        return;
      }
      setState(() => _setRestingPose(actor));
    });
    if (actor == BattleActor.player) {
      _playerPoseTimer = timer;
    } else {
      _opponentPoseTimer = timer;
    }
  }

  void _triggerHitJuice({
    required bool targetsPlayer,
    required int projectileLevel,
    required int amount,
  }) {
    if (!mounted) {
      return;
    }
    _shakeIntensity =
        (0.5 + (projectileLevel * 0.35) + (amount > 20 ? 0.3 : 0.0)).clamp(
          0.4,
          1.5,
        );
    _shakeController.forward(from: 0);

    // Feedback for the player's own attack already fired in the question
    // sheet, so only vibrate here when the player is the one getting hit.
    final GameHaptics haptics = GameHaptics(widget.hapticsEnabled);
    if (!targetsPlayer) {
      return;
    }
    _hitFlashController.forward(from: 0);
    if (projectileLevel >= 2 || amount >= 25) {
      haptics.heavy();
    } else {
      haptics.medium();
    }
  }

  void _setRestingPose(BattleActor actor) {
    if (actor == BattleActor.player) {
      _playerPose = _playerQuestionReady
          ? _CharacterPose.ready
          : _CharacterPose.idle;
    } else {
      _opponentPose = _CharacterPose.idle;
    }
  }

  void _showNotice(String text, {bool isError = false}) {
    _notice = text;
    _noticeIsError = isError;
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _notice = null;
      });
    });
  }

  void _showAnswerResult({required bool correct}) {
    _answerResultTimer?.cancel();
    _answerResultCorrect = correct;
    _showNotice(correct ? 'Benar!' : 'Salah!', isError: !correct);
    _answerResultTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _answerResultCorrect = null;
      });
    });
  }

  Future<void> _handlePickQuestion(BattleQuestion question) async {
    if (!_countdownDone ||
        _interactionLocked ||
        _pauseOpen ||
        widget.state.phase != BattlePhase.inBattle) {
      return;
    }

    GameHaptics(widget.hapticsEnabled).selection();

    setState(() {
      _interactionLocked = true;
      _selectedQuestionId = question.id;
      _playerQuestionReady = true;
      if (_playerPose == _CharacterPose.idle ||
          _playerPose == _CharacterPose.ready) {
        _playerPose = _CharacterPose.ready;
      }
    });
    _arenaAudio.playCardPick();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      await widget.onPickQuestion(question);
    } finally {
      if (mounted) {
        setState(() {
          _interactionLocked = false;
          _selectedQuestionId = null;
          _playerQuestionReady = false;
          if (_playerPose == _CharacterPose.ready) {
            _playerPose = _CharacterPose.idle;
          }
        });
      }
    }
  }

  void _handleExhaustedQuestion(BattleQuestion question) {
    if (!_countdownDone ||
        _interactionLocked ||
        _pauseOpen ||
        widget.state.phase != BattlePhase.inBattle) {
      return;
    }
    GameHaptics(widget.hapticsEnabled).medium();
    final String category = question.category
        .trim()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .toUpperCase();
    setState(() {
      _showNotice('${category.isEmpty ? 'KARTU' : category} habis');
    });
  }

  Future<void> _handlePause() async {
    if (_pauseOpen || _interactionLocked) {
      return;
    }
    _pauseOpen = true;
    unawaited(_arenaAudio.pauseMusic());
    _countdownTimer?.cancel();
    try {
      await widget.onPause();
    } finally {
      if (mounted) {
        _pauseOpen = false;
        unawaited(_arenaAudio.resumeMusic());
        if (!_countdownDone) {
          _startCountdownTimer();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _noticeTimer?.cancel();
    _answerResultTimer?.cancel();
    for (final Timer timer in _effectSoundTimers) {
      timer.cancel();
    }
    _playerPoseTimer?.cancel();
    _opponentPoseTimer?.cancel();
    _ambientController.dispose();
    _effectController.dispose();
    _shakeController.dispose();
    _hitFlashController.dispose();
    _lowHpController.dispose();
    unawaited(_arenaAudio.dispose());
    widget.onArenaDisposed();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_pauseOpen) {
      unawaited(_arenaAudio.resumeMusic());
      return;
    }
    unawaited(_arenaAudio.pauseMusic());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxHeight < 700 || constraints.maxWidth < 380;

        return DecoratedBox(
          key: const ValueKey<String>('in-battle-stage'),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                _BattleClayPalette.navy,
                Color(0xFF123D60),
                _BattleClayPalette.navy,
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  _BattleHud(
                    isOpponent: true,
                    avatarAsset: widget.opponentCharacter.idle,
                    name: widget.state.opponentName,
                    hp: widget.state.opponentHp,
                    points: widget.state.opponentPoints,
                    mode: widget.state.mode,
                    compact: compact,
                    currentRound: widget.state.currentRound,
                    roundSecondsRemaining: widget.state.roundSecondsRemaining,
                    playerRoundWins: widget.state.playerRoundWins,
                    opponentRoundWins: widget.state.opponentRoundWins,
                    onPause: _handlePause,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 6 : 8,
                        6,
                        compact ? 6 : 8,
                        6,
                      ),
                      child: _ArenaShakeWrapper(
                        controller: _shakeController,
                        intensity: _shakeIntensity,
                        child: _ArenaBoard(
                          playerHp: widget.state.playerHp,
                          opponentHp: widget.state.opponentHp,
                          playerCharacter: widget.playerCharacter,
                          opponentCharacter: widget.opponentCharacter,
                          playerTowerAsset: widget.playerTowerAsset,
                          playerDestroyedTowerAsset:
                              widget.playerDestroyedTowerAsset,
                          opponentTowerAsset: widget.opponentTowerAsset,
                          opponentDestroyedTowerAsset:
                              widget.opponentDestroyedTowerAsset,
                          arenaAsset: widget.arenaAsset,
                          playerPose: _playerPose,
                          opponentPose: _opponentPose,
                          arenaTheme: widget.arenaTheme,
                          compact: compact,
                          ambientAnimation: _ambientController,
                          effectAnimation: _effectController,
                          effectActor: _effectActor,
                          effectKind: _effectKind,
                          effectCategory: _effectCategory,
                          effectAmount: _effectAmount,
                          effectTargetsPlayer: _effectTargetsPlayer,
                          effectIsHeal: _effectIsHeal,
                          effectProjectileLevel: _effectProjectileLevel,
                        ),
                      ),
                    ),
                  ),
                  _BattleHud(
                    isOpponent: false,
                    avatarAsset: widget.playerCharacter.idle,
                    name: widget.playerDisplayName,
                    hp: widget.state.playerHp,
                    points: widget.state.playerPoints,
                    mode: widget.state.mode,
                    compact: compact,
                    comboLevel: widget.state.comboLevel,
                    comboSecondsRemaining: widget.state.comboSecondsRemaining,
                  ),
                  _BattleHand(
                    questions: _hand,
                    compact: compact,
                    enabled:
                        widget.state.phase == BattlePhase.inBattle &&
                        _countdownDone &&
                        !_interactionLocked &&
                        !_pauseOpen,
                    selectedQuestionId: _selectedQuestionId,
                    answerResultCorrect: _answerResultCorrect,
                    processing: _interactionLocked,
                    onPickQuestion: _handlePickQuestion,
                    onExhaustedQuestion: _handleExhaustedQuestion,
                  ),
                ],
              ),
              if (widget.state.playerHp <= 30 &&
                  widget.state.phase == BattlePhase.inBattle)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _LowHpVignetteOverlay(animation: _lowHpController),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: _HitFlashOverlay(animation: _hitFlashController),
                ),
              ),
              Positioned(
                top: compact ? 64 : 72,
                left: 18,
                right: 18,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _notice == null
                        ? const SizedBox.shrink()
                        : _ArenaNotice(
                            key: ValueKey<String>(_notice!),
                            text: _notice!,
                            isError: _noticeIsError,
                          ),
                  ),
                ),
              ),
              if (!widget.state.opponentConnected)
                const Positioned(
                  top: 72,
                  left: 18,
                  right: 18,
                  child: _OpponentReconnectBanner(),
                ),
              if (!_countdownDone)
                _CountdownOverlay(
                  value: _countdownValue,
                  round: widget.state.phase == BattlePhase.roundBreak
                      ? widget.state.currentRound + 1
                      : widget.state.currentRound,
                  resultMessage: widget.state.phase == BattlePhase.roundBreak
                      ? widget.state.statusMessage
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BattleHud extends StatelessWidget {
  const _BattleHud({
    required this.isOpponent,
    required this.avatarAsset,
    required this.name,
    required this.hp,
    required this.points,
    required this.mode,
    required this.compact,
    this.onPause,
    this.comboLevel,
    this.comboSecondsRemaining,
    this.currentRound,
    this.roundSecondsRemaining,
    this.playerRoundWins,
    this.opponentRoundWins,
  });

  final bool isOpponent;
  final String avatarAsset;
  final String name;
  final int hp;
  final int points;
  final BattleMode mode;
  final bool compact;
  final VoidCallback? onPause;
  final int? comboLevel;
  final int? comboSecondsRemaining;
  final int? currentRound;
  final int? roundSecondsRemaining;
  final int? playerRoundWins;
  final int? opponentRoundWins;

  @override
  Widget build(BuildContext context) {
    final Color accent = isOpponent
        ? _BattleClayPalette.rival
        : _BattleClayPalette.player;
    final int safeHp = hp.clamp(0, 100).toInt();

    return Container(
      key: ValueKey<String>(
        isOpponent ? 'battle-hud-opponent' : 'battle-hud-player',
      ),
      constraints: BoxConstraints(minHeight: compact ? 58 : 66),
      padding: EdgeInsets.fromLTRB(10, compact ? 6 : 8, 10, compact ? 6 : 8),
      decoration: BoxDecoration(
        color: _BattleClayPalette.cream,
        borderRadius: BorderRadius.vertical(
          bottom: isOpponent ? const Radius.circular(18) : Radius.zero,
          top: isOpponent ? Radius.zero : const Radius.circular(18),
        ),
        border: Border.all(color: Colors.white.withAlpha(190)),
        boxShadow: isOpponent
            ? <BoxShadow>[
                BoxShadow(
                  color: _BattleClayPalette.rival.withAlpha(72),
                  blurRadius: 0,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        children: <Widget>[
          _BattleAvatar(asset: avatarAsset, accent: accent, compact: compact),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fredoka(
                          color: _BattleClayPalette.ink,
                          fontSize: compact ? 13 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isOpponent)
                      _ModePill(mode: mode)
                    else
                      Text(
                        'HP $safeHp',
                        style: GoogleFonts.dmSans(
                          color: _BattleClayPalette.mutedInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                _AnimatedHpBar(value: safeHp / 100, accent: accent),
              ],
            ),
          ),
          const SizedBox(width: 9),
          if (!isOpponent && comboLevel != null) ...<Widget>[
            _ComboBadge(
              level: comboLevel!,
              secondsRemaining: comboSecondsRemaining ?? 0,
              compact: compact,
            ),
            const SizedBox(width: 6),
          ],
          if (isOpponent && currentRound != null) ...<Widget>[
            _RoundClockPill(
              round: currentRound!,
              secondsRemaining: roundSecondsRemaining ?? 0,
              playerWins: playerRoundWins ?? 0,
              opponentWins: opponentRoundWins ?? 0,
              compact: compact,
            ),
            const SizedBox(width: 6),
          ],
          _ScorePill(points: points, accent: accent),
          if (onPause != null) ...<Widget>[
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Opsi battle',
              child: IconButton(
                onPressed: onPause,
                tooltip: 'Opsi battle',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: _BattleClayPalette.navy,
                  backgroundColor: Colors.white,
                  shadowColor: _BattleClayPalette.neutralEdge,
                  elevation: 4,
                ),
                icon: const Icon(Icons.pause_rounded, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComboBadge extends StatelessWidget {
  const _ComboBadge({
    required this.level,
    required this.secondsRemaining,
    required this.compact,
  });

  final int level;
  final int secondsRemaining;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool active = level > 1 && secondsRemaining > 0;
    final Color accent = switch (level) {
      3 => const Color(0xFFF05E5E),
      2 => const Color(0xFFFF9F43),
      _ => const Color(0xFF66708A),
    };
    return Semantics(
      label: 'Combo serangan',
      value: active ? 'x$level, $secondsRemaining detik' : 'x1',
      child: Container(
        key: const ValueKey<String>('combo-meter'),
        constraints: BoxConstraints(minWidth: compact ? 45 : 50),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withAlpha(22), Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withAlpha(72)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withAlpha(64),
              blurRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'COMBO',
              maxLines: 1,
              style: GoogleFonts.dmSans(
                color: accent,
                fontSize: compact ? 7 : 7.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'x$level',
              style: GoogleFonts.jetBrainsMono(
                color: _BattleClayPalette.ink,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundClockPill extends StatelessWidget {
  const _RoundClockPill({
    required this.round,
    required this.secondsRemaining,
    required this.playerWins,
    required this.opponentWins,
    required this.compact,
  });

  final int round;
  final int secondsRemaining;
  final int playerWins;
  final int opponentWins;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final int safeSeconds = secondsRemaining.clamp(
      0,
      BattleController.roundDurationSeconds,
    );
    final String minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final String seconds = (safeSeconds % 60).toString().padLeft(2, '0');
    final bool isRush = safeSeconds <= 30 && safeSeconds > 0;
    return Semantics(
      label: 'Ronde $round',
      value:
          '$minutes menit $seconds detik, skor ronde '
          '$playerWins lawan $opponentWins',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        key: const ValueKey<String>('round-clock'),
        constraints: BoxConstraints(minWidth: compact ? 58 : 66),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isRush ? const Color(0xFFC0392B) : _BattleClayPalette.navy,
          borderRadius: BorderRadius.circular(12),
          border: isRush
              ? Border.all(color: const Color(0xFFFFC857), width: 1.5)
              : null,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: isRush
                  ? const Color(0xFF7E251C)
                  : _BattleClayPalette.navyEdge,
              blurRadius: isRush ? 8 : 0,
              spreadRadius: isRush ? 1 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isRush ? '🔥 $minutes:$seconds' : 'R$round  $minutes:$seconds',
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: compact ? 8 : 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$playerWins  •  $opponentWins',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFFFC857),
                fontSize: compact ? 8 : 9,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleAvatar extends StatelessWidget {
  const _BattleAvatar({
    required this.asset,
    required this.accent,
    required this.compact,
  });

  final String asset;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 42 : 48;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: accent.withAlpha(28),
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withAlpha(82),
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: 160,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});

  final BattleMode mode;

  @override
  Widget build(BuildContext context) {
    final bool online = mode == BattleMode.online;
    final Color accent = online
        ? const Color(0xFF238963)
        : const Color(0xFF2878F0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          online ? Icons.wifi_rounded : Icons.smart_toy_outlined,
          color: accent,
          size: 13,
        ),
        const SizedBox(width: 4),
        Text(
          online ? 'ONLINE' : 'BOT',
          style: GoogleFonts.dmSans(
            color: accent,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.points, required this.accent});

  final int points;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(13),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color.alphaBlend(Colors.black.withAlpha(75), accent),
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$points',
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          Text(
            'SKOR',
            style: GoogleFonts.dmSans(
              color: Colors.white.withAlpha(215),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedHpBar extends StatelessWidget {
  const _AnimatedHpBar({required this.value, required this.accent});

  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E1D7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: _BattleClayPalette.neutralEdge,
            blurRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: value.clamp(0, 1)),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double animated, Widget? child) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: animated,
                    heightFactor: 1,
                    child: ColoredBox(color: accent),
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

class _ArenaBoard extends StatelessWidget {
  const _ArenaBoard({
    required this.playerHp,
    required this.opponentHp,
    required this.playerCharacter,
    required this.opponentCharacter,
    required this.playerTowerAsset,
    required this.playerDestroyedTowerAsset,
    required this.opponentTowerAsset,
    required this.opponentDestroyedTowerAsset,
    required this.arenaAsset,
    required this.playerPose,
    required this.opponentPose,
    required this.arenaTheme,
    required this.compact,
    required this.ambientAnimation,
    required this.effectAnimation,
    required this.effectActor,
    required this.effectKind,
    required this.effectCategory,
    required this.effectAmount,
    required this.effectTargetsPlayer,
    required this.effectIsHeal,
    required this.effectProjectileLevel,
  });

  final int playerHp;
  final int opponentHp;
  final CharacterVisualAssets playerCharacter;
  final CharacterVisualAssets opponentCharacter;
  final String playerTowerAsset;
  final String playerDestroyedTowerAsset;
  final String opponentTowerAsset;
  final String opponentDestroyedTowerAsset;
  final String arenaAsset;
  final _CharacterPose playerPose;
  final _CharacterPose opponentPose;
  final ArenaVisualTheme arenaTheme;
  final bool compact;
  final Animation<double> ambientAnimation;
  final Animation<double> effectAnimation;
  final BattleActor? effectActor;
  final BattleVisualEffect? effectKind;
  final String effectCategory;
  final int effectAmount;
  final bool effectTargetsPlayer;
  final bool effectIsHeal;
  final int effectProjectileLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('battle-arena-board'),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _BattleClayPalette.arenaFrame,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(52), width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: _BattleClayPalette.navyEdge,
            blurRadius: 0,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final double height = constraints.maxHeight;
            final double mainSize = compact
                ? (width * 0.29).clamp(88.0, 108.0)
                : (width * 0.34).clamp(112.0, 142.0);
            final double miniSize = mainSize * 0.61;

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Image.asset(
                    arenaAsset,
                    key: const ValueKey<String>('battle-arena-background'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    cacheWidth: 1024,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.10,
                      child: CustomPaint(
                        painter: _ClayArenaPainter(arenaTheme),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: height * 0.35,
                  right: 7,
                  child: const _ArenaPropCluster(
                    accent: Color(0xFFF05E5E),
                    mirrored: true,
                  ),
                ),
                Positioned(
                  bottom: height * 0.35,
                  left: 7,
                  child: const _ArenaPropCluster(accent: Color(0xFF2878F0)),
                ),
                Positioned(
                  top: -5,
                  left: (width - mainSize * 1.12) / 2,
                  width: mainSize * 1.12,
                  height: mainSize,
                  child: _ChampionStand(
                    character: opponentCharacter,
                    pose: opponentPose,
                    accent: const Color(0xFFF05E5E),
                    destroyed: opponentHp <= 0,
                    ambientAnimation: ambientAnimation,
                  ),
                ),
                Positioned(
                  top: height * 0.22,
                  left: width * 0.17 - miniSize / 2,
                  width: miniSize,
                  height: miniSize,
                  child: _TowerAsset(
                    activeAsset: opponentTowerAsset,
                    destroyedAsset: opponentDestroyedTowerAsset,
                    destroyed: opponentHp <= 0,
                    ambientAnimation: ambientAnimation,
                  ),
                ),
                Positioned(
                  top: height * 0.22,
                  left: width * 0.83 - miniSize / 2,
                  width: miniSize,
                  height: miniSize,
                  child: _TowerAsset(
                    activeAsset: opponentTowerAsset,
                    destroyedAsset: opponentDestroyedTowerAsset,
                    destroyed: opponentHp <= 0,
                    ambientAnimation: ambientAnimation,
                  ),
                ),
                Positioned(
                  bottom: height * 0.22,
                  left: width * 0.17 - miniSize / 2,
                  width: miniSize,
                  height: miniSize,
                  child: _TowerAsset(
                    activeAsset: playerTowerAsset,
                    destroyedAsset: playerDestroyedTowerAsset,
                    destroyed: playerHp <= 0,
                    ambientAnimation: ambientAnimation,
                  ),
                ),
                Positioned(
                  bottom: height * 0.22,
                  left: width * 0.83 - miniSize / 2,
                  width: miniSize,
                  height: miniSize,
                  child: _TowerAsset(
                    activeAsset: playerTowerAsset,
                    destroyedAsset: playerDestroyedTowerAsset,
                    destroyed: playerHp <= 0,
                    ambientAnimation: ambientAnimation,
                  ),
                ),
                Positioned(
                  bottom: -5,
                  left: (width - mainSize * 1.12) / 2,
                  width: mainSize * 1.12,
                  height: mainSize,
                  child: _ChampionStand(
                    character: playerCharacter,
                    pose: playerPose,
                    accent: const Color(0xFF2878F0),
                    destroyed: playerHp <= 0,
                    ambientAnimation: ambientAnimation,
                  ),
                ),
                Positioned.fill(
                  child: _BattleEffectLayer(
                    animation: effectAnimation,
                    actor: effectActor,
                    kind: effectKind,
                    category: effectCategory,
                    amount: effectAmount,
                    targetsPlayer: effectTargetsPlayer,
                    isHeal: effectIsHeal,
                    projectileLevel: effectProjectileLevel,
                    playerCharacter: playerCharacter,
                    opponentCharacter: opponentCharacter,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArenaHeroAsset extends StatelessWidget {
  const _ArenaHeroAsset({
    required this.character,
    required this.pose,
    required this.ambientAnimation,
  });

  final CharacterVisualAssets character;
  final _CharacterPose pose;
  final Animation<double> ambientAnimation;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final String asset = switch (pose) {
      _CharacterPose.idle => character.idle,
      _CharacterPose.ready => character.ready,
      _CharacterPose.attack => character.attack,
      _CharacterPose.hit => character.hit,
    };
    return AnimatedBuilder(
      animation: ambientAnimation,
      builder: (BuildContext context, Widget? child) {
        final double wave = reduceMotion
            ? 0
            : sin(ambientAnimation.value * pi * 2);
        return Transform.translate(
          offset: Offset(0, wave * 1.8),
          child: Transform.rotate(angle: wave * 0.01, child: child),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 90),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Image.asset(
          asset,
          key: ValueKey<String>(asset),
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          cacheWidth: 360,
          filterQuality: FilterQuality.low,
          semanticLabel: 'Karakter di arena dalam pose ${pose.name}',
        ),
      ),
    );
  }
}

class _ChampionStand extends StatelessWidget {
  const _ChampionStand({
    required this.character,
    required this.pose,
    required this.accent,
    required this.destroyed,
    required this.ambientAnimation,
  });

  final CharacterVisualAssets character;
  final _CharacterPose pose;
  final Color accent;
  final bool destroyed;
  final Animation<double> ambientAnimation;

  @override
  Widget build(BuildContext context) {
    final Widget stand = Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 30,
          right: 30,
          bottom: 27,
          height: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(62),
              borderRadius: const BorderRadius.all(Radius.elliptical(60, 14)),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x3317233F), blurRadius: 7),
              ],
            ),
          ),
        ),
        Positioned(
          top: -4,
          left: 4,
          right: 4,
          bottom: 21,
          child: _ArenaHeroAsset(
            character: character,
            pose: pose,
            ambientAnimation: ambientAnimation,
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 0,
          height: 39,
          child: RepaintBoundary(
            child: CustomPaint(painter: _ChampionPodiumPainter(accent)),
          ),
        ),
        Positioned(
          bottom: 5,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(color: accent.withAlpha(90), blurRadius: 6),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              size: 11,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );

    return AnimatedOpacity(
      opacity: destroyed ? 0.46 : 1,
      duration: const Duration(milliseconds: 240),
      child: ColorFiltered(
        colorFilter: destroyed
            ? const ColorFilter.matrix(<double>[
                0.32,
                0.32,
                0.32,
                0,
                0,
                0.32,
                0.32,
                0.32,
                0,
                0,
                0.32,
                0.32,
                0.32,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ])
            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: stand,
      ),
    );
  }
}

class _ChampionPodiumPainter extends CustomPainter {
  const _ChampionPodiumPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..isAntiAlias = true;
    final Rect shadow = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.66,
      size.width * 0.84,
      size.height * 0.28,
    );
    paint.color = Colors.black.withAlpha(45);
    canvas.drawOval(shadow.shift(const Offset(0, 3)), paint);

    final Path front = Path()
      ..moveTo(size.width * 0.16, size.height * 0.34)
      ..lineTo(size.width * 0.84, size.height * 0.34)
      ..lineTo(size.width * 0.75, size.height * 0.88)
      ..lineTo(size.width * 0.25, size.height * 0.88)
      ..close();
    paint.color = Color.alphaBlend(
      accent.withAlpha(55),
      const Color(0xFFD9C6A4),
    );
    canvas.drawPath(front, paint);

    final Path rightSide = Path()
      ..moveTo(size.width * 0.84, size.height * 0.34)
      ..lineTo(size.width * 0.75, size.height * 0.88)
      ..lineTo(size.width * 0.67, size.height * 0.82)
      ..lineTo(size.width * 0.73, size.height * 0.38)
      ..close();
    paint.color = Color.alphaBlend(
      accent.withAlpha(70),
      const Color(0xFF967B5A),
    );
    canvas.drawPath(rightSide, paint);

    final Rect top = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.13,
      size.width * 0.76,
      size.height * 0.38,
    );
    paint.color = Color.alphaBlend(
      accent.withAlpha(38),
      const Color(0xFFF3E1BD),
    );
    canvas.drawOval(top, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.alphaBlend(
        accent.withAlpha(145),
        const Color(0xFF8E7658),
      );
    canvas.drawOval(top, paint);
  }

  @override
  bool shouldRepaint(covariant _ChampionPodiumPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class _TowerAsset extends StatelessWidget {
  const _TowerAsset({
    required this.activeAsset,
    required this.destroyedAsset,
    required this.destroyed,
    required this.ambientAnimation,
  });

  final String activeAsset;
  final String destroyedAsset;
  final bool destroyed;
  final Animation<double> ambientAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ambientAnimation,
      builder: (BuildContext context, Widget? child) {
        final double float = (ambientAnimation.value - 0.5) * 2;
        return Transform.translate(
          offset: Offset(0, destroyed ? 4 : float),
          child: AnimatedRotation(
            turns: destroyed ? 0.018 : 0,
            duration: const Duration(milliseconds: 260),
            child: AnimatedOpacity(
              opacity: destroyed ? 0.42 : 1,
              duration: const Duration(milliseconds: 220),
              child: ColorFiltered(
                colorFilter: destroyed
                    ? const ColorFilter.matrix(<double>[
                        0.32,
                        0.32,
                        0.32,
                        0,
                        0,
                        0.32,
                        0.32,
                        0.32,
                        0,
                        0,
                        0.32,
                        0.32,
                        0.32,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: child!,
              ),
            ),
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Image.asset(
          destroyed ? destroyedAsset : activeAsset,
          key: ValueKey<String>(destroyed ? destroyedAsset : activeAsset),
          fit: BoxFit.contain,
          cacheWidth: 320,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}

class _ArenaPropCluster extends StatelessWidget {
  const _ArenaPropCluster({required this.accent, this.mirrored = false});

  final Color accent;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: mirrored,
      child: SizedBox(
        width: 48,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 3,
              bottom: 1,
              child: Container(
                width: 19,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0A4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4A85D)),
                ),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 17,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7C875),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                width: 27,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF45A85C),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF2E8845), width: 2),
                ),
              ),
            ),
            Positioned(
              left: 25,
              bottom: 7,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF65BF68),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleEffectLayer extends StatelessWidget {
  const _BattleEffectLayer({
    required this.animation,
    required this.actor,
    required this.kind,
    required this.category,
    required this.amount,
    required this.targetsPlayer,
    required this.isHeal,
    required this.projectileLevel,
    required this.playerCharacter,
    required this.opponentCharacter,
  });

  final Animation<double> animation;
  final BattleActor? actor;
  final BattleVisualEffect? kind;
  final String category;
  final int amount;
  final bool targetsPlayer;
  final bool isHeal;
  final int projectileLevel;
  final CharacterVisualAssets playerCharacter;
  final CharacterVisualAssets opponentCharacter;

  @override
  Widget build(BuildContext context) {
    if (actor == null || kind == null || amount <= 0) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final double raw = animation.value;
              const double launchAt = 0.20;
              const double impactAt = 0.82;
              final double travelProgress =
                  ((raw - launchAt) / (impactAt - launchAt)).clamp(0, 1);
              final double travel = Curves.easeInOutCubic.transform(
                travelProgress,
              );
              final Offset playerPoint = Offset(
                constraints.maxWidth * 0.5,
                constraints.maxHeight * 0.82,
              );
              final Offset opponentPoint = Offset(
                constraints.maxWidth * 0.5,
                constraints.maxHeight * 0.18,
              );
              final Offset start = actor == BattleActor.player
                  ? playerPoint
                  : opponentPoint;
              final Offset target = targetsPlayer ? playerPoint : opponentPoint;
              final double direction = actor == BattleActor.player ? -1 : 1;
              final Offset linear = Offset.lerp(start, target, travel)!;
              final Offset curved = switch (kind!) {
                BattleVisualEffect.cannon => Offset(
                  linear.dx +
                      sin(pi * travel) *
                          constraints.maxWidth *
                          0.18 *
                          direction,
                  linear.dy - sin(pi * travel) * 22,
                ),
                BattleVisualEffect.wizard => Offset(
                  linear.dx + sin(pi * travel * 4) * 15,
                  linear.dy - sin(pi * travel) * 11,
                ),
                BattleVisualEffect.robot => Offset(
                  linear.dx + sin(pi * travel * 2) * 4 * direction,
                  linear.dy - sin(pi * travel) * 7,
                ),
                BattleVisualEffect.heal => target,
              };
              final double projectileAngle = actor == BattleActor.player
                  ? pi / 2
                  : -pi / 2;
              final bool showProjectile =
                  !isHeal && raw >= launchAt && raw < impactAt;
              final bool showHeal = isHeal && raw >= launchAt;
              final bool showImpact = !isHeal && raw >= impactAt;
              final Color color = _battleEffectColor(kind!, category);
              final CharacterVisualAssets projectileOwner =
                  actor == BattleActor.player
                  ? playerCharacter
                  : opponentCharacter;
              final String projectileAsset = projectileOwner.projectileForLevel(
                projectileLevel,
              );
              final double projectileSize = switch (projectileLevel) {
                3 => 76,
                2 => 66,
                _ => 56,
              };
              final double healProgress = ((raw - launchAt) / (1 - launchAt))
                  .clamp(0, 1);

              return Stack(
                children: <Widget>[
                  if (showProjectile)
                    Positioned(
                      left: curved.dx - projectileSize / 2,
                      top: curved.dy - projectileSize / 2,
                      child: Transform.rotate(
                        angle: projectileAngle,
                        child: _CharacterProjectile(
                          asset: projectileAsset,
                          level: projectileLevel,
                          size: projectileSize,
                          color: color,
                        ),
                      ),
                    ),
                  if (showHeal)
                    Positioned(
                      left: target.dx - 42,
                      top: target.dy - 42,
                      child: _HealBloom(progress: healProgress, color: color),
                    )
                  else if (showImpact)
                    Positioned(
                      left: target.dx - 35,
                      top: target.dy - 35,
                      child: Opacity(
                        opacity: (1 - ((raw - impactAt) / (1 - impactAt)))
                            .clamp(0, 1),
                        child: Transform.scale(
                          scale: 0.65 + raw * 0.55,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withAlpha(isHeal ? 45 : 30),
                              border: Border.all(color: color, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (raw >= 0.76)
                    Positioned(
                      left: target.dx - 55,
                      top: target.dy - 64 - ((raw - 0.76) * 38),
                      width: 110,
                      child: Opacity(
                        opacity: (1 - ((raw - 0.84).clamp(0, 0.16) / 0.16))
                            .clamp(0, 1),
                        child: Transform.scale(
                          scale: 0.8 + ((raw - 0.76) / 0.08).clamp(0, 1) * 0.35,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (!isHeal && projectileLevel >= 2)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9F43),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    projectileLevel == 3
                                        ? '🔥 CRITICAL x3!'
                                        : '⚡ COMBO x2!',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              Text(
                                '${isHeal ? '+' : '-'}$amount',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.fredoka(
                                  color: isHeal
                                      ? const Color(0xFF2ECC71)
                                      : (projectileLevel >= 2
                                            ? const Color(0xFFFF5252)
                                            : color),
                                  fontSize: projectileLevel >= 2 ? 28 : 24,
                                  fontWeight: FontWeight.w700,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.white,
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
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
        },
      ),
    );
  }
}

class _CharacterProjectile extends StatelessWidget {
  const _CharacterProjectile({
    required this.asset,
    required this.level,
    required this.size,
    required this.color,
  });

  final String asset;
  final int level;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('projectile-level-$level'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withAlpha(level == 3 ? 125 : 78),
            blurRadius: level == 3 ? 18 : 11,
            spreadRadius: level - 1,
          ),
        ],
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        cacheWidth: 240,
        filterQuality: FilterQuality.low,
        semanticLabel: 'Projectile combo level $level',
      ),
    );
  }
}

class _HealBloom extends StatelessWidget {
  const _HealBloom({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double pulse = sin(progress * pi).clamp(0, 1).toDouble();
    return Opacity(
      opacity: (1 - progress * 0.55).clamp(0, 1),
      child: Transform.scale(
        scale: 0.55 + pulse * 0.65,
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(38),
                  border: Border.all(color: color, width: 3),
                ),
              ),
              Icon(Icons.shield_rounded, color: color, size: 46),
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
              Positioned(
                left: 5,
                top: 17 - progress * 10,
                child: Icon(Icons.eco_rounded, color: color, size: 20),
              ),
              Positioned(
                right: 5,
                top: 22 - progress * 13,
                child: Transform.flip(
                  flipX: true,
                  child: Icon(Icons.eco_rounded, color: color, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BattleHand extends StatelessWidget {
  const _BattleHand({
    required this.questions,
    required this.compact,
    required this.enabled,
    required this.selectedQuestionId,
    required this.answerResultCorrect,
    required this.processing,
    required this.onPickQuestion,
    required this.onExhaustedQuestion,
  });

  final List<BattleQuestion> questions;
  final bool compact;
  final bool enabled;
  final String? selectedQuestionId;
  final bool? answerResultCorrect;
  final bool processing;
  final ValueChanged<BattleQuestion> onPickQuestion;
  final ValueChanged<BattleQuestion> onExhaustedQuestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('battle-hand'),
      padding: EdgeInsets.fromLTRB(8, compact ? 6 : 8, 8, compact ? 7 : 10),
      decoration: const BoxDecoration(color: _BattleClayPalette.cream),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Pilih kartu',
                style: GoogleFonts.fredoka(
                  color: _BattleClayPalette.ink,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: answerResultCorrect == null
                    ? processing
                          ? _BattleProcessingBadge(compact: compact)
                          : Text(
                              enabled
                                  ? 'Jawab untuk bergerak'
                                  : 'Bersiap di arena',
                              key: const ValueKey<String>('battle-hand-helper'),
                              style: GoogleFonts.dmSans(
                                color: _BattleClayPalette.mutedInk,
                                fontSize: compact ? 9 : 10,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                    : _BattleAnswerResultBadge(
                        key: ValueKey<String>(
                          'battle-answer-result-$answerResultCorrect',
                        ),
                        correct: answerResultCorrect!,
                        compact: compact,
                      ),
              ),
            ],
          ),
          SizedBox(height: compact ? 5 : 7),
          Align(
            alignment: Alignment.center,
            child: Container(
              key: const ValueKey<String>('battle-deck-panel'),
              width: compact ? 238 : 276,
              height: compact ? 98 : 116,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 18,
                vertical: compact ? 5 : 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB8C0CC), width: 1.2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x2B17233F),
                    blurRadius: 0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List<Widget>.generate(3, (int index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                      child: index < questions.length
                          ? _ArenaQuestionCard(
                              question: questions[index],
                              compact: compact,
                              enabled: enabled,
                              selected:
                                  selectedQuestionId == questions[index].id,
                              onTap: () => onPickQuestion(questions[index]),
                              onExhausted: () =>
                                  onExhaustedQuestion(questions[index]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleProcessingBadge extends StatelessWidget {
  const _BattleProcessingBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('battle-card-processing'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2878F0).withAlpha(20),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF2878F0).withAlpha(65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: compact ? 9 : 10,
            height: compact ? 9 : 10,
            child: const CircularProgressIndicator(
              strokeWidth: 1.7,
              color: Color(0xFF2878F0),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'MEMBUKA KARTU',
            style: GoogleFonts.dmSans(
              color: const Color(0xFF1F62BF),
              fontSize: compact ? 7 : 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaQuestionCard extends StatefulWidget {
  const _ArenaQuestionCard({
    required this.question,
    required this.compact,
    required this.enabled,
    required this.selected,
    required this.onTap,
    required this.onExhausted,
  });

  final BattleQuestion question;
  final bool compact;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onExhausted;

  @override
  State<_ArenaQuestionCard> createState() => _ArenaQuestionCardState();
}

class _ArenaQuestionCardState extends State<_ArenaQuestionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exhaustedShakeController;

  @override
  void initState() {
    super.initState();
    _exhaustedShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void dispose() {
    _exhaustedShakeController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.question.isExhausted) {
      _exhaustedShakeController.forward(from: 0);
      widget.onExhausted();
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final BattleQuestion question = widget.question;
    final Color color = _arenaCategoryColor(
      question.category,
      question.effect,
      subcategory: question.subcategory,
    );
    final String asset = _arenaCardAsset(
      question.category,
      question.effect,
      subcategory: question.subcategory,
    );
    final bool heal = question.effect == QuestionEffect.heal;
    final bool exhausted = question.isExhausted;

    return AnimatedBuilder(
      animation: _exhaustedShakeController,
      builder: (BuildContext context, Widget? child) {
        final double progress = _exhaustedShakeController.value;
        final double offset = sin(progress * pi * 8) * 6 * (1 - progress);
        return Transform.translate(
          key: ValueKey<String>('exhausted-card-shake-${question.id}'),
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: AnimatedScale(
        scale: widget.selected ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: exhausted
              ? 0.48
              : widget.enabled || widget.selected
              ? 1
              : 0.58,
          duration: const Duration(milliseconds: 140),
          child: ColorFiltered(
            key: ValueKey<String>('question-card-filter-${question.id}'),
            colorFilter: exhausted
                ? const ColorFilter.matrix(<double>[
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey<String>('question-card-${question.id}'),
                onTap: widget.enabled ? _handleTap : null,
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  key: ValueKey<String>('question-card-surface-${question.id}'),
                  padding: EdgeInsets.all(widget.compact ? 1 : 2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.asset(
                        asset,
                        fit: BoxFit.contain,
                        cacheWidth: 180,
                        filterQuality: FilterQuality.low,
                      ),
                      Positioned(
                        left: widget.compact ? 3 : 4,
                        bottom: widget.compact ? 3 : 4,
                        child: Container(
                          width: widget.compact ? 19 : 22,
                          height: widget.compact ? 19 : 22,
                          decoration: BoxDecoration(
                            color: exhausted ? const Color(0xFF7D8490) : color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color:
                                    (exhausted
                                            ? const Color(0xFF7D8490)
                                            : color)
                                        .withAlpha(90),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Semantics(
                            label: heal ? 'Kartu heal' : 'Kartu attack',
                            child: heal
                                ? Icon(
                                    Icons.favorite_rounded,
                                    key: ValueKey<String>(
                                      'question-card-effect-${question.id}-heal',
                                    ),
                                    color: Colors.white,
                                    size: widget.compact ? 12 : 14,
                                  )
                                : SvgPicture.asset(
                                    _attackCardIconAsset,
                                    key: ValueKey<String>(
                                      'question-card-effect-${question.id}-attack',
                                    ),
                                    width: widget.compact ? 14 : 16,
                                    height: widget.compact ? 14 : 16,
                                    fit: BoxFit.contain,
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
        ),
      ),
    );
  }
}

class _BattleAnswerResultBadge extends StatelessWidget {
  const _BattleAnswerResultBadge({
    required super.key,
    required this.correct,
    required this.compact,
  });

  final bool correct;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color color = correct
        ? const Color(0xFF168A61)
        : const Color(0xFFD83D50);
    return Container(
      key: const ValueKey<String>('battle-answer-result'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(105)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            correct ? Icons.check_rounded : Icons.close_rounded,
            color: color,
            size: compact ? 11 : 12,
          ),
          const SizedBox(width: 3),
          Text(
            correct ? 'BENAR' : 'SALAH',
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaNotice extends StatelessWidget {
  const _ArenaNotice({
    required super.key,
    required this.text,
    this.isError = false,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color color = isError
        ? const Color(0xFFF05E5E)
        : const Color(0xFF2878F0);
    return Center(
      child: Container(
        key: ValueKey<String>(
          isError ? 'battle-error-banner' : 'battle-status-banner',
        ),
        constraints: const BoxConstraints(maxWidth: 330),
        padding: const EdgeInsets.fromLTRB(10, 9, 13, 9),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withAlpha(18), Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(105)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color.alphaBlend(
                const Color(0xFF17233F).withAlpha(35),
                color,
              ),
              blurRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isError ? Icons.priority_high_rounded : Icons.bolt_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF17233F),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpponentReconnectBanner extends StatelessWidget {
  const _OpponentReconnectBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const ValueKey<String>('battle-opponent-reconnecting'),
        constraints: const BoxConstraints(maxWidth: 330),
        padding: const EdgeInsets.fromLTRB(10, 9, 13, 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFC857)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0xFFD99723),
              blurRadius: 0,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC857),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8A5600),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'MENUNGGU LAWAN',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF8A5600),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.45,
                    ),
                  ),
                  Text(
                    'Koneksi lawan terputus. Arena menunggu hingga 30 detik.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: _BattleClayPalette.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({
    required this.value,
    required this.round,
    this.resultMessage,
  });

  final int value;
  final int round;
  final String? resultMessage;

  @override
  Widget build(BuildContext context) {
    final bool ready = value == 0;
    final bool betweenRounds = resultMessage != null;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFF0D2A52).withAlpha(190),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              key: const ValueKey<String>('battle-round-overlay'),
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: _BattleClayPalette.cream,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2878F0).withAlpha(18),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFF2878F0).withAlpha(55),
                      ),
                    ),
                    child: Text(
                      betweenRounds ? 'RONDE SELESAI' : 'BERSIAP DI ARENA',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF1F62BF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (betweenRounds) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      resultMessage!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: _BattleClayPalette.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: _BattleClayPalette.ink.withAlpha(20),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    ready
                        ? 'Ronde $round dimulai!'
                        : 'Ronde $round dimulai dalam',
                    style: GoogleFonts.dmSans(
                      color: _BattleClayPalette.mutedInk,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: Container(
                      key: ValueKey<int>(value),
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ready
                            ? const Color(0xFFFFE9B0)
                            : const Color(0xFFDDEBFF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ready
                              ? const Color(0xFFFFC857)
                              : const Color(0xFF2878F0),
                          width: 3,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color:
                                (ready
                                        ? const Color(0xFFFFC857)
                                        : const Color(0xFF2878F0))
                                    .withAlpha(45),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        ready ? 'GO' : '$value',
                        style: GoogleFonts.fredoka(
                          color: ready
                              ? const Color(0xFF9A6200)
                              : const Color(0xFF1F62BF),
                          fontSize: ready ? 34 : 48,
                          fontWeight: FontWeight.w700,
                          height: 1,
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
  }
}

class _ClayArenaPainter extends CustomPainter {
  const _ClayArenaPainter(this.theme);

  final ArenaVisualTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..isAntiAlias = true;
    final double riverHeight = (size.height * 0.12).clamp(40, 54);
    final double riverTop = (size.height - riverHeight) / 2;

    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[theme.field, theme.fieldAccent],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = null;

    final RRect outerCourt = RRect.fromRectAndRadius(
      Rect.fromLTWH(9, 9, size.width - 18, size.height - 18),
      const Radius.circular(22),
    );
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withAlpha(
        theme.id == 'arena-lembah-bara' ? 10 : 30,
      );
    canvas.drawRRect(outerCourt, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = theme.boundary.withAlpha(180);
    canvas.drawRRect(outerCourt, paint);

    final RRect opponentCourt = RRect.fromRectAndRadius(
      Rect.fromLTWH(18, 18, size.width - 36, riverTop - 27),
      const Radius.circular(18),
    );
    final RRect playerCourt = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        18,
        riverTop + riverHeight + 9,
        size.width - 36,
        size.height - riverTop - riverHeight - 27,
      ),
      const Radius.circular(18),
    );
    paint.style = PaintingStyle.fill;
    paint.color = theme.opponentWash;
    canvas.drawRRect(opponentCourt, paint);
    paint.color = theme.playerWash;
    canvas.drawRRect(playerCourt, paint);

    _drawArenaMotif(canvas, size, paint, opponentCourt, playerCourt);

    paint.color = theme.riverEdge;
    canvas.drawRect(Rect.fromLTWH(0, riverTop - 5, size.width, 5), paint);
    canvas.drawRect(
      Rect.fromLTWH(0, riverTop + riverHeight, size.width, 5),
      paint,
    );

    paint.color = theme.river;
    canvas.drawRect(Rect.fromLTWH(0, riverTop, size.width, riverHeight), paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withAlpha(65);
    for (int index = 0; index < 3; index++) {
      final double y = riverTop + 8 + index * (riverHeight - 16) / 2;
      canvas.drawLine(
        Offset(size.width * 0.05, y),
        Offset(size.width * 0.30, y + 2),
        paint,
      );
      canvas.drawLine(
        Offset(size.width * 0.70, y - 1),
        Offset(size.width * 0.95, y + 1),
        paint,
      );
    }

    final Rect bridgeRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: (size.width * 0.34).clamp(104, 136),
      height: riverHeight + 14,
    );
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0x400D2A52);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bridgeRect.shift(const Offset(0, 5)),
        const Radius.circular(14),
      ),
      paint,
    );
    paint.color = theme.bridge;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bridgeRect, const Radius.circular(14)),
      paint,
    );
    paint.color = theme.bridgeLine;
    paint.strokeWidth = 2;
    for (int index = 1; index < 4; index++) {
      final double x = bridgeRect.left + bridgeRect.width * index / 4;
      canvas.drawLine(
        Offset(x, bridgeRect.top + 5),
        Offset(x, bridgeRect.bottom - 5),
        paint,
      );
    }

    paint.style = PaintingStyle.fill;
    for (final Offset center in <Offset>[
      Offset(8, size.height * 0.18),
      Offset(size.width - 8, size.height * 0.82),
    ]) {
      paint.color = const Color(0x380D2A52);
      canvas.drawCircle(center.translate(0, 3), 14, paint);
      paint.color = theme.boundary;
      canvas.drawCircle(center, 13, paint);
    }
  }

  void _drawArenaMotif(
    Canvas canvas,
    Size size,
    Paint paint,
    RRect opponentCourt,
    RRect playerCourt,
  ) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withAlpha(
        theme.id == 'arena-lembah-bara' ? 26 : 50,
      );
    if (theme.id == 'arena-lembah-bara') {
      for (final RRect court in <RRect>[opponentCourt, playerCourt]) {
        final double y = court.center.dy;
        canvas.drawLine(
          Offset(size.width * 0.16, y - 5),
          Offset(size.width * 0.84, y - 5),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.16, y + 5),
          Offset(size.width * 0.84, y + 5),
          paint,
        );
        for (int index = 0; index < 7; index++) {
          final double x = size.width * (0.20 + index * 0.10);
          canvas.drawLine(Offset(x, y - 8), Offset(x, y + 8), paint);
        }
      }
      return;
    }

    for (final RRect court in <RRect>[opponentCourt, playerCourt]) {
      final Rect document = Rect.fromCenter(
        center: court.center,
        width: 52,
        height: 34,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(document, const Radius.circular(5)),
        paint,
      );
      for (int index = 0; index < 3; index++) {
        final double y = document.top + 10 + index * 7;
        canvas.drawLine(
          Offset(document.left + 10, y),
          Offset(document.right - 10, y),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClayArenaPainter oldDelegate) {
    return oldDelegate.theme.id != theme.id;
  }
}

String _arenaTaxonomyKey(String? value) {
  return value
          ?.trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[\s-]+'), '_')
          .replaceAll(RegExp('_+'), '_') ??
      '';
}

List<String> _arenaDeckOrder(BattleTarget? target) {
  return switch (target) {
    BattleTarget.bumn => const <String>['wawasan_kebangsaan', 'tkd', 'akhlak'],
    BattleTarget.cpns || null => const <String>['twk', 'tiu', 'tkp'],
  };
}

String _arenaQuestionDeckKey(BattleQuestion question, BattleTarget? target) {
  final String topic = _arenaTaxonomyKey(question.subcategory);
  final String? topicDeck = switch (target) {
    BattleTarget.bumn => switch (topic) {
      'pancasila' ||
      'uud_1945' ||
      'nkri' ||
      'bhinneka_tunggal_ika' => 'wawasan_kebangsaan',
      'verbal' ||
      'kemampuan_verbal' ||
      'numerik' ||
      'kemampuan_numerik' ||
      'logis' ||
      'logika' ||
      'kemampuan_logis' ||
      'kemampuan_logika' ||
      'figural' ||
      'kemampuan_figural' => 'tkd',
      'amanah' || 'kompeten' || 'harmonis' || 'loyal' => 'akhlak',
      _ => null,
    },
    BattleTarget.cpns || null => switch (topic) {
      'pancasila_dan_ideologi' ||
      'pancasila_ideologi' ||
      'konstitusi_dan_negara' ||
      'konstitusi_negara' ||
      'sejarah_dan_kebangsaan' ||
      'sejarah_kebangsaan' ||
      'bhinneka_tunggal_ika' => 'twk',
      'verbal' ||
      'kemampuan_verbal' ||
      'numerik' ||
      'kemampuan_numerik' ||
      'logis' ||
      'logika' ||
      'kemampuan_logis' ||
      'kemampuan_logika' ||
      'figural' ||
      'kemampuan_figural' => 'tiu',
      'pelayanan_dan_integritas' ||
      'pelayanan_integritas' ||
      'kerja_sama_dan_komunikasi' ||
      'kerja_sama_komunikasi' ||
      'adaptasi_dan_pengembangan_diri' ||
      'adaptasi_pengembangan_diri' ||
      'pengambilan_keputusan_dan_kinerja' ||
      'pengambilan_keputusan_kinerja' => 'tkp',
      _ => null,
    },
  };
  if (topicDeck != null) return topicDeck;

  final String category = _arenaTaxonomyKey(question.category);
  return switch (target) {
    BattleTarget.bumn => switch (category) {
      'wk' || 'twk' => 'wawasan_kebangsaan',
      'tiu' => 'tkd',
      'akhlah' || 'core_values' => 'akhlak',
      _ => category,
    },
    BattleTarget.cpns || null => category,
  };
}

Color _arenaCategoryColor(
  String category,
  QuestionEffect effect, {
  String? subcategory,
}) {
  if (effect == QuestionEffect.heal) {
    return const Color(0xFF47CFA0);
  }
  final String topic = _arenaTaxonomyKey(subcategory);
  final String deck = _arenaTaxonomyKey(category);
  final Color? topicColor = deck == 'tiu' || deck == 'tkd'
      ? switch (topic) {
          'figural' || 'kemampuan_figural' => const Color(0xFF4CAF78),
          'verbal' || 'kemampuan_verbal' => const Color(0xFF8B6FE8),
          'logis' ||
          'logika' ||
          'kemampuan_logis' ||
          'kemampuan_logika' => const Color(0xFFFF9F43),
          'numerik' || 'kemampuan_numerik' => const Color(0xFF2878F0),
          _ => null,
        }
      : null;
  if (topicColor != null) return topicColor;

  return switch (deck) {
    'akhlak' || 'core_values' => const Color(0xFFD4A64D),
    'figural' => const Color(0xFF4CAF78),
    'verbal' => const Color(0xFF8B6FE8),
    'logis' || 'logika' => const Color(0xFFFF9F43),
    'tkp' || 'karakteristik_pribadi' => const Color(0xFFB878A3),
    'twk' || 'wk' || 'wawasan_kebangsaan' => const Color(0xFF47CFA0),
    'tkd' => const Color(0xFF2878F0),
    _ => const Color(0xFF2878F0),
  };
}

String _arenaCardAsset(
  String category,
  QuestionEffect effect, {
  String? subcategory,
}) {
  final String topic = _arenaTaxonomyKey(subcategory);
  final String deck = _arenaTaxonomyKey(category);
  final String? sharedTopicAsset = switch (topic) {
    'pancasila' ||
    'pancasila_dan_ideologi' ||
    'pancasila_ideologi' ||
    'uud_1945' ||
    'konstitusi_dan_negara' ||
    'konstitusi_negara' ||
    'nkri' ||
    'sejarah_dan_kebangsaan' ||
    'sejarah_kebangsaan' ||
    'bhinneka_tunggal_ika' => _twkCardAsset,
    'pelayanan_dan_integritas' ||
    'pelayanan_integritas' ||
    'kerja_sama_dan_komunikasi' ||
    'kerja_sama_komunikasi' ||
    'adaptasi_dan_pengembangan_diri' ||
    'adaptasi_pengembangan_diri' ||
    'pengambilan_keputusan_dan_kinerja' ||
    'pengambilan_keputusan_kinerja' => _tkpCardAsset,
    'amanah' || 'kompeten' || 'harmonis' || 'loyal' => _akhlakCardAsset,
    _ => null,
  };
  if (sharedTopicAsset != null) return sharedTopicAsset;

  return switch (deck) {
    'tiu' || 'tkd' => switch (topic) {
      'verbal' || 'kemampuan_verbal' => _verbalCardAsset,
      'logis' ||
      'logika' ||
      'kemampuan_logis' ||
      'kemampuan_logika' => _logikaCardAsset,
      'figural' || 'kemampuan_figural' => _figuralCardAsset,
      _ => _numerikCardAsset,
    },
    'akhlak' || 'akhlah' || 'core_values' => _akhlakCardAsset,
    'figural' => _figuralCardAsset,
    'verbal' => _verbalCardAsset,
    'logika' => _logikaCardAsset,
    'tkp' || 'karakteristik_pribadi' => _tkpCardAsset,
    'twk' || 'wk' || 'wawasan_kebangsaan' => _twkCardAsset,
    'tkd' => _numerikCardAsset,
    'tiu' || 'numerik' => _numerikCardAsset,
    _ => effect == QuestionEffect.heal ? _akhlakCardAsset : _numerikCardAsset,
  };
}

Color _battleEffectColor(BattleVisualEffect effect, String category) {
  return switch (effect) {
    BattleVisualEffect.heal => const Color(0xFF47CFA0),
    BattleVisualEffect.wizard => const Color(0xFF8B6FE8),
    BattleVisualEffect.robot => const Color(0xFFFF9F43),
    BattleVisualEffect.cannon => _arenaCategoryColor(
      category,
      QuestionEffect.damage,
    ),
  };
}

class _ArenaShakeWrapper extends StatelessWidget {
  const _ArenaShakeWrapper({
    required this.controller,
    required this.intensity,
    required this.child,
  });

  final AnimationController controller;
  final double intensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        final double progress = controller.value;
        if (progress == 0.0 || progress == 1.0) {
          return child;
        }
        final double decay = 1.0 - progress;
        final double dx = sin(progress * pi * 8) * 6.5 * intensity * decay;
        final double dy = cos(progress * pi * 6) * 4.5 * intensity * decay;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
    );
  }
}

class _HitFlashOverlay extends StatelessWidget {
  const _HitFlashOverlay({required this.animation});

  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double progress = animation.value;
        if (progress == 0.0 || progress == 1.0) {
          return const SizedBox.shrink();
        }
        final int alpha = ((1.0 - progress) * 96).clamp(0, 255).toInt();
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFFE74C3C).withAlpha(alpha),
          ),
        );
      },
    );
  }
}

class _LowHpVignetteOverlay extends StatelessWidget {
  const _LowHpVignetteOverlay({required this.animation});

  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double pulse = sin(animation.value * pi);
        final int alpha = (38 + (pulse * 56)).clamp(0, 255).toInt();
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE74C3C).withAlpha(alpha),
              width: 3.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFE74C3C).withAlpha((alpha * 0.7).toInt()),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
