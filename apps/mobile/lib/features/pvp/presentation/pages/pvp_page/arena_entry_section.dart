part of '../pvp_page.dart';

class _ArenaEntrySection extends StatelessWidget {
  const _ArenaEntrySection({
    required this.playerDisplayName,
    required this.onEnterArena,
  });

  final String playerDisplayName;
  final VoidCallback onEnterArena;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 700;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: compact ? 220 : 260,
                  child: _ArenaPreview(playerName: playerDisplayName),
                ),
                SizedBox(height: compact ? 14 : 20),
                _HowToPlayPanel(compact: compact),
                SizedBox(height: compact ? 16 : 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: onEnterArena,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warriorNavy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.sports_esports_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Masuk Arena',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HowToPlayPanel extends StatelessWidget {
  const _HowToPlayPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<({IconData icon, String title, String text, Color accent})>
        items =
        <({IconData icon, String title, String text, Color accent})>[
      (
        icon: Icons.style_rounded,
        title: 'Pilih Kartu',
        text: 'Pilih kartu soal dari tanganmu — tiap kartu punya damage atau heal berbeda',
        accent: AppColors.levelUpTeal,
      ),
      (
        icon: Icons.bolt_rounded,
        title: 'Jawab Soal',
        text: 'Jawab benar untuk memberi damage ke menara lawan atau heal menaramu',
        accent: AppColors.fireGold,
      ),
      (
        icon: Icons.account_balance_rounded,
        title: 'Hancurkan Menara',
        text: 'Hancurkan menara utama lawan sebelum menaramu dihancurkan',
        accent: AppColors.warriorNavy,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Cara Bermain',
            style: GoogleFonts.dmSans(
              color: AppColors.textStrong,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (int i = 0; i < items.length; i++) ...<Widget>[
          _HowToRow(
            step: i + 1,
            icon: items[i].icon,
            title: items[i].title,
            text: items[i].text,
            accent: items[i].accent,
          ),
          if (i != items.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _HowToRow extends StatelessWidget {
  const _HowToRow({
    required this.step,
    required this.icon,
    required this.title,
    required this.text,
    required this.accent,
  });

  final int step;
  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(22),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$step',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
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

class _ArenaPreview extends StatelessWidget {
  const _ArenaPreview({required this.playerName});

  final String playerName;

  @override
  Widget build(BuildContext context) {
    final String safePlayerName =
        playerName.trim().isEmpty ? 'Kamu' : playerName;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF7F9FC),
            Color(0xFFEEF2F9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE3ED)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: <Widget>[
            const _ArenaGrid(),
            Positioned.fill(child: CustomPaint(painter: _ArenaRingPainter())),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 22,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _AvatarBadge(label: safePlayerName, isEnemy: false),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFDDE3ED),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'VS',
                            style: GoogleFonts.dmSans(
                              color: AppColors.textStrong,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 32,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.fireGold.withAlpha(120),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                    _AvatarBadge(label: 'Lawan', isEnemy: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArenaGrid extends StatelessWidget {
  const _ArenaGrid();

  @override
  Widget build(BuildContext context) {
    final Color line = const Color(0xFFCDD5E0).withAlpha(50);

    return Stack(
      children: <Widget>[
        for (double x in <double>[0.17, 0.34, 0.5, 0.66, 0.83])
          Align(
            alignment: Alignment(x * 2 - 1, 0),
            child: Container(width: 0.8, color: line),
          ),
        for (double y in <double>[0.25, 0.5, 0.75])
          Align(
            alignment: Alignment(0, y * 2 - 1),
            child: Container(height: 0.8, color: line),
          ),
        ...<Widget>[
          _CornerBracket(alignment: Alignment.topLeft),
          _CornerBracket(alignment: Alignment.topRight),
          _CornerBracket(alignment: Alignment.bottomLeft),
          _CornerBracket(alignment: Alignment.bottomRight),
        ],
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final bool left = alignment.x < 0;
    final bool top = alignment.y < 0;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CustomPaint(
            painter: _BracketPainter(
              left: left,
              top: top,
              color: AppColors.warriorNavy.withAlpha(50),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.label, required this.isEnemy});

  final String label;
  final bool isEnemy;

  @override
  Widget build(BuildContext context) {
    final Color tint = isEnemy
        ? const Color(0xFFE25555)
        : AppColors.levelUpTeal;
    final String asset = isEnemy ? _enemyAvatarAsset : _playerAvatarAsset;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: tint.withAlpha(60), width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: tint.withAlpha(16),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              backgroundColor: tint.withAlpha(12),
              backgroundImage: AssetImage(asset),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: tint.withAlpha(60),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 90,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: AppColors.textStrong,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ArenaRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint ringPaint = Paint()
      ..color = AppColors.warriorNavy.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Rect outerOval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.54,
    );

    canvas.drawOval(outerOval, ringPaint);

    // Small dots at top/bottom
    final Paint dotPaint = Paint()
      ..color = AppColors.levelUpTeal.withAlpha(70);
    canvas.drawCircle(Offset(size.width / 2, 24), 3.5, dotPaint);
    canvas.drawCircle(
      Offset(size.width / 2, size.height - 24),
      3.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({
    required this.left,
    required this.top,
    required this.color,
  });

  final bool left;
  final bool top;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final Path path = Path();

    final double startX = left ? 0 : size.width;
    final double midX = left ? size.width * 0.6 : size.width * 0.4;
    final double startY = top ? 0 : size.height;
    final double midY = top ? size.height * 0.6 : size.height * 0.4;

    path.moveTo(startX, startY);
    path.lineTo(midX, startY);
    path.moveTo(startX, startY);
    path.lineTo(startX, midY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
