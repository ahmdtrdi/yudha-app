part of '../pvp_page.dart';

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

