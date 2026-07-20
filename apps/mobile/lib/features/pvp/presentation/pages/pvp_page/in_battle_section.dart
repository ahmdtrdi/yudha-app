part of '../pvp_page.dart';

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
  final Future<void> Function() onPause;
  final VoidCallback onBotAnswer;
  final Future<void> Function(BattleQuestion question) onPickQuestion;

  @override
  State<_InBattleSection> createState() => _InBattleSectionState();
}

class _InBattleSectionState extends State<_InBattleSection>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _effectController;
  final Random _random = Random();

  Timer? _countdownTimer;
  Timer? _botTimer;
  Timer? _noticeTimer;
  int _countdownValue = 3;
  bool _countdownDone = false;
  bool _interactionLocked = false;
  bool _pauseOpen = false;
  List<BattleQuestion> _hand = const <BattleQuestion>[];
  String? _selectedQuestionId;
  String? _notice;
  bool _noticeIsError = false;

  BattleActor? _effectActor;
  BattleVisualEffect? _effectKind;
  String _effectCategory = 'numerik';
  int _effectAmount = 0;
  bool _effectTargetsPlayer = false;
  bool _effectIsHeal = false;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _hand = widget.state.availableQuestions.take(4).toList();
    _notice = widget.state.errorMessage ?? widget.state.statusMessage;
    _noticeIsError = widget.state.errorMessage != null;
    _startCountdownTimer();
  }

  @override
  void didUpdateWidget(covariant _InBattleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildHand();

    final int playerDelta = widget.state.playerHp - oldWidget.state.playerHp;
    final int opponentDelta =
        widget.state.opponentHp - oldWidget.state.opponentHp;
    if (playerDelta != 0 || opponentDelta != 0) {
      _prepareBattleEffect(
        playerDelta: playerDelta,
        opponentDelta: opponentDelta,
      );
    }

    final String? newError = widget.state.errorMessage;
    final String? oldError = oldWidget.state.errorMessage;
    final String? newStatus = widget.state.statusMessage;
    final String? oldStatus = oldWidget.state.statusMessage;
    if (newError != null && newError != oldError) {
      _showNotice(newError, isError: true);
    } else if (newStatus != null && newStatus != oldStatus) {
      _showNotice(newStatus);
    }

    if (widget.state.phase != BattlePhase.inBattle ||
        widget.state.mode != BattleMode.bot ||
        widget.state.availableQuestions.isEmpty) {
      _cancelBotTimer();
    } else if (_canBotAct && !(_botTimer?.isActive ?? false)) {
      _scheduleBotAttack();
    }
  }

  bool get _canBotAct {
    return mounted &&
        _countdownDone &&
        !_pauseOpen &&
        widget.state.phase == BattlePhase.inBattle &&
        widget.state.mode == BattleMode.bot &&
        widget.state.availableQuestions.isNotEmpty;
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
        return;
      }

      timer.cancel();
      setState(() {
        _countdownDone = true;
      });
      _scheduleBotAttack();
    });
  }

  void _cancelBotTimer() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  void _scheduleBotAttack() {
    if (!_canBotAct || (_botTimer?.isActive ?? false)) {
      return;
    }

    final int delayMs = 4300 + _random.nextInt(1900);
    _botTimer = Timer(Duration(milliseconds: delayMs), () {
      _botTimer = null;
      if (!_canBotAct) {
        return;
      }
      widget.onBotAnswer();
    });
  }

  void _rebuildHand() {
    final Set<String> availableIds = widget.state.availableQuestions
        .map((BattleQuestion question) => question.id)
        .toSet();
    final List<BattleQuestion> nextHand = _hand
        .where((BattleQuestion question) => availableIds.contains(question.id))
        .take(4)
        .toList();
    final Set<String> retainedIds = nextHand
        .map((BattleQuestion question) => question.id)
        .toSet();

    for (final BattleQuestion question in widget.state.availableQuestions) {
      if (nextHand.length == 4) {
        break;
      }
      if (retainedIds.add(question.id)) {
        nextHand.add(question);
      }
    }
    _hand = nextHand;
  }

  void _prepareBattleEffect({
    required int playerDelta,
    required int opponentDelta,
  }) {
    final bool playerChanged = playerDelta != 0;
    final int delta = playerChanged ? playerDelta : opponentDelta;
    _effectAmount = delta.abs();
    _effectTargetsPlayer = playerChanged;
    _effectIsHeal = delta > 0;
    _effectActor =
        widget.state.lastActor ??
        (_effectIsHeal
            ? (_effectTargetsPlayer ? BattleActor.player : BattleActor.opponent)
            : (_effectTargetsPlayer
                  ? BattleActor.opponent
                  : BattleActor.player));
    _effectKind = _effectIsHeal
        ? BattleVisualEffect.heal
        : widget.state.lastVisualEffect ?? BattleVisualEffect.cannon;
    _effectCategory = widget.state.lastEventCategory ?? 'numerik';
    _effectController.forward(from: 0);
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

  Future<void> _handlePickQuestion(BattleQuestion question) async {
    if (!_countdownDone || _interactionLocked || _pauseOpen) {
      return;
    }

    setState(() {
      _interactionLocked = true;
      _selectedQuestionId = question.id;
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      await widget.onPickQuestion(question);
    } finally {
      if (mounted) {
        setState(() {
          _interactionLocked = false;
          _selectedQuestionId = null;
        });
        _scheduleBotAttack();
      }
    }
  }

  Future<void> _handlePause() async {
    if (_pauseOpen || _interactionLocked) {
      return;
    }
    _pauseOpen = true;
    _countdownTimer?.cancel();
    _cancelBotTimer();
    try {
      await widget.onPause();
    } finally {
      if (mounted) {
        _pauseOpen = false;
        if (!_countdownDone) {
          _startCountdownTimer();
        } else {
          _scheduleBotAttack();
        }
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _botTimer?.cancel();
    _noticeTimer?.cancel();
    _ambientController.dispose();
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxHeight < 700 || constraints.maxWidth < 380;

        return ColoredBox(
          color: const Color(0xFF0D2A52),
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  _BattleHud(
                    isOpponent: true,
                    name: widget.state.opponentName,
                    hp: widget.state.opponentHp,
                    points: widget.state.opponentPoints,
                    mode: widget.state.mode,
                    compact: compact,
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
                      child: _ArenaBoard(
                        playerHp: widget.state.playerHp,
                        opponentHp: widget.state.opponentHp,
                        compact: compact,
                        ambientAnimation: _ambientController,
                        effectAnimation: _effectController,
                        effectActor: _effectActor,
                        effectKind: _effectKind,
                        effectCategory: _effectCategory,
                        effectAmount: _effectAmount,
                        effectTargetsPlayer: _effectTargetsPlayer,
                        effectIsHeal: _effectIsHeal,
                      ),
                    ),
                  ),
                  _BattleHud(
                    isOpponent: false,
                    name: widget.playerDisplayName,
                    hp: widget.state.playerHp,
                    points: widget.state.playerPoints,
                    mode: widget.state.mode,
                    compact: compact,
                  ),
                  _BattleHand(
                    questions: _hand,
                    compact: compact,
                    enabled:
                        _countdownDone && !_interactionLocked && !_pauseOpen,
                    selectedQuestionId: _selectedQuestionId,
                    onPickQuestion: _handlePickQuestion,
                  ),
                ],
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
              if (!_countdownDone) _CountdownOverlay(value: _countdownValue),
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
    required this.name,
    required this.hp,
    required this.points,
    required this.mode,
    required this.compact,
    this.onPause,
  });

  final bool isOpponent;
  final String name;
  final int hp;
  final int points;
  final BattleMode mode;
  final bool compact;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final Color accent = isOpponent
        ? const Color(0xFFF05E5E)
        : const Color(0xFF2878F0);
    final String asset = isOpponent ? _enemyAvatarAsset : _playerAvatarAsset;
    final int safeHp = hp.clamp(0, 100).toInt();

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 58 : 66),
      padding: EdgeInsets.fromLTRB(10, compact ? 6 : 8, 10, compact ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        border: Border(
          bottom: isOpponent
              ? BorderSide(color: accent.withAlpha(75), width: 2)
              : BorderSide.none,
          top: isOpponent
              ? BorderSide.none
              : BorderSide(color: accent.withAlpha(75), width: 2),
        ),
      ),
      child: Row(
        children: <Widget>[
          _BattleAvatar(asset: asset, accent: accent, compact: compact),
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
                          color: const Color(0xFF17233F),
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
                          color: const Color(0xFF66708A),
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
                  foregroundColor: const Color(0xFF17233F),
                  backgroundColor: const Color(0xFFECE7DA),
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
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: 160,
          filterQuality: FilterQuality.medium,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: online ? const Color(0xFFE8F7F1) : const Color(0xFFE9F1FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF47CFA0) : const Color(0xFF2878F0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            online ? 'ONLINE' : 'BOT',
            style: GoogleFonts.dmSans(
              color: const Color(0xFF17233F),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: ColoredBox(color: Color(0xFFE5E1D7))),
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: value.clamp(0, 1)),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder:
                    (BuildContext context, double animated, Widget? child) {
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
      ),
    );
  }
}

