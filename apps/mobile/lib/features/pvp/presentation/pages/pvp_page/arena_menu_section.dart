part of '../pvp_page.dart';

class _ArenaMenuSection extends StatefulWidget {
  const _ArenaMenuSection({
    required this.playerDisplayName,
    required this.onBackHome,
    required this.onStartBot,
    required this.onStartPlayer,
  });

  final String playerDisplayName;
  final VoidCallback onBackHome;
  final VoidCallback onStartBot;
  final VoidCallback onStartPlayer;

  @override
  State<_ArenaMenuSection> createState() => _ArenaMenuSectionState();
}

class _ArenaMenuSectionState extends State<_ArenaMenuSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transitionController;
  bool _transitionDone = false;

  @override
  void initState() {
    super.initState();
    _transitionController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1000),
          )
          ..forward().then((_) {
            if (mounted) {
              setState(() {
                _transitionDone = true;
              });
            }
          });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FC),
      child: Stack(
        children: <Widget>[
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxHeight < 720;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, compact ? 16 : 24, 20, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: max<double>(0, constraints.maxHeight - 36),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _ArenaMenuHeader(compact: compact),
                        SizedBox(height: compact ? 22 : 32),
                        _ModeCard(
                          icon: Icons.smart_toy_outlined,
                          title: 'VS Bot',
                          subtitle: 'Latihan melawan AI',
                          accentColor: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF4FF),
                          borderColor: const Color(0xFFD0DCEF),
                          onTap: widget.onStartBot,
                        ),
                        const SizedBox(height: 10),
                        _ModeCard(
                          icon: Icons.people_alt_rounded,
                          title: 'VS Player',
                          subtitle: 'Buat room atau join teman',
                          accentColor: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFF3EFFE),
                          borderColor: const Color(0xFFDDD0F5),
                          onTap: widget.onStartPlayer,
                        ),
                        SizedBox(height: compact ? 18 : 26),
                        _QuickTip(
                          playerDisplayName: widget.playerDisplayName,
                        ),
                        SizedBox(height: compact ? 12 : 18),
                        TextButton.icon(
                          onPressed: widget.onBackHome,
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Kembali',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Entrance transition overlay
          if (!_transitionDone)
            AnimatedBuilder(
              animation: _transitionController,
              builder: (BuildContext context, Widget? child) {
                final double t = _transitionController.value;
                final double fadeOut = t < 0.65
                    ? 0
                    : ((t - 0.65) / 0.35).clamp(0.0, 1.0);
                final double progressBar = (t / 0.6).clamp(0.0, 1.0);
                final double scale = 0.92 +
                    Curves.easeOut.transform(
                          (t / 0.5).clamp(0.0, 1.0),
                        ) *
                        0.08;

                return Positioned.fill(
                  child: IgnorePointer(
                    ignoring: fadeOut >= 1.0,
                    child: Opacity(
                      opacity: (1 - fadeOut).clamp(0.0, 1.0),
                      child: Container(
                        color: const Color(0xFFF6F8FC),
                        child: Center(
                          child: Transform.scale(
                            scale: scale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.warriorNavy.withAlpha(10),
                                    border: Border.all(
                                      color: AppColors.warriorNavy.withAlpha(40),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.shield_rounded,
                                    color: AppColors.warriorNavy,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Yudha PvP',
                                  style: GoogleFonts.dmSans(
                                    color: AppColors.textStrong,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Memasuki Arena...',
                                  style: GoogleFonts.dmSans(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: 180,
                                  height: 3,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: progressBar,
                                      backgroundColor:
                                          AppColors.warriorNavy.withAlpha(14),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        AppColors.warriorNavy,
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
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ArenaMenuHeader extends StatelessWidget {
  const _ArenaMenuHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: compact ? 64 : 76,
          height: compact ? 64 : 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warriorNavy.withAlpha(8),
            border: Border.all(
              color: AppColors.warriorNavy.withAlpha(30),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.shield_rounded,
            color: AppColors.warriorNavy,
            size: compact ? 32 : 38,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Yudha PvP',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: AppColors.textStrong,
            fontSize: compact ? 28 : 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih mode pertandingan',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: accentColor.withAlpha(30),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: accentColor,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTip extends StatelessWidget {
  const _QuickTip({required this.playerDisplayName});

  final String playerDisplayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.fireGold.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.fireGold,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Jawab cepat & benar untuk deal damage maksimal',
              style: GoogleFonts.dmSans(
                color: AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
