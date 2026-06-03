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
            duration: const Duration(milliseconds: 1200),
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
      color: const Color(0xFF08101F),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: _ArenaMenuBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxHeight < 720;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, compact ? 18 : 28, 20, 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: max<double>(0, constraints.maxHeight - 36),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _ArenaMenuLogo(compact: compact),
                        SizedBox(height: compact ? 20 : 28),
                        _MenuActionButton(
                          icon: Icons.smart_toy_outlined,
                          title: 'VS Bot',
                          subtitle: 'Lawan AI dan kuasai kartu',
                          colors: const <Color>[
                            Color(0xFF1A3A6B),
                            Color(0xFF2563EB),
                          ],
                          onTap: widget.onStartBot,
                        ),
                        const SizedBox(height: 12),
                        _MenuActionButton(
                          icon: Icons.public_rounded,
                          title: 'VS Player',
                          subtitle: 'Buat room atau join teman',
                          colors: const <Color>[
                            Color(0xFF512DA8),
                            Color(0xFF9333EA),
                          ],
                          onTap: widget.onStartPlayer,
                        ),
                        const SizedBox(height: 12),
                        _MenuActionButton(
                          icon: Icons.home_rounded,
                          title: 'Kembali ke Halaman Utama',
                          subtitle: 'Keluar dari arena',
                          colors: const <Color>[
                            Color(0xFF14532D),
                            Color(0xFF16A34A),
                          ],
                          onTap: widget.onBackHome,
                        ),
                        SizedBox(height: compact ? 18 : 24),
                        _ArenaTipStrip(
                          playerDisplayName: widget.playerDisplayName,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // â”€â”€ Entrance transition overlay â”€â”€
          if (!_transitionDone)
            AnimatedBuilder(
              animation: _transitionController,
              builder: (BuildContext context, Widget? child) {
                final double t = _transitionController.value;
                final double fadeOut = t < 0.7
                    ? 0
                    : ((t - 0.7) / 0.3).clamp(0.0, 1.0);
                final double progressBar = (t / 0.65).clamp(0.0, 1.0);
                final double iconPulse = 1.0 + sin(t * pi * 4) * 0.08;

                return Positioned.fill(
                  child: IgnorePointer(
                    ignoring: fadeOut >= 1.0,
                    child: Opacity(
                      opacity: (1 - fadeOut).clamp(0.0, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0xFF0D1B3E),
                              Color(0xFF080E1A),
                              Color(0xFF0E2A1A),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Transform.scale(
                                scale: iconPulse,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFFFFD23F,
                                    ).withAlpha(28),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFFD23F,
                                      ).withAlpha(120),
                                      width: 2,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFD23F,
                                        ).withAlpha(60),
                                        blurRadius: 30,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.military_tech_rounded,
                                    color: Color(0xFFFFD23F),
                                    size: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'YUDHA PvP',
                                style: GoogleFonts.orbitron(
                                  color: const Color(0xFFFFD23F),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color: const Color(
                                        0xFFFFD23F,
                                      ).withAlpha(120),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'MEMASUKI ARENA',
                                style: GoogleFonts.orbitron(
                                  color: Colors.white.withAlpha(120),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: 200,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progressBar,
                                    backgroundColor: Colors.white.withAlpha(20),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFFD23F),
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
              },
            ),
        ],
      ),
    );
  }
}

class _ArenaMenuLogo extends StatelessWidget {
  const _ArenaMenuLogo({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: compact ? 72 : 88,
          height: compact ? 72 : 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.fireGold.withAlpha(15),
            border: Border.all(
              color: AppColors.fireGold.withAlpha(80),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.fireGold.withAlpha(30),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(
            Icons.military_tech_rounded,
            color: AppColors.fireGold,
            size: 46,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'YUDHA PvP',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            color: AppColors.fireGold,
            fontSize: compact ? 30 : 38,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ARENA PERTEMPURAN',
          style: TextStyle(
            color: Colors.white.withAlpha(150),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _MenuActionButton extends StatelessWidget {
  const _MenuActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.last.withAlpha(50),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(170),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withAlpha(160),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaTipStrip extends StatelessWidget {
  const _ArenaTipStrip({required this.playerDisplayName});

  final String playerDisplayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Text(
        '$playerDisplayName siap bertarung - jawab cepat, deal damage, rebut victory',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withAlpha(170),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }
}

class _ArenaMenuBackground extends StatelessWidget {
  const _ArenaMenuBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ArenaMenuBackgroundPainter());
  }
}

class _ArenaMenuBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF0A1628),
          Color(0xFF111D38),
          Color(0xFF0C1A2E),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    // Subtle corner accents only â€” no grid, no orbs
    final Paint glowBlue = Paint()
      ..color = const Color(0xFF3EAAFF).withAlpha(18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    final Paint glowGold = Paint()
      ..color = AppColors.fireGold.withAlpha(20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.15),
      100,
      glowBlue,
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.85),
      100,
      glowGold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
