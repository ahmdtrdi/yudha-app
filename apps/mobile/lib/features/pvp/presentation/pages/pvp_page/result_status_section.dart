part of '../pvp_page.dart';

class _ResultSection extends StatefulWidget {
  const _ResultSection({
    required this.state,
    required this.soundEnabled,
    required this.hapticsEnabled,
    required this.onClaimReward,
    required this.onPractice,
    required this.onReplay,
    required this.onReset,
    required this.playerDisplayName,
  });

  static const Color _ink = Color(0xFF17233F);
  static const Color _mutedInk = Color(0xFF66708A);
  static const Color _warmCanvas = Color(0xFFFFF8EC);
  static const Color _playerBlue = Color(0xFF2878F0);
  static const Color _rivalCoral = Color(0xFFF05E5E);

  final BattleState state;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final VoidCallback onClaimReward;
  final ValueChanged<String> onPractice;
  final VoidCallback onReplay;
  final VoidCallback onReset;
  final String playerDisplayName;

  @override
  State<_ResultSection> createState() => _ResultSectionState();
}

class _ResultSectionState extends State<_ResultSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final ArenaAudioController _sfx = ArenaAudioController.sfxOnly(
    enabled: widget.soundEnabled,
  );
  final List<_ConfettiParticle> _particles = <_ConfettiParticle>[];
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    final GameHaptics haptics = GameHaptics(widget.hapticsEnabled);
    switch (widget.state.outcome) {
      case BattleOutcome.win:
        _initConfetti();
        _confettiController.forward();
        haptics.medium();
        _hapticTimer = Timer(const Duration(milliseconds: 160), () {
          if (mounted) haptics.medium();
        });
        _sfx.playVictoryStinger();
      case BattleOutcome.lose:
        haptics.heavy();
        _sfx.playDefeatStinger();
      case BattleOutcome.inProgress || BattleOutcome.draw:
        break;
    }
  }

  void _initConfetti() {
    final Random random = Random();
    final List<Color> colors = <Color>[
      const Color(0xFFFFC857),
      const Color(0xFFFF9F1C),
      const Color(0xFF2878F0),
      const Color(0xFF2FAE7D),
      const Color(0xFF8B6FE8),
      const Color(0xFFFF5964),
    ];

    _particles.clear();
    for (int i = 0; i < 45; i++) {
      _particles.add(
        _ConfettiParticle(
          x: 0.15 + random.nextDouble() * 0.7,
          y: -0.1 - random.nextDouble() * 0.3,
          vx: (random.nextDouble() - 0.5) * 0.6,
          vy: 0.4 + random.nextDouble() * 0.6,
          size: 6.0 + random.nextDouble() * 8.0,
          color: colors[random.nextInt(colors.length)],
          rotation: random.nextDouble() * pi * 2,
          vRotation: (random.nextDouble() - 0.5) * 6.0,
          shape: random.nextInt(3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    unawaited(_sfx.dispose());
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BattleState state = widget.state;
    final bool isVictory = state.outcome == BattleOutcome.win;
    final bool isDefeat = state.outcome == BattleOutcome.lose;
    final Color accent = isVictory
        ? const Color(0xFFFFC857)
        : isDefeat
        ? _ResultSection._rivalCoral
        : const Color(0xFF8B6FE8);
    final Color titleColor = isVictory
        ? const Color(0xFF9A6200)
        : isDefeat
        ? const Color(0xFFB83F45)
        : const Color(0xFF6249B8);
    final String title = switch (state.outcome) {
      BattleOutcome.win => 'VICTORY!',
      BattleOutcome.lose => 'KALAH',
      BattleOutcome.draw || _ => 'SERI',
    };
    final String subtitle = switch (state.outcome) {
      BattleOutcome.win => 'Serangan terakhirmu menutup pertandingan.',
      BattleOutcome.lose => 'Arena selesai. Coba susun kartu baru.',
      BattleOutcome.draw || _ => 'Skor imbang, pertahanan sama kuat.',
    };
    final String ratingText = state.ratingDelta > 0
        ? '+${state.ratingDelta}'
        : '${state.ratingDelta}';
    final NavigatorState navigator = Navigator.of(context);
    final bool canGoBack = navigator.canPop();
    final BattlePerformanceInsight? insight = BattlePerformanceAnalyzer.analyze(
      state.answerHistory,
    );

    return ColoredBox(
      color: _ResultSection._warmCanvas,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxHeight < 700;
                final double badgeSize = compact ? 76 : 84;
                final double verticalPadding = compact ? 20 : 28;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    compact ? 10 : 14,
                    16,
                    compact ? 10 : 14,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        minHeight: max(
                          0.0,
                          constraints.maxHeight - verticalPadding,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Column(
                            children: <Widget>[
                              _ResultHero(
                                key: const ValueKey<String>(
                                  'battle-result-hero',
                                ),
                                accent: accent,
                                titleColor: titleColor,
                                title: title,
                                subtitle: subtitle,
                                modeLabel: _resultModeLabel(state),
                                victory: isVictory,
                                defeat: isDefeat,
                                badgeSize: badgeSize,
                                compact: compact,
                              ),
                              SizedBox(height: compact ? 10 : 12),
                              _ScoreCard(
                                state: state,
                                playerDisplayName: widget.playerDisplayName,
                                compact: compact,
                              ),
                              SizedBox(height: compact ? 8 : 10),
                              if (insight != null)
                                _PerformanceInsightCard(
                                  insight: insight,
                                  compact: compact,
                                  onPractice: () => widget.onPractice(
                                    insight.weakestCategory.category,
                                  ),
                                )
                              else
                                _EmptyPerformanceInsightCard(compact: compact),
                              SizedBox(height: compact ? 8 : 10),
                              _RewardCard(
                                ratingText: ratingText,
                                coinsDelta: state.coinsDelta,
                                isRanked:
                                    state.mode == BattleMode.online &&
                                    state.onlineMatchmakingMode ==
                                        OnlineMatchmakingMode.ranked,
                                claimed: state.rewardClaimed,
                                accent: accent,
                                compact: compact,
                              ),
                            ],
                          ),
                          Column(
                            children: <Widget>[
                              SizedBox(height: compact ? 10 : 14),
                              if (!state.rewardClaimed) ...<Widget>[
                                _ResultClayAction(
                                  key: const ValueKey<String>(
                                    'battle-result-primary-action',
                                  ),
                                  onPressed: widget.onClaimReward,
                                  icon: Icons.redeem_rounded,
                                  label: 'Klaim hadiah',
                                ),
                                const SizedBox(height: 10),
                              ],
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _ResultSecondaryAction(
                                      onPressed: widget.onReplay,
                                      icon: Icons.replay_rounded,
                                      label: 'Main lagi',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ResultSecondaryAction(
                                      onPressed: widget.onReset,
                                      icon: Icons.grid_view_rounded,
                                      label: 'Pilih mode',
                                    ),
                                  ),
                                ],
                              ),
                              if (canGoBack) ...<Widget>[
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: () {
                                    widget.onReset();
                                    navigator.maybePop();
                                  },
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('Kembali ke lobby'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _ResultSection._mutedInk,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (isVictory)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _confettiController.value,
                        particles: _particles,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _resultModeLabel(BattleState state) {
  if (state.mode != BattleMode.online) {
    return 'LATIHAN BOT';
  }
  return switch (state.onlineMatchmakingMode) {
    OnlineMatchmakingMode.ranked => 'RANKED MATCH',
    OnlineMatchmakingMode.casual => 'PLAYER MATCH',
    OnlineMatchmakingMode.privateRoom => 'PRIVATE ROOM',
    OnlineMatchmakingMode.bot => 'LATIHAN BOT',
  };
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({
    required super.key,
    required this.accent,
    required this.titleColor,
    required this.title,
    required this.subtitle,
    required this.modeLabel,
    required this.victory,
    required this.defeat,
    required this.badgeSize,
    required this.compact,
  });

  final Color accent;
  final Color titleColor;
  final String title;
  final String subtitle;
  final String modeLabel;
  final bool victory;
  final bool defeat;
  final double badgeSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color surface = Color.alphaBlend(accent.withAlpha(24), Colors.white);
    final Color clayEdge = Color.alphaBlend(
      const Color(0xFF17233F).withAlpha(42),
      accent,
    );

    return Container(
      key: const ValueKey<String>('battle-result-hero-surface'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, compact ? 13 : 16, 18, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withAlpha(72)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: clayEdge.withAlpha(150),
            blurRadius: 0,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(185),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: accent.withAlpha(55)),
            ),
            child: Text(
              modeLabel,
              style: GoogleFonts.dmSans(
                color: titleColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          SizedBox(height: compact ? 7 : 9),
          _ResultBadge(
            accent: accent,
            victory: victory,
            defeat: defeat,
            size: badgeSize,
          ),
          SizedBox(height: compact ? 7 : 9),
          Text(
            title,
            key: const ValueKey<String>('battle-result-title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: titleColor,
              fontSize: compact ? 30 : 33,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _ResultSection._mutedInk,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultClayAction extends StatelessWidget {
  const _ResultClayAction({
    required super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD7A3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC27A)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xFFF39A61),
            blurRadius: 0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: const Color(0xFFB85C21), size: 21),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFB85C21),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSecondaryAction extends StatelessWidget {
  const _ResultSecondaryAction({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ResultSection._ink,
          backgroundColor: Colors.white.withAlpha(125),
          side: BorderSide(color: _ResultSection._ink.withAlpha(38)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        label: Text(
          label,
          maxLines: 1,
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.vRotation,
    required this.shape,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final Color color;
  final double rotation;
  final double vRotation;
  final int shape; // 0: rect, 1: circle, 2: star/strip
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress >= 1.0) return;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    final double fade = (1.0 - progress).clamp(0.0, 1.0);

    for (final _ConfettiParticle p in particles) {
      final double curX = (p.x + p.vx * progress) * size.width;
      final double curY =
          (p.y + p.vy * progress * 1.5 + (0.5 * 1.2 * progress * progress)) *
          size.height;
      if (curY < 0 || curY > size.height) continue;

      paint.color = p.color.withAlpha((fade * 255).round().clamp(0, 255));
      final double curRot = p.rotation + p.vRotation * progress;

      canvas.save();
      canvas.translate(curX, curY);
      canvas.rotate(curRot);

      if (p.shape == 0) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          paint,
        );
      } else if (p.shape == 1) {
        canvas.drawCircle(Offset.zero, p.size * 0.35, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 1.2,
              height: p.size * 0.35,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _PerformanceInsightCard extends StatelessWidget {
  const _PerformanceInsightCard({
    required this.insight,
    required this.compact,
    required this.onPractice,
  });

  final BattlePerformanceInsight insight;
  final bool compact;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final BattleCategoryPerformance category = insight.weakestCategory;
    final BattleMissedCard? missedCard = insight.mostMissedCard;
    final String categoryLabel = _performanceCategoryLabel(category.category);
    final bool flawless = category.incorrectAnswers == 0;

    return Container(
      key: const ValueKey<String>('battle-performance-insight'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2878F0).withAlpha(34)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFD9DEE7),
            blurRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF2878F0).withAlpha(18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF2878F0),
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      flawless
                          ? 'Pertahankan performamu'
                          : 'Fokus latihan berikutnya',
                      style: GoogleFonts.fredoka(
                        color: _ResultSection._ink,
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$categoryLabel · ${category.correctAnswers} dari '
                      '${category.totalAnswers} benar',
                      style: GoogleFonts.dmSans(
                        color: _ResultSection._mutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (flawless
                              ? const Color(0xFF2FAE7D)
                              : const Color(0xFFF05E5E))
                          .withAlpha(18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${category.accuracyPercent}%',
                  style: GoogleFonts.dmSans(
                    color: flawless
                        ? const Color(0xFF21845F)
                        : const Color(0xFFB83F45),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (missedCard != null) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'KARTU PALING SERING SALAH · '
                    '${missedCard.incorrectAnswers}×',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFB83F45),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _ExpandableResultQuestion(prompt: missedCard.prompt),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('practice-weakest-category'),
              onPressed: onPractice,
              icon: const Icon(Icons.fitness_center_rounded, size: 16),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D2A52),
                side: const BorderSide(color: Color(0xFF2878F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: Text(
                'Latihan $categoryLabel',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableResultQuestion extends StatefulWidget {
  const _ExpandableResultQuestion({required this.prompt});

  final String prompt;

  @override
  State<_ExpandableResultQuestion> createState() =>
      _ExpandableResultQuestionState();
}

class _ExpandableResultQuestionState extends State<_ExpandableResultQuestion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = GoogleFonts.dmSans(
      color: _ResultSection._ink,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.35,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.prompt, style: style),
          textDirection: Directionality.of(context),
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth);
        final bool canExpand = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.prompt,
              maxLines: _expanded ? null : 2,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: style,
            ),
            if (canExpand) ...<Widget>[
              const SizedBox(height: 3),
              InkWell(
                key: const ValueKey<String>('result-question-expand'),
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _expanded ? 'Ringkas' : 'Lihat lengkap',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF2878F0),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyPerformanceInsightCard extends StatelessWidget {
  const _EmptyPerformanceInsightCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('battle-performance-insight'),
      width: double.infinity,
      constraints: BoxConstraints(minHeight: compact ? 82 : 96),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 14 : 17,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2878F0).withAlpha(34)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xFFD9DEE7),
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              color: const Color(0xFF2878F0).withAlpha(18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: Color(0xFF2878F0),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Fokus latihan berikutnya',
                  style: GoogleFonts.fredoka(
                    color: _ResultSection._ink,
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Belum ada jawaban untuk dianalisis. Jawab minimal satu '
                  'kartu agar rekomendasi latihan muncul.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ResultSection._mutedInk,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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

String _performanceCategoryLabel(String category) {
  final String normalized = category.trim().toLowerCase();
  return switch (normalized) {
    'numerik' => 'Numerik',
    'verbal' => 'Verbal',
    'logika' => 'Logika',
    'tkd' => 'TKD',
    'tiu' => 'TIU',
    'twk' => 'TWK',
    'tkp' => 'TKP',
    'akhlak' => 'AKHLAK',
    'wawasan_kebangsaan' || 'wawasan kebangsaan' => 'Wawasan Kebangsaan',
    'uud_1945' || 'uud 1945' => 'UUD 1945',
    'nkri' => 'NKRI',
    _ when normalized.isNotEmpty =>
      normalized
          .split(RegExp(r'[_\s]+'))
          .where((String word) => word.isNotEmpty)
          .map((String word) => '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' '),
    _ => 'Kategori soal',
  };
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
        ? Icons.emoji_events_rounded
        : defeat
        ? Icons.shield_rounded
        : Icons.handshake_rounded;
    final String semanticsLabel = victory
        ? 'Trofi kemenangan'
        : defeat
        ? 'Perisai pertandingan berakhir'
        : 'Pertandingan seri';

    return Semantics(
      image: true,
      label: semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              left: size * 0.04,
              top: size * 0.17,
              child: _ResultDot(color: accent, size: size * 0.12),
            ),
            Positioned(
              right: size * 0.02,
              bottom: size * 0.13,
              child: _ResultDot(color: accent, size: size * 0.08),
            ),
            Container(
              width: size * 0.78,
              height: size * 0.76,
              decoration: BoxDecoration(
                color: accent.withAlpha(38),
                borderRadius: BorderRadius.circular(size * 0.28),
                border: Border.all(color: accent.withAlpha(95), width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF17233F).withAlpha(24),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Icon(icon, color: accent, size: size * 0.43),
                  if (defeat)
                    Positioned(
                      right: size * 0.17,
                      bottom: size * 0.16,
                      child: Container(
                        width: size * 0.25,
                        height: size * 0.25,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8EC),
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 2),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: accent,
                          size: size * 0.16,
                        ),
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

class _ResultDot extends StatelessWidget {
  const _ResultDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(105),
        borderRadius: BorderRadius.circular(size * 0.38),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.state,
    required this.playerDisplayName,
    required this.compact,
  });

  final BattleState state;
  final String playerDisplayName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String opponentName = state.opponentName.trim().isEmpty
        ? 'Lawan'
        : state.opponentName;
    final String playerName = playerDisplayName.trim().isEmpty
        ? 'Kamu'
        : playerDisplayName;

    return Container(
      key: const ValueKey<String>('battle-result-score-card'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(4, compact ? 8 : 10, 4, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFF17233F).withAlpha(22)),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.sports_score_rounded,
                color: _ResultSection._ink,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Skor ronde',
                style: GoogleFonts.fredoka(
                  color: _ResultSection._ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 7 : 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: _ScoreColumn(
                  label: playerName,
                  value: '${state.playerRoundWins}',
                  color: _ResultSection._playerBlue,
                  compact: compact,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '—',
                  style: GoogleFonts.fredoka(
                    color: _ResultSection._mutedInk.withAlpha(90),
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: _ScoreColumn(
                  label: opponentName,
                  value: '${state.opponentRoundWins}',
                  color: _ResultSection._rivalCoral,
                  compact: compact,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 7 : 9),
          Divider(color: _ResultSection._ink.withAlpha(18), height: 1),
          SizedBox(height: compact ? 7 : 9),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniMetric(
                  value: '${state.playerHp}%',
                  label: 'HP kamu',
                  compact: compact,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: _ResultSection._ink.withAlpha(18),
              ),
              Expanded(
                child: _MiniMetric(
                  value: '${state.opponentHp}%',
                  label: 'HP lawan',
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
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
            color: _ResultSection._mutedInk,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.fredoka(
            color: color,
            fontSize: compact ? 29 : 32,
            fontWeight: FontWeight.w700,
            height: 1,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.favorite_rounded, color: Color(0xFFF05E5E), size: 17),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: GoogleFonts.fredoka(
                color: _ResultSection._ink,
                fontSize: compact ? 15 : 17,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: _ResultSection._mutedInk,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.ratingText,
    required this.coinsDelta,
    required this.isRanked,
    required this.claimed,
    required this.accent,
    required this.compact,
  });

  final String ratingText;
  final int coinsDelta;
  final bool isRanked;
  final bool claimed;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('battle-result-reward-card'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 9),
      decoration: BoxDecoration(
        color: accent.withAlpha(24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(72)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.military_tech_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isRanked ? 'Rating & Y-Coin' : 'Mode tanpa progression',
                  style: GoogleFonts.dmSans(
                    color: _ResultSection._mutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isRanked
                      ? '$ratingText rating  •  +$coinsDelta Y-Coin'
                      : 'Rating tetap',
                  style: GoogleFonts.fredoka(
                    color: _ResultSection._ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (claimed)
            _RewardClaimedBanner(compact: compact)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'Siap diklaim',
                style: GoogleFonts.dmSans(
                  color: _ResultSection._mutedInk,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardClaimedBanner extends StatelessWidget {
  const _RewardClaimedBanner({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF47CFA0).withAlpha(30),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF47CFA0).withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.check_rounded, color: Color(0xFF258861), size: 15),
          const SizedBox(width: 3),
          Text(
            'Diklaim',
            style: GoogleFonts.dmSans(
              color: const Color(0xFF258861),
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
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
