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
  List<BattleQuestion> _hand = const <BattleQuestion>[];
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _startCountdown();
    _hand = widget.state.availableQuestions.take(4).toList();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
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
    final String? newError = widget.state.errorMessage;
    if (widget.state.battleEventId != _lastToastEventId &&
        _countdownDone &&
        widget.state.battleEventId > 0) {
      _lastToastEventId = widget.state.battleEventId;

      final BattleActor? actor = widget.state.lastActor;
      final BattleVisualEffect? effect = widget.state.lastVisualEffect;

      if (newError != null) {
        _addToast(newError, isError: true);
      } else if (actor != null && effect != null) {
        // Contextual toast messages
        if (actor == BattleActor.opponent &&
            effect != BattleVisualEffect.heal) {
          // Enemy attacked us
          _addToast('Enemy attacking!', isError: true);
          _triggerShake();
        } else if (actor == BattleActor.player &&
            effect == BattleVisualEffect.heal) {
          // Player healed
          _addToast('Heal!');
        } else if (actor == BattleActor.player &&
            effect != BattleVisualEffect.heal) {
          // Player attacked correctly
          _addToast('Attack!');
        } else if (actor == BattleActor.opponent &&
            effect == BattleVisualEffect.heal) {
          // Opponent healed (player answered wrong on heal card)
          _addToast('Oh no', isError: true);
        }
      }
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

    // Rebuild hand: keep existing cards that are still available, fill gaps
    _rebuildHand();
  }

  void _rebuildHand() {
    final Set<String> availableIds = widget.state.availableQuestions
        .map((BattleQuestion q) => q.id)
        .toSet();

    // Keep cards that are still in the pool (same position)
    final List<BattleQuestion?> stable = _hand
        .map((BattleQuestion q) => availableIds.contains(q.id) ? q : null)
        .toList();

    // Collect IDs already in hand
    final Set<String> handIds = <String>{};
    for (final BattleQuestion? q in stable) {
      if (q != null) handIds.add(q.id);
    }

    // Get replacement cards from the pool (not already in hand)
    final Iterator<BattleQuestion> replacements = widget
        .state
        .availableQuestions
        .where((BattleQuestion q) => !handIds.contains(q.id))
        .iterator;

    final List<BattleQuestion> newHand = <BattleQuestion>[];
    for (int i = 0; i < 4; i++) {
      if (i < stable.length && stable[i] != null) {
        newHand.add(stable[i]!);
      } else if (replacements.moveNext()) {
        newHand.add(replacements.current);
      }
    }

    // If hand is still short, fill from pool
    while (newHand.length < 4 && replacements.moveNext()) {
      newHand.add(replacements.current);
    }

    _hand = newHand;
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _ambientController.dispose();
    _countdownController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
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
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (BuildContext context, Widget? shakeChild) {
        final double shakeOffset = _shakeController.isAnimating
            ? sin(_shakeController.value * pi * 6) *
                  (1 - _shakeController.value) *
                  6
            : 0;
        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: shakeChild,
        );
      },
      child: LayoutBuilder(
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
                          questions: _hand,
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
      ),
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

    return Container(
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
                      filterQuality: FilterQuality.low,
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

    for (final Offset wheel in const <Offset>[
      Offset(-17, 14),
      Offset(17, 14),
    ]) {
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
          ..color = const Color(
            0xFFFFD36A,
          ).withAlpha(_alpha(chargeT * opacity * 0.45))
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
      _drawWizardCaster(canvas, from, accent, castT, wizardOpacity);
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
        ..color = const Color(
          0xFFB7F4FF,
        ).withAlpha(_alpha(opacity * (0.45 + castT * 0.55)))
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
            ..color = const Color(
              0xFFFFE98A,
            ).withAlpha(_alpha(opacity * castT)),
        );
      }
    }
    canvas.restore();
  }

  void _drawLightning(
    Canvas canvas,
    Offset from,
    Offset to,
    double boltT,
    double fade,
  ) {
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
        final Offset end =
            to + Offset(cos(angle) * length, sin(angle) * length * 0.65);
        canvas.drawLine(
          to,
          end,
          Paint()
            ..color = const Color(
              0xFF7A2D12,
            ).withAlpha(_alpha((1 - slamT) * 0.65))
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
    final Paint dark = Paint()
      ..color = _darken(sideColor).withAlpha(_alpha(opacity));
    final Paint mid = Paint()..color = sideColor.withAlpha(_alpha(opacity));
    final Paint light = Paint()
      ..color = _lighten(sideColor).withAlpha(_alpha(opacity));

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
        ..color =
            (windupT > 0 || slamT > 0
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

    // â”€â”€ Screen flash on impact â”€â”€
    final double impactT = ((progress - 0.52) / 0.48).clamp(0.0, 1.0);
    if (impactT > 0 && impactT < 0.3) {
      final double flashOpacity = (1 - impactT / 0.3) * 0.15;
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = color.withAlpha((flashOpacity * 255).round()),
      );
    }

    // â”€â”€ Trail particles â”€â”€
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

    // â”€â”€ Projectile orb â”€â”€
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

    // â”€â”€ Impact: expanding shockwave rings â”€â”€
    if (impactT > 0) {
      final double impactFade = max(0, 1 - impactT);

      // Ring 1 â€” fast expanding
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

      // Ring 2 â€” slower
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

      // Ring 3 â€” slowest, widest
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

    // â”€â”€ Expanding heal rings â”€â”€
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

    // â”€â”€ Central glow â”€â”€
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

    // â”€â”€ Rising heal particles â”€â”€
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

    // â”€â”€ + symbol â”€â”€
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
    final double towerImageSize = mainTower ? 108 : 80;
    final double padWidth = mainTower ? 118 : 88;
    final double padHeight = mainTower ? 112 : 86;
    final double phase = (animationValue + animationDelay) * pi * 2;
    final double bob = destroyed ? 0 : sin(phase) * 3;
    final double sway = destroyed ? 0 : cos(phase * 0.7) * 1.5;
    final double pulse = destroyed ? 1.0 : 1.0 + sin(phase * 2) * 0.012;
    final Color hpColor = hpProgress <= 0.32
        ? const Color(0xFFEF4444)
        : hpProgress <= 0.64
        ? const Color(0xFFFFD23F)
        : const Color(0xFF25C67A);
    final bool isEnemy = alignment.y < 0;
    final Color teamColor = isEnemy
        ? const Color(0xFFFF4444)
        : const Color(0xFF4488FF);

    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(sway, bob),
        child: Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: padWidth,
            height: padHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                // Stone platform base (integrated with tower for perfect alignment)
                Positioned(
                  bottom: -4,
                  child: Container(
                    width: mainTower ? 108 : 80,
                    height: mainTower ? 48 : 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFFBEA882),
                          Color(0xFF9E8A68),
                          Color(0xFF7A6A4E),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF5C4E38),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withAlpha(80),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: teamColor.withAlpha(destroyed ? 8 : 30),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CustomPaint(
                        painter: _StonePadGridPainter(),
                      ),
                    ),
                  ),
                ),
                // Ground shadow ellipse
                Positioned(
                  bottom: -8,
                  child: Container(
                    width: mainTower ? 90 : 66,
                    height: mainTower ? 14 : 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: <Color>[
                          Colors.black.withAlpha(50),
                          Colors.black.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Tower image
                Center(
                  child: SizedBox(
                    width: towerImageSize,
                    height: towerImageSize,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return ScaleTransition(
                              scale: Tween<double>(begin: 0.86, end: 1)
                                  .animate(
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
                          filterQuality: FilterQuality.low,
                        ),
                      ),
                    ),
                  ),
                ),
                // HP bar (positioned below the tower image area)
                Positioned(
                  top: padHeight + 2,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          if (hpProgress <= 0.32 && !destroyed)
                            Container(
                              width: mainTower ? 82 : 62,
                              height: 11,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: hpColor.withAlpha(
                                      (80 + sin(phase * 4) * 40).round().clamp(0, 255),
                                    ),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
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
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: <Color>[
                                          hpColor,
                                          hpColor.withAlpha(200),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter for the stone grid pattern on tower platforms.
class _StonePadGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.black.withAlpha(22)
      ..strokeWidth = 0.8;
    for (double x = 0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // Subtle highlight on top edge
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, 0),
      Paint()..color = Colors.white.withAlpha(30)..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BattlefieldPainter extends CustomPainter {
  const _BattlefieldPainter({required this.time, required this.mode});

  final double time;
  final BattleMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect bounds = Offset.zero & size;
    final double tick = time * pi * 2;
    final double riverOff = time * 80;

    // ══════════════════════════════════════════
    // 1. GRASS – rich multi-tone base
    // ══════════════════════════════════════════
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF3D8526),
            Color(0xFF4B9B35),
            Color(0xFF479432),
            Color(0xFF3A7E24),
          ],
          stops: <double>[0, 0.35, 0.65, 1],
        ).createShader(bounds),
    );

    // Checker grass tiles
    const double tile = 26;
    final Paint tileA = Paint()..color = Colors.white.withAlpha(10);
    final Paint tileB = Paint()..color = Colors.black.withAlpha(8);
    for (double x = 0; x < w; x += tile) {
      for (double y = 0; y < h; y += tile) {
        final bool even = ((x / tile).floor() + (y / tile).floor()).isEven;
        canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), even ? tileA : tileB);
      }
    }

    // Subtle grass stripe rows for depth
    for (double y = 0; y < h; y += 52) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, w, 3),
        Paint()..color = Colors.black.withAlpha(6),
      );
    }

    // Cloud shadows
    _drawCloudShadow(canvas, size, 0.04, 0.18, 0.44, 0.09, 0.07, time);
    _drawCloudShadow(canvas, size, 0.52, 0.08, 0.36, 0.07, 0.05, time + 0.3);
    _drawCloudShadow(canvas, size, 0.26, 0.72, 0.50, 0.10, 0.06, time + 0.6);

    // ══════════════════════════════════════════
    // 2. LANES – cobblestone paths
    // ══════════════════════════════════════════
    final double laneW = (w * 0.22).clamp(92.0, 110.0).toDouble();
    final double midY = h * 0.46;
    const double crossH = 68;

    // Vertical main lane
    final Rect vLane = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: laneW,
      height: h,
    );
    canvas.drawRect(
      vLane,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const <Color>[
            Color(0xFFA88C56),
            Color(0xFFC4A866),
            Color(0xFFC4A866),
            Color(0xFFA88C56),
          ],
        ).createShader(vLane),
    );

    // Lane edge shadows
    canvas.drawRect(
      Rect.fromLTWH(w / 2 - laneW / 2, 0, 4, h),
      Paint()..color = Colors.black.withAlpha(28),
    );
    canvas.drawRect(
      Rect.fromLTWH(w / 2 + laneW / 2 - 4, 0, 4, h),
      Paint()..color = Colors.black.withAlpha(28),
    );
    // Lane edge highlight (inner)
    canvas.drawRect(
      Rect.fromLTWH(w / 2 - laneW / 2 + 4, 0, 2, h),
      Paint()..color = Colors.white.withAlpha(14),
    );
    canvas.drawRect(
      Rect.fromLTWH(w / 2 + laneW / 2 - 6, 0, 2, h),
      Paint()..color = Colors.white.withAlpha(14),
    );

    // Cobblestone pattern on vertical lane
    final Paint cobble = Paint()..color = Colors.black.withAlpha(12);
    for (double y = 0; y < h; y += 14) {
      final double xOff = ((y / 14).floor().isEven) ? 7 : 0;
      for (double x = vLane.left + xOff; x < vLane.right - 2; x += 14) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1, y + 1, 12, 12),
            const Radius.circular(2),
          ),
          cobble,
        );
      }
    }

    // Horizontal cross lane
    final Rect hLane = Rect.fromCenter(
      center: Offset(w / 2, midY),
      width: w,
      height: crossH,
    );
    canvas.drawRect(
      hLane,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[
            Color(0xFFA88C56),
            Color(0xFFC4A866),
            Color(0xFFC4A866),
            Color(0xFFA88C56),
          ],
        ).createShader(hLane),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, midY - crossH / 2, w, 4),
      Paint()..color = Colors.black.withAlpha(24),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, midY + crossH / 2 - 4, w, 4),
      Paint()..color = Colors.black.withAlpha(24),
    );

    // Cobblestone on horizontal lane
    for (double y = hLane.top; y < hLane.bottom - 2; y += 14) {
      final double xOff = ((y / 14).floor().isEven) ? 7 : 0;
      for (double x = xOff; x < w - 2; x += 14) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 1, y + 1, 12, 12),
            const Radius.circular(2),
          ),
          cobble,
        );
      }
    }

    // ══════════════════════════════════════════
    // 3. KING TOWER ZONE highlights
    // ══════════════════════════════════════════
    _drawKingZone(canvas, size, 0.5, 0.19, true);
    _drawKingZone(canvas, size, 0.5, 0.72, false);

    // ══════════════════════════════════════════
    // 4. RIVER
    // ══════════════════════════════════════════
    final double rivH = (h * 0.11).clamp(54.0, 78.0).toDouble();

    // River body path with wave edges
    final Path riverPath = Path();
    riverPath.moveTo(0, midY - rivH / 2);
    for (double x = 0; x <= w; x += 4) {
      riverPath.lineTo(
        x,
        midY - rivH / 2 + sin((x + riverOff) * 0.06) * 4,
      );
    }
    riverPath.lineTo(w, midY + rivH / 2);
    for (double x = w; x >= 0; x -= 4) {
      riverPath.lineTo(
        x,
        midY + rivH / 2 + sin((x + riverOff * 0.7) * 0.08) * 3,
      );
    }
    riverPath.close();

    // River shadow
    canvas.drawPath(
      riverPath.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withAlpha(35),
    );

    // River gradient fill
    final Rect riverRect = Rect.fromCenter(
      center: Offset(w / 2, midY),
      width: w,
      height: rivH + 20,
    );
    canvas.drawPath(
      riverPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0097B8),
            Color(0xFF10CCE8),
            Color(0xFF30E8FF),
            Color(0xFF10CCE8),
            Color(0xFF0097B8),
          ],
          stops: <double>[0, 0.2, 0.5, 0.8, 1],
        ).createShader(riverRect),
    );

    // River surface highlights – moving horizontal streaks
    for (int i = 0; i < 8; i++) {
      final double sx = ((i * w / 7 + riverOff * 2.5) % (w + 60)) - 30;
      final double sy = midY + sin(i * 1.7 + tick) * (rivH * 0.22);
      final double sw = 28 + sin(i * 2.1) * 10;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(sx, sy), width: sw, height: 2.5),
          const Radius.circular(2),
        ),
        Paint()
          ..color = Colors.white.withAlpha(
            (40 + sin(tick * 3 + i) * 18).round().clamp(0, 90),
          ),
      );
    }

    // Foam splashes
    final Paint foamPaint = Paint()..color = Colors.white.withAlpha(60);
    for (int i = 0; i < 5; i++) {
      final double cx = ((i * 90 + riverOff * 3.5) % (w + 60)) - 30;
      final double cy = midY + sin(i * 1.3) * (rivH * 0.18);
      final double p = 0.72 + sin(tick * 3 + i) * 0.16;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(-0.18);
      canvas.scale(p);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 36, height: 8),
        foamPaint,
      );
      canvas.restore();
    }

    // Shore edges
    final Paint shore = Paint()
      ..color = Colors.white.withAlpha(44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    Path edge = Path()..moveTo(0, midY - rivH / 2);
    for (double x = 0; x <= w; x += 3) {
      edge.lineTo(x, midY - rivH / 2 + sin((x + riverOff) * 0.06) * 4);
    }
    canvas.drawPath(edge, shore);
    edge = Path()..moveTo(0, midY + rivH / 2);
    for (double x = 0; x <= w; x += 3) {
      edge.lineTo(
        x,
        midY + rivH / 2 + sin((x + riverOff * 0.7) * 0.08) * 3,
      );
    }
    canvas.drawPath(edge, shore);

    // Shore glow (grass-water border light)
    final Paint shoreGlow = Paint()
      ..color = const Color(0xFF60E8FF).withAlpha(20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(
      Rect.fromLTWH(0, midY - rivH / 2 - 6, w, 8),
      shoreGlow,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, midY + rivH / 2 - 2, w, 8),
      shoreGlow,
    );

    // ══════════════════════════════════════════
    // 5. WOODEN BRIDGE
    // ══════════════════════════════════════════
    _drawWoodenBridge(canvas, w / 2, midY, laneW, rivH, tick);

    // ══════════════════════════════════════════
    // 6. TORCHES
    // ══════════════════════════════════════════
    final double flicker = 0.86 + 0.14 * sin(tick * 12 + 1);
    _drawTorch(canvas, 10, midY - rivH / 2 - 32, flicker);
    _drawTorch(canvas, 10, midY + rivH / 2 + 32, flicker * 0.92);
    _drawTorch(canvas, w - 10, midY - rivH / 2 - 32, flicker * 0.96);
    _drawTorch(canvas, w - 10, midY + rivH / 2 + 32, flicker);

    // ══════════════════════════════════════════
    // 7. DECORATIONS
    // ══════════════════════════════════════════
    _drawSideTrees(canvas, size, time);
    _drawBushes(canvas, size, time);

    // ══════════════════════════════════════════
    // 8. AMBIENT SPARKS
    // ══════════════════════════════════════════
    _drawAmbientSpark(canvas, size, 0.18, 0.82, time, const Color(0xFF7DD3FC));
    _drawAmbientSpark(
      canvas, size, 0.82, 0.23, time + 0.35, const Color(0xFFFCD34D),
    );
    _drawAmbientSpark(
      canvas, size, 0.52, 0.50, time + 0.62, const Color(0xFF86EFAC),
    );
    _drawAmbientSpark(
      canvas, size, 0.30, 0.12, time + 0.15, const Color(0xFFFCA5A5),
    );
    _drawAmbientSpark(
      canvas, size, 0.72, 0.88, time + 0.78, const Color(0xFFA5B4FC),
    );

    if (mode == BattleMode.online) {
      _drawModeBadge(canvas, size);
    }
  }

  // ──────────────────────────────────────────
  // Helper painters
  // ──────────────────────────────────────────

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
    final double cw = size.width * wRatio;
    final double ch = size.height * hRatio;
    final double x =
        ((size.width * xRatio + phase * 38) % (size.width + cw)) - cw;
    final double y = size.height * yRatio;
    final Rect rect = Rect.fromCenter(
      center: Offset(x + cw / 2, y + ch / 2),
      width: cw,
      height: ch,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.black.withAlpha((alpha * 255).round()),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  void _drawKingZone(
    Canvas canvas,
    Size size,
    double xR,
    double yR,
    bool isEnemy,
  ) {
    final Offset c = Offset(size.width * xR, size.height * yR);
    final Color zone =
        isEnemy ? const Color(0xFFBB3333) : const Color(0xFF3366BB);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 140, height: 80),
      Paint()
        ..color = zone.withAlpha(14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
  }

  void _drawWoodenBridge(
    Canvas canvas,
    double cx,
    double cy,
    double laneW,
    double rivH,
    double tick,
  ) {
    final double bw = laneW + 10;
    final double bh = rivH + 16;

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 4), width: bw, height: bh),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black.withAlpha(45),
    );

    // Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: bw, height: bh),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF5A3E12),
    );

    // Planks
    final double pTop = cy - bh / 2 + 3;
    final double pBot = cy + bh / 2 - 3;
    final Paint plankA = Paint()..color = const Color(0xFF8B6914);
    final Paint plankB = Paint()..color = const Color(0xFF6E5410);
    int idx = 0;
    for (double y = pTop; y < pBot; y += 7) {
      canvas.drawRect(
        Rect.fromLTWH(cx - bw / 2 + 4, y, bw - 8, 5),
        idx.isEven ? plankA : plankB,
      );
      // Plank gap
      canvas.drawRect(
        Rect.fromLTWH(cx - bw / 2 + 4, y + 5, bw - 8, 1.5),
        Paint()..color = const Color(0xFF3E2A0A),
      );
      idx++;
    }

    // Side rails
    final Paint railPaint = Paint()..color = const Color(0xFF4E3510);
    canvas.drawRect(
      Rect.fromLTWH(cx - bw / 2, cy - bh / 2, 4, bh),
      railPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx + bw / 2 - 4, cy - bh / 2, 4, bh),
      railPaint,
    );

    // Rail posts with lanterns
    final Paint postPaint = Paint()..color = const Color(0xFF8B6914);
    for (final double yOff in <double>[-bh / 2 + 3, 0, bh / 2 - 3]) {
      for (final double side in <double>[-1, 1]) {
        canvas.drawCircle(
          Offset(cx + side * bw / 2, cy + yOff),
          4.5,
          postPaint,
        );
        canvas.drawCircle(
          Offset(cx + side * bw / 2, cy + yOff),
          2.5,
          Paint()..color = const Color(0xFFAA8420),
        );
      }
    }

    // Lantern glow on top posts
    final double glow = 1 + 0.12 * sin(tick * 2.5);
    for (final double side in <double>[-1, 1]) {
      canvas.drawCircle(
        Offset(cx + side * bw / 2, cy - bh / 2 + 3),
        7 * glow,
        Paint()
          ..color = const Color(0xFFFFAA00).withAlpha(55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(cx + side * bw / 2, cy - bh / 2 + 3),
        3 * glow,
        Paint()..color = const Color(0xFFFFCC44).withAlpha(160),
      );
    }
  }

  void _drawTorch(Canvas canvas, double x, double y, double flicker) {
    // Torch pole
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y + 10), width: 3, height: 14),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF6B4520),
    );
    // Flame glow
    canvas.drawCircle(
      Offset(x, y),
      18 * flicker,
      Paint()
        ..color = const Color(0xFFFFAA00).withAlpha(40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Flame core
    canvas.drawCircle(
      Offset(x, y),
      5 * flicker,
      Paint()..color = const Color(0xFFFFBB22).withAlpha(230),
    );
    canvas.drawCircle(
      Offset(x, y - 2),
      3 * flicker,
      Paint()..color = const Color(0xFFFFF4CC).withAlpha(200),
    );
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
        trees =
        <({double x, double y, double scale, Color dark, Color mid})>[
      (
        x: 0.02,
        y: 0.14,
        scale: 0.9,
        dark: const Color(0xFF14532D),
        mid: const Color(0xFF2F8D3A),
      ),
      (
        x: 0.02,
        y: 0.36,
        scale: 0.82,
        dark: const Color(0xFF166534),
        mid: const Color(0xFF3CA44A),
      ),
      (
        x: 0.02,
        y: 0.78,
        scale: 0.94,
        dark: const Color(0xFF14532D),
        mid: const Color(0xFF2F8D3A),
      ),
      (
        x: 0.98,
        y: 0.14,
        scale: 0.84,
        dark: const Color(0xFF14532D),
        mid: const Color(0xFF35A047),
      ),
      (
        x: 0.98,
        y: 0.38,
        scale: 0.96,
        dark: const Color(0xFF166534),
        mid: const Color(0xFF3CA44A),
      ),
      (
        x: 0.98,
        y: 0.78,
        scale: 0.88,
        dark: const Color(0xFF14532D),
        mid: const Color(0xFF2F8D3A),
      ),
    ];

    for (int i = 0; i < trees.length; i++) {
      final tree = trees[i];
      final double sway = sin(time * pi * 2 + i * 1.4) * 2;
      final Offset base = Offset(size.width * tree.x, size.height * tree.y);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.scale(tree.scale);

      // Trunk shadow
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 22), width: 18, height: 6),
        Paint()..color = Colors.black.withAlpha(20),
      );
      // Trunk
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, 2, 6, 20),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF6B3F1D),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-1, 4, 2, 16),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF7D4E26),
      );

      canvas.translate(sway, 0);
      // Foliage layers
      canvas.drawCircle(Offset.zero, 14, Paint()..color = tree.dark);
      canvas.drawCircle(
        const Offset(-4, -3),
        10,
        Paint()..color = tree.mid,
      );
      canvas.drawCircle(
        const Offset(4, -6),
        9,
        Paint()..color = tree.mid,
      );
      canvas.drawCircle(
        const Offset(0, -10),
        8,
        Paint()..color = const Color(0xFF4FBB50),
      );
      canvas.drawCircle(
        const Offset(0, -16),
        6,
        Paint()..color = const Color(0xFF62D462),
      );
      // Light dapple
      canvas.drawCircle(
        const Offset(-3, -8),
        3,
        Paint()..color = Colors.white.withAlpha(16),
      );

      canvas.restore();
    }
  }

  void _drawBushes(Canvas canvas, Size size, double time) {
    const List<(double, double, double)> bushData = <(double, double, double)>[
      (0.07, 0.56, 0.85),
      (0.93, 0.56, 0.75),
      (0.07, 0.28, 0.7),
      (0.93, 0.28, 0.8),
      (0.04, 0.92, 0.65),
      (0.96, 0.08, 0.6),
      (0.04, 0.64, 0.55),
      (0.96, 0.64, 0.6),
    ];

    for (int i = 0; i < bushData.length; i++) {
      final (double bx, double by, double bs) = bushData[i];
      final Offset center = Offset(size.width * bx, size.height * by);
      final double sway = sin(time * pi * 2 + i * 1.2) * 1.0;

      canvas.save();
      canvas.translate(center.dx + sway, center.dy);
      canvas.scale(bs);

      // Shadow
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 7), width: 18, height: 5),
        Paint()..color = Colors.black.withAlpha(16),
      );
      // Bush body
      canvas.drawCircle(
        Offset.zero,
        7,
        Paint()..color = const Color(0xFF2D7A2D),
      );
      canvas.drawCircle(
        const Offset(-4, -1),
        5,
        Paint()..color = const Color(0xFF35912A),
      );
      canvas.drawCircle(
        const Offset(4, -1),
        5,
        Paint()..color = const Color(0xFF35912A),
      );
      canvas.drawCircle(
        const Offset(0, -4),
        4,
        Paint()..color = const Color(0xFF4AAA3A),
      );
      // Highlight
      canvas.drawCircle(
        const Offset(-2, -3),
        2,
        Paint()..color = Colors.white.withAlpha(14),
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
