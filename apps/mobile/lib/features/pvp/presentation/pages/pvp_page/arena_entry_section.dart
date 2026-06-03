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
                  height: compact ? 236 : 280,
                  child: _ArenaPreview(playerName: playerDisplayName),
                ),
                SizedBox(height: compact ? 12 : 16),
                _HowToPlayPanel(compact: compact),
                SizedBox(height: compact ? 12 : 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: onEnterArena,
                    icon: const Icon(Icons.sports_esports_rounded, size: 20),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warriorNavy,
                      foregroundColor: const Color(0xFFEAF0FB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppColors.textStrong.withAlpha(70),
                        ),
                      ),
                    ),
                    label: Text(
                      'MASUK ARENA',
                      style: GoogleFonts.orbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
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
    final List<({IconData icon, String title, String text})>
    items = <({IconData icon, String title, String text})>[
      (
        icon: Icons.style_rounded,
        title: 'Pilih kartu',
        text:
            'Pilih kartu soal dari tanganmu. Tiap kartu punya damage atau heal berbeda.',
      ),
      (
        icon: Icons.bolt_rounded,
        title: 'Jawab soal',
        text:
            'Jawab benar untuk memberi damage ke menara lawan atau heal menaramu.',
      ),
      (
        icon: Icons.account_balance_rounded,
        title: 'Hancurkan menara',
        text: 'Hancurkan menara utama lawan sebelum menaramu dihancurkan.',
      ),
    ];

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'CARA BERMAIN',
            style: GoogleFonts.orbitron(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          for (int i = 0; i < items.length; i++) ...<Widget>[
            _HowToRow(
              icon: items[i].icon,
              title: items[i].title,
              text: items[i].text,
              accent: i == 0
                  ? AppColors.levelUpTeal
                  : i == 1
                  ? AppColors.fireGold
                  : AppColors.warriorNavy,
            ),
            if (i != items.length - 1) SizedBox(height: compact ? 8 : 8),
          ],
        ],
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  const _HowToRow({
    required this.icon,
    required this.title,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    color: AppColors.warriorNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
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
    final String safePlayerName = playerName.trim().isEmpty
        ? 'Kamu'
        : playerName;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(30)),
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
                  vertical: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _AvatarBadge(label: safePlayerName, isEnemy: false),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.warriorNavy.withAlpha(80),
                        ),
                      ),
                      child: Text(
                        'VS',
                        style: GoogleFonts.orbitron(
                          color: AppColors.warriorNavy,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1.8,
                        ),
                      ),
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
    final Color line = AppColors.warriorNavy.withAlpha(26);
    final Color strong = AppColors.warriorNavy.withAlpha(90);

    return Stack(
      children: <Widget>[
        for (double x in <double>[0.17, 0.34, 0.5, 0.66, 0.83])
          Align(
            alignment: Alignment(x * 2 - 1, 0),
            child: Container(width: 1, color: line),
          ),
        for (double y in <double>[0.25, 0.5, 0.75])
          Align(
            alignment: Alignment(0, y * 2 - 1),
            child: Container(height: 1, color: line),
          ),
        Align(
          alignment: Alignment.center,
          child: Container(width: 1.2, color: strong.withAlpha(90)),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(height: 1.2, color: strong.withAlpha(24)),
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
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 34,
          height: 34,
          child: CustomPaint(
            painter: _BracketPainter(
              left: left,
              top: top,
              color: AppColors.warriorNavy.withAlpha(80),
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
    final Color tint = isEnemy ? AppColors.fireGold : AppColors.levelUpTeal;
    final String asset = isEnemy ? _enemyAvatarAsset : _playerAvatarAsset;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 104,
          child: Column(
            children: <Widget>[
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: tint.withAlpha(28),
                  backgroundImage: AssetImage(asset),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 90,
                height: 6,
                decoration: BoxDecoration(
                  color: tint.withAlpha(80),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 104,
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: tint,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.2,
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
      ..color = AppColors.warriorNavy.withAlpha(36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Paint softPaint = Paint()
      ..color = AppColors.levelUpTeal.withAlpha(28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Rect outerOval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.72,
      height: size.height * 0.56,
    );
    final Rect innerOval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.46,
      height: size.height * 0.34,
    );

    canvas.drawOval(outerOval, ringPaint);
    canvas.drawOval(innerOval, softPaint);

    final Paint dotPaint = Paint()
      ..color = AppColors.levelUpTeal.withAlpha(110);
    canvas.drawCircle(Offset(size.width / 2, 28), 5, dotPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height - 28), 5, dotPaint);
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
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final Path path = Path();

    final double startX = left ? 0 : size.width;
    final double midX = left ? size.width * 0.65 : size.width * 0.35;
    final double startY = top ? 0 : size.height;
    final double midY = top ? size.height * 0.65 : size.height * 0.35;

    path.moveTo(startX, startY);
    path.lineTo(midX, startY);
    path.moveTo(startX, startY);
    path.lineTo(startX, midY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