class _ArenaBoard extends StatelessWidget {
  const _ArenaBoard({
    required this.playerHp,
    required this.opponentHp,
    required this.compact,
    required this.ambientAnimation,
    required this.effectAnimation,
    required this.effectActor,
    required this.effectKind,
    required this.effectCategory,
    required this.effectAmount,
    required this.effectTargetsPlayer,
    required this.effectIsHeal,
  });

  final int playerHp;
  final int opponentHp;
  final bool compact;
  final Animation<double> ambientAnimation;
  final Animation<double> effectAnimation;
  final BattleActor? effectActor;
  final BattleVisualEffect? effectKind;
  final String effectCategory;
  final int effectAmount;
  final bool effectTargetsPlayer;
  final bool effectIsHeal;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withAlpha(45),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                const Positioned.fill(
                  child: CustomPaint(painter: _ClayArenaPainter()),
                ),
                Positioned(
                  top: height * 0.35,
                  left: 7,
                  child: const _ArenaPropCluster(accent: Color(0xFFF05E5E)),
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
                  bottom: height * 0.35,
                  right: 7,
                  child: const _ArenaPropCluster(
                    accent: Color(0xFF2878F0),
                    mirrored: true,
                  ),
                ),
                Positioned(
                  top: -2,
                  left: (width - mainSize) / 2,
                  width: mainSize,
                  height: mainSize,
                  child: _TowerAsset(
                    asset: _enemyMainTowerAsset,
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
                    asset: _enemyMiniTowerAsset,
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
                    asset: _enemyMiniTowerAsset,
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
                    asset: _playerMiniTowerAsset,
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
                    asset: _playerMiniTowerAsset,
                    destroyed: playerHp <= 0,
                    ambientAnimation: ambientAnimation,
                  ),
                ),
                Positioned(
                  bottom: -2,
                  left: (width - mainSize) / 2,
                  width: mainSize,
                  height: mainSize,
                  child: _TowerAsset(
                    asset: _playerMainTowerAsset,
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

class _TowerAsset extends StatelessWidget {
  const _TowerAsset({
    required this.asset,
    required this.destroyed,
    required this.ambientAnimation,
  });

  final String asset;
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
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        cacheWidth: 320,
        filterQuality: FilterQuality.medium,
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
  });

  final Animation<double> animation;
  final BattleActor? actor;
  final BattleVisualEffect? kind;
  final String category;
  final int amount;
  final bool targetsPlayer;
  final bool isHeal;

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
              final double travel = Curves.easeInOutCubic.transform(raw);
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
              final double projectileAngle = switch (kind!) {
                BattleVisualEffect.cannon => direction * (0.18 + raw * 0.45),
                BattleVisualEffect.wizard => sin(raw * pi * 2) * 0.16,
                BattleVisualEffect.robot => direction * raw * pi * 2,
                BattleVisualEffect.heal => 0,
              };
              final bool showProjectile = !isHeal && raw < 0.82;
              final bool showImpact = isHeal || raw >= 0.68;
              final Color color = _battleEffectColor(kind!, category);

              return Stack(
                children: <Widget>[
                  if (showProjectile)
                    Positioned(
                      left: curved.dx - 28,
                      top: curved.dy - 23,
                      child: Transform.rotate(
                        angle: projectileAngle,
                        child: _EffectOrb(kind: kind!, color: color),
                      ),
                    ),
                  if (isHeal)
                    Positioned(
                      left: target.dx - 42,
                      top: target.dy - 42,
                      child: _HealBloom(progress: raw, color: color),
                    )
                  else if (showImpact)
                    Positioned(
                      left: target.dx - 35,
                      top: target.dy - 35,
                      child: Opacity(
                        opacity: (1 - ((raw - 0.68).clamp(0, 0.32) / 0.32))
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
                  if (raw >= 0.62)
                    Positioned(
                      left: target.dx - 38,
                      top: target.dy - 58 - ((raw - 0.62) * 32),
                      width: 76,
                      child: Opacity(
                        opacity: (1 - ((raw - 0.76).clamp(0, 0.24) / 0.24))
                            .clamp(0, 1),
                        child: Text(
                          '${isHeal ? '+' : '-'}$amount',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fredoka(
                            color: color,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            shadows: const <Shadow>[
                              Shadow(
                                color: Colors.white,
                                blurRadius: 2,
                                offset: Offset(0, 1),
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

class _EffectOrb extends StatelessWidget {
  const _EffectOrb({required this.kind, required this.color});

  final BattleVisualEffect kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      BattleVisualEffect.cannon => _NumerikBolt(color: color),
      BattleVisualEffect.wizard => _VerbalSpell(color: color),
      BattleVisualEffect.robot => _LogikaCore(color: color),
      BattleVisualEffect.heal => _HealSeed(color: color),
    };
  }
}

class _NumerikBolt extends StatelessWidget {
  const _NumerikBolt({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 42,
      child: Stack(
        alignment: Alignment.centerRight,
        children: <Widget>[
          Positioned(
            left: 1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC857).withAlpha(135),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 10,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: color.withAlpha(150),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: 39,
            height: 31,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF17233F).withAlpha(55),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFFFC857),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerbalSpell extends StatelessWidget {
  const _VerbalSpell({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 3,
            top: 5,
            child: Container(
              width: 39,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF17233F).withAlpha(55),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.format_quote_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const Positioned(
            right: 0,
            top: 0,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFFC857),
              size: 17,
            ),
          ),
          Positioned(
            right: 2,
            bottom: 1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color.withAlpha(145),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogikaCore extends StatelessWidget {
  const _LogikaCore({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ClipPath(
            clipper: const _HexagonClipper(),
            child: Container(
              width: 45,
              height: 45,
              color: color,
              alignment: Alignment.center,
              child: Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2D8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.extension_rounded, color: color, size: 21),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HexagonOutlinePainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealSeed extends StatelessWidget {
  const _HealSeed({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(7),
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 23),
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

class _HexagonClipper extends CustomClipper<Path> {
  const _HexagonClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.75, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.75, size.height)
      ..lineTo(size.width * 0.25, size.height)
      ..lineTo(0, size.height * 0.5)
      ..close();
  }

  @override
  bool shouldReclip(covariant _HexagonClipper oldClipper) => false;
}

class _HexagonOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path path = const _HexagonClipper()
        .getClip(size)
        .shift(const Offset(0, -1));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _HexagonOutlinePainter oldDelegate) => false;
}

class _BattleHand extends StatelessWidget {
  const _BattleHand({
    required this.questions,
    required this.compact,
    required this.enabled,
    required this.selectedQuestionId,
    required this.onPickQuestion,
  });

  final List<BattleQuestion> questions;
  final bool compact;
  final bool enabled;
  final String? selectedQuestionId;
  final ValueChanged<BattleQuestion> onPickQuestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8EC),
      padding: EdgeInsets.fromLTRB(8, compact ? 6 : 8, 8, compact ? 7 : 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Pilih kartu',
                style: GoogleFonts.fredoka(
                  color: const Color(0xFF17233F),
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                enabled ? 'Jawab untuk bergerak' : 'Bersiap di arena',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF66708A),
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 5 : 7),
          SizedBox(
            height: compact ? 96 : 114,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List<Widget>.generate(4, (int index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                    child: index < questions.length
                        ? _ArenaQuestionCard(
                            question: questions[index],
                            compact: compact,
                            enabled: enabled,
                            selected: selectedQuestionId == questions[index].id,
                            onTap: () => onPickQuestion(questions[index]),
                          )
                        : const _EmptyCardSlot(),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaQuestionCard extends StatelessWidget {
  const _ArenaQuestionCard({
    required this.question,
    required this.compact,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final BattleQuestion question;
  final bool compact;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _arenaCategoryColor(question.category, question.effect);
    final String asset = _arenaCardAsset(question.category, question.effect);
    final String label = _arenaCategoryLabel(question.category);
    final int power = question.weight.clamp(1, 4).toInt();
    final bool heal = question.effect == QuestionEffect.heal;

    return AnimatedScale(
      scale: selected ? 0.94 : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedOpacity(
        opacity: enabled || selected ? 1 : 0.58,
        duration: const Duration(milliseconds: 140),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('question-card-${question.id}'),
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: EdgeInsets.fromLTRB(5, compact ? 5 : 6, 5, 5),
              decoration: BoxDecoration(
                color: Color.alphaBlend(color.withAlpha(20), Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: selected ? 2.5 : 1.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF17233F).withAlpha(24),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF17233F),
                            fontSize: compact ? 8 : 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      _PowerPips(value: power, color: color),
                    ],
                  ),
                  Expanded(
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      cacheWidth: 144,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: compact ? 2 : 3),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      heal ? 'PULIHKAN' : 'SERANG',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: compact ? 7 : 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.25,
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

class _PowerPips extends StatelessWidget {
  const _PowerPips({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (int index) {
        return Container(
          width: 4,
          height: 4,
          margin: EdgeInsets.only(left: index == 0 ? 0 : 2),
          decoration: BoxDecoration(
            color: index < value.clamp(1, 3) ? color : color.withAlpha(40),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _EmptyCardSlot extends StatelessWidget {
  const _EmptyCardSlot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8D2C5)),
      ),
      child: const Center(
        child: Icon(Icons.hourglass_empty_rounded, color: Color(0xFF9AA1B2)),
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
        constraints: const BoxConstraints(maxWidth: 330),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(95)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF17233F).withAlpha(45),
              blurRadius: 9,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isError ? Icons.info_rounded : Icons.bolt_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF17233F),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final bool ready = value == 0;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFF0D2A52).withAlpha(205),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                ready ? 'Mulai!' : 'Bersiap',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withAlpha(205),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Text(
                  ready ? 'GO' : '$value',
                  key: ValueKey<int>(value),
                  style: GoogleFonts.fredoka(
                    color: ready ? const Color(0xFFFFC857) : Colors.white,
                    fontSize: ready ? 62 : 76,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClayArenaPainter extends CustomPainter {
  const _ClayArenaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..isAntiAlias = true;
    final double riverHeight = (size.height * 0.13).clamp(42, 58);
    final double riverTop = (size.height - riverHeight) / 2;

    paint.color = const Color(0xFF82D279);
    canvas.drawRect(Offset.zero & size, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.white.withAlpha(42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
        const Radius.circular(20),
      ),
      paint,
    );

    paint.style = PaintingStyle.fill;
    paint.color = const Color(0x2071B96A);
    for (final double xFactor in <double>[0.23, 0.77]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * xFactor, size.height / 2),
            width: (size.width * 0.18).clamp(48, 72),
            height: size.height * 0.82,
          ),
          const Radius.circular(28),
        ),
        paint,
      );
    }

    paint.color = const Color(0x222878F0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          10,
          size.height * 0.56,
          size.width - 20,
          size.height * 0.39,
        ),
        const Radius.circular(26),
      ),
      paint,
    );
    paint.color = const Color(0x22F05E5E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          10,
          size.height * 0.05,
          size.width - 20,
          size.height * 0.39,
        ),
        const Radius.circular(26),
      ),
      paint,
    );

    for (final double xFactor in <double>[0.23, 0.77]) {
      for (final double yFactor in <double>[0.30, 0.39, 0.61, 0.70]) {
        final Rect stone = Rect.fromCenter(
          center: Offset(size.width * xFactor, size.height * yFactor),
          width: (size.width * 0.075).clamp(22, 31),
          height: 9,
        );
        paint.color = const Color(0x28723934);
        canvas.drawOval(stone.shift(const Offset(0, 3)), paint);
        paint.color = const Color(0xFFFFE6B7);
        canvas.drawOval(stone, paint);
      }
    }

    paint.color = const Color(0xFF5FAF68);
    canvas.drawRect(Rect.fromLTWH(0, riverTop - 5, size.width, 5), paint);
    canvas.drawRect(
      Rect.fromLTWH(0, riverTop + riverHeight, size.width, 5),
      paint,
    );

    paint.color = const Color(0xFF72C8F1);
    canvas.drawRect(Rect.fromLTWH(0, riverTop, size.width, riverHeight), paint);
    paint.color = Colors.white.withAlpha(75);
    canvas.drawRect(Rect.fromLTWH(0, riverTop + 5, size.width, 3), paint);
    canvas.drawRect(
      Rect.fromLTWH(0, riverTop + riverHeight - 8, size.width, 3),
      paint,
    );

    final Rect bridgeRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: (size.width * 0.34).clamp(104, 136),
      height: riverHeight + 14,
    );
    paint.color = const Color(0x330D2A52);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bridgeRect.shift(const Offset(0, 5)),
        const Radius.circular(14),
      ),
      paint,
    );
    paint.color = const Color(0xFFFFE0A4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bridgeRect, const Radius.circular(14)),
      paint,
    );
    paint.color = const Color(0xFFD8A85A);
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
    for (int index = 0; index < 5; index++) {
      final double y = size.height * (0.10 + index * 0.20);
      final Rect leftStone = Rect.fromCenter(
        center: Offset(5, y),
        width: 24,
        height: (size.height * 0.055).clamp(22, 31),
      );
      final Rect rightStone = Rect.fromCenter(
        center: Offset(size.width - 5, y),
        width: 24,
        height: (size.height * 0.055).clamp(22, 31),
      );
      paint.color = const Color(0x33723934);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          leftStone.shift(const Offset(0, 3)),
          const Radius.circular(8),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rightStone.shift(const Offset(0, 3)),
          const Radius.circular(8),
        ),
        paint,
      );
      paint.color = const Color(0xFFFFD89A);
      canvas.drawRRect(
        RRect.fromRectAndRadius(leftStone, const Radius.circular(8)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rightStone, const Radius.circular(8)),
        paint,
      );
    }

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = Colors.white.withAlpha(45);
    canvas.drawLine(
      Offset(size.width * 0.17, size.height * 0.12),
      Offset(size.width * 0.17, riverTop - 8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.83, size.height * 0.12),
      Offset(size.width * 0.83, riverTop - 8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.17, riverTop + riverHeight + 8),
      Offset(size.width * 0.17, size.height * 0.88),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.83, riverTop + riverHeight + 8),
      Offset(size.width * 0.83, size.height * 0.88),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ClayArenaPainter oldDelegate) => false;
}

Color _arenaCategoryColor(String category, QuestionEffect effect) {
  if (effect == QuestionEffect.heal) {
    return const Color(0xFF47CFA0);
  }
  return switch (category.trim().toLowerCase()) {
    'verbal' => const Color(0xFF8B6FE8),
    'logika' => const Color(0xFFFF9F43),
    _ => const Color(0xFF2878F0),
  };
}

String _arenaCategoryLabel(String category) {
  return switch (category.trim().toLowerCase()) {
    'tiu' || 'numerik' => 'Numerik',
    'verbal' => 'Verbal',
    'logika' => 'Logika',
    'twk' => 'TWK',
    _ => 'Soal',
  };
}

String _arenaCardAsset(String category, QuestionEffect effect) {
  if (effect == QuestionEffect.heal) {
    return _twkCardAsset;
  }
  return switch (category.trim().toLowerCase()) {
    'verbal' => _verbalCardAsset,
    'logika' => _logikaCardAsset,
    _ => _numerikCardAsset,
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
