part of '../pvp_page.dart';

class _ArenaMenuSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFF8EC),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxHeight < 660;
            final String trimmedName = playerDisplayName.trim();
            final String firstName = trimmedName.isEmpty
                ? 'Kamu'
                : trimmedName.split(RegExp(r'\s+')).first;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                compact ? 12 : 18,
                16,
                compact ? 14 : 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max<double>(
                    0,
                    constraints.maxHeight - (compact ? 26 : 38),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _MenuTopBar(onBack: onBackHome),
                    SizedBox(height: compact ? 18 : 28),
                    Text(
                      'Pilih lawanmu',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: const Color(0xFF17233F),
                        fontSize: compact ? 29 : 34,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$firstName, empat kartu dan satu arena sudah menunggu.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF667085),
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: compact ? 20 : 28),
                    _ArenaModeTile(
                      title: 'Lawan Bot',
                      subtitle: 'Latihan langsung melawan bot arena.',
                      status: 'Siap dimainkan',
                      accent: const Color(0xFF2878F0),
                      softColor: const Color(0xFFEAF2FE),
                      statusColor: const Color(0xFF228C62),
                      type: _MenuOpponentType.bot,
                      compact: compact,
                      onTap: onStartBot,
                    ),
                    SizedBox(height: compact ? 13 : 17),
                    _ArenaModeTile(
                      title: 'Lawan Player',
                      subtitle: 'Cari lawan online secara acak.',
                      status: 'Matchmaking acak',
                      accent: const Color(0xFF8B6FE8),
                      softColor: const Color(0xFFF0ECFC),
                      statusColor: const Color(0xFF7559D4),
                      type: _MenuOpponentType.player,
                      compact: compact,
                      onTap: onStartPlayer,
                    ),
                    SizedBox(height: compact ? 18 : 26),
                    const _MenuFourCardNote(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MenuTopBar extends StatelessWidget {
  const _MenuTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(14),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF17233F),
                size: 21,
              ),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
                color: Color(0xFF865710),
              ),
              const SizedBox(width: 6),
              Text(
                'MODE ARENA',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF865710),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MenuOpponentType { bot, player }

class _ArenaModeTile extends StatefulWidget {
  const _ArenaModeTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.accent,
    required this.softColor,
    required this.statusColor,
    required this.type,
    required this.compact,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color accent;
  final Color softColor;
  final Color statusColor;
  final _MenuOpponentType type;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_ArenaModeTile> createState() => _ArenaModeTileState();
}

class _ArenaModeTileState extends State<_ArenaModeTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.accent.withAlpha(60),
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (bool highlighted) {
                if (_pressed != highlighted) {
                  setState(() => _pressed = highlighted);
                }
              },
              child: Ink(
                height: widget.compact ? 124 : 142,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 13 : 16,
                  vertical: widget.compact ? 12 : 15,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: widget.accent.withAlpha(44)),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: <Widget>[
                    _MenuOpponentIllustration(
                      type: widget.type,
                      accent: widget.accent,
                      softColor: widget.softColor,
                      compact: widget.compact,
                    ),
                    SizedBox(width: widget.compact ? 12 : 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.fredoka(
                              color: const Color(0xFF17233F),
                              fontSize: widget.compact ? 18 : 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: const Color(0xFF667085),
                              fontSize: widget.compact ? 11.5 : 12.5,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: widget.compact ? 8 : 10),
                          _MenuStatusPill(
                            label: widget.status,
                            color: widget.statusColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.softColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: widget.accent,
                        size: 18,
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

class _MenuStatusPill extends StatelessWidget {
  const _MenuStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuOpponentIllustration extends StatelessWidget {
  const _MenuOpponentIllustration({
    required this.type,
    required this.accent,
    required this.softColor,
    required this.compact,
  });

  final _MenuOpponentType type;
  final Color accent;
  final Color softColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 76 : 88;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(19),
      ),
      child: type == _MenuOpponentType.bot
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(5, 3, 5, 0),
                  child: Image.asset(
                    _enemyAvatarAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    semanticLabel: 'Karakter bot arena',
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  left: -5,
                  bottom: 0,
                  width: size * 0.66,
                  height: size * 0.9,
                  child: Image.asset(
                    _playerAvatarAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    semanticLabel: 'Karakter pemain',
                  ),
                ),
                Positioned(
                  right: -5,
                  bottom: 0,
                  width: size * 0.66,
                  height: size * 0.9,
                  child: Image.asset(
                    _enemyAvatarAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    semanticLabel: 'Karakter lawan online',
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 27,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.sync_alt_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MenuFourCardNote extends StatelessWidget {
  const _MenuFourCardNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.style_rounded, color: Color(0xFF9A7A47), size: 17),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Pilih satu dari empat kartu di setiap giliran.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: const Color(0xFF7A6A51),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
