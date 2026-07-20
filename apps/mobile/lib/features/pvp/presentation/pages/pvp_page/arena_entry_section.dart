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
        final bool compact = constraints.maxHeight < 650;
        final String trimmedName = playerDisplayName.trim();
        final String firstName = trimmedName.isEmpty
            ? 'Kamu'
            : trimmedName.split(RegExp(r'\s+')).first;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC),
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              compact ? 14 : 18,
              16,
              compact ? 14 : 18,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: max<double>(
                  0,
                  constraints.maxHeight - (compact ? 28 : 36),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _EntryEyebrow(),
                      SizedBox(height: compact ? 10 : 14),
                      Text(
                        'Siap rebut arena,\n$firstName?',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fredoka(
                          color: const Color(0xFF17233F),
                          fontSize: compact ? 27 : 31,
                          height: 1.04,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Pilih kartu terbaikmu, jawab soal, lalu lihat seranganmu melesat.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF667085),
                          fontSize: compact ? 12.5 : 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      _EntryArenaDiorama(
                        playerName: firstName,
                        compact: compact,
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  const _EntryGameLoopStrip(),
                  SizedBox(height: compact ? 14 : 20),
                  _EntryPrimaryButton(onPressed: onEnterArena),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EntryEyebrow extends StatelessWidget {
  const _EntryEyebrow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE8B0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.stadium_rounded,
              size: 15,
              color: Color(0xFF9A6413),
            ),
            const SizedBox(width: 6),
            Text(
              'YUDHA ARENA',
              style: GoogleFonts.dmSans(
                color: const Color(0xFF865710),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryArenaDiorama extends StatelessWidget {
  const _EntryArenaDiorama({required this.playerName, required this.compact});

  final String playerName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 154 : 184,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0D9C9)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A795F3A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _EntryArenaDioramaPainter()),
          Positioned(
            left: 5,
            bottom: compact ? 5 : 3,
            width: compact ? 108 : 126,
            height: compact ? 120 : 146,
            child: Image.asset(
              _playerAvatarAsset,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              semanticLabel: 'Karakter pemain',
            ),
          ),
          Positioned(
            right: 5,
            bottom: compact ? 5 : 3,
            width: compact ? 108 : 126,
            height: compact ? 120 : 146,
            child: Image.asset(
              _enemyAvatarAsset,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              semanticLabel: 'Karakter rival',
            ),
          ),
          Align(
            child: Container(
              width: compact ? 48 : 54,
              height: compact ? 48 : 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC857),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x337C5613),
                    blurRadius: 0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'VS',
                style: GoogleFonts.fredoka(
                  color: const Color(0xFF51390D),
                  fontSize: compact ? 17 : 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: _EntrySideLabel(
              label: playerName,
              color: const Color(0xFF2878F0),
            ),
          ),
          const Positioned(
            right: 12,
            bottom: 10,
            child: _EntrySideLabel(label: 'Rival', color: Color(0xFFF05E5E)),
          ),
        ],
      ),
    );
  }
}

class _EntrySideLabel extends StatelessWidget {
  const _EntrySideLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EntryGameLoopStrip extends StatelessWidget {
  const _EntryGameLoopStrip();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Alur bermain: Pilih kartu, Jawab, lalu Serang',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEAE1D2)),
        ),
        child: const Row(
          children: <Widget>[
            Expanded(
              child: _EntryLoopStep(
                icon: Icons.style_rounded,
                label: 'Pilih kartu',
                color: Color(0xFF2878F0),
                background: Color(0xFFEAF2FE),
              ),
            ),
            _EntryLoopArrow(),
            Expanded(
              child: _EntryLoopStep(
                icon: Icons.quiz_rounded,
                label: 'Jawab',
                color: Color(0xFF8B6FE8),
                background: Color(0xFFF0ECFC),
              ),
            ),
            _EntryLoopArrow(),
            Expanded(
              child: _EntryLoopStep(
                icon: Icons.bolt_rounded,
                label: 'Serang',
                color: Color(0xFFF05E5E),
                background: Color(0xFFFDECEC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryLoopStep extends StatelessWidget {
  const _EntryLoopStep({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: const Color(0xFF344054),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EntryLoopArrow extends StatelessWidget {
  const _EntryLoopArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 21),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: Color(0xFFB4AA9A),
        size: 15,
      ),
    );
  }
}

class _EntryPrimaryButton extends StatelessWidget {
  const _EntryPrimaryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xFF1453B7), offset: Offset(0, 5)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2878F0),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Masuk arena',
                  style: GoogleFonts.fredoka(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 9),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryArenaDioramaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint shadowPaint = Paint()..color = const Color(0x2B38583E);
    final Paint basePaint = Paint()..color = const Color(0xFF78B96D);
    final Paint grassPaint = Paint()..color = const Color(0xFF9BD286);
    final Paint riverPaint = Paint()..color = const Color(0xFF71C7F2);
    final Paint bridgePaint = Paint()..color = const Color(0xFFD9AA70);
    final Paint bridgeLinePaint = Paint()
      ..color = const Color(0xFFB9834E)
      ..strokeWidth = 2;

    final Rect baseRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.58),
      width: size.width * 0.88,
      height: size.height * 0.62,
    );
    canvas.drawOval(baseRect.shift(const Offset(0, 7)), shadowPaint);
    canvas.drawOval(baseRect, basePaint);

    final Rect grassRect = Rect.fromCenter(
      center: Offset(baseRect.center.dx, baseRect.center.dy - 4),
      width: baseRect.width * 0.94,
      height: baseRect.height * 0.84,
    );
    canvas.drawOval(grassRect, grassPaint);

    canvas.save();
    canvas.clipPath(Path()..addOval(grassRect));
    final Rect riverRect = Rect.fromLTWH(
      0,
      grassRect.center.dy - 10,
      size.width,
      20,
    );
    canvas.drawRect(riverRect, riverPaint);
    final RRect bridge = RRect.fromRectAndRadius(
      Rect.fromCenter(center: grassRect.center, width: 40, height: 30),
      const Radius.circular(5),
    );
    canvas.drawRRect(bridge, bridgePaint);
    for (double y = bridge.top + 6; y < bridge.bottom; y += 7) {
      canvas.drawLine(
        Offset(bridge.left + 3, y),
        Offset(bridge.right - 3, y),
        bridgeLinePaint,
      );
    }
    canvas.restore();

    final Paint markerPaint = Paint()..color = const Color(0x66FFFFFF);
    canvas.drawCircle(
      Offset(size.width * 0.27, size.height * 0.47),
      6,
      markerPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.73, size.height * 0.69),
      6,
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
