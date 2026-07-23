part of '../pvp_page.dart';

class _ArenaMenuSection extends StatelessWidget {
  const _ArenaMenuSection({
    required this.playerDisplayName,
    required this.playerAvatarAsset,
    required this.opponentAvatarAsset,
    required this.selectedArena,
    required this.selectedTower,
    required this.onBackHome,
    required this.onStartBot,
    required this.onStartPlayer,
  });

  final String playerDisplayName;
  final String playerAvatarAsset;
  final String opponentAvatarAsset;
  final CosmeticItem selectedArena;
  final CosmeticItem selectedTower;
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
            final bool compact = constraints.maxHeight < 690;
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
                compact ? 16 : 22,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max<double>(
                    0,
                    constraints.maxHeight - (compact ? 28 : 40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          key: const ValueKey<String>('back-to-loadout'),
                          onPressed: onBackHome,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF17233F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                        const Spacer(),
                        Text(
                          '03  PILIH MODE',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF8B6B39),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 16 : 23),
                    Text(
                      'Siap bertanding, $firstName?',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.fredoka(
                        color: const Color(0xFF17233F),
                        fontSize: compact ? 28 : 32,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Loadout sudah siap. Pilih cara bermain untuk masuk ke arena.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF667085),
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: compact ? 15 : 20),
                    _ModeLoadoutSummary(
                      arena: selectedArena,
                      tower: selectedTower,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 16 : 22),
                    _ModeCard(
                      key: const ValueKey<String>('mode-bot'),
                      title: 'Lawan Bot',
                      description: 'Mulai langsung untuk latihan mandiri.',
                      actionLabel: 'Main sekarang',
                      accent: const Color(0xFF2878F0),
                      visual: _ModeVisual(
                        key: const ValueKey<String>('bot-mode-visual'),
                        playerAsset: playerAvatarAsset,
                        opponentAsset: opponentAvatarAsset,
                        online: false,
                      ),
                      compact: compact,
                      onTap: onStartBot,
                    ),
                    SizedBox(height: compact ? 12 : 15),
                    _ModeCard(
                      key: const ValueKey<String>('mode-online'),
                      title: 'Lawan Player',
                      description: 'Cari peserta lain melalui matchmaking.',
                      actionLabel: 'Cari lawan',
                      accent: const Color(0xFF7559D4),
                      visual: _ModeVisual(
                        key: const ValueKey<String>('online-mode-visual'),
                        playerAsset: playerAvatarAsset,
                        opponentAsset: opponentAvatarAsset,
                        online: true,
                      ),
                      compact: compact,
                      onTap: onStartPlayer,
                    ),
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

class _ModeLoadoutSummary extends StatelessWidget {
  const _ModeLoadoutSummary({
    required this.arena,
    required this.tower,
    required this.compact,
  });

  final CosmeticItem arena;
  final CosmeticItem tower;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 96 : 108,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0D9CC)),
      ),
      child: Row(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1.35,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                arena.assetPath!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  arena.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fredoka(
                    color: const Color(0xFF17233F),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tower: ${tower.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF667085),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: compact ? 54 : 62,
            child: Image.asset(
              tower.assetPath!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.accent,
    required this.visual,
    required this.compact,
    required this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final String actionLabel;
  final Color accent;
  final Widget visual;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (bool value) {
            if (_pressed != value) {
              setState(() => _pressed = value);
            }
          },
          child: Ink(
            height: widget.compact ? 128 : 148,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 12 : 15,
              vertical: widget.compact ? 8 : 11,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accent.withAlpha(80)),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: widget.compact ? 88 : 102,
                  child: widget.visual,
                ),
                SizedBox(width: widget.compact ? 12 : 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: GoogleFonts.fredoka(
                          color: const Color(0xFF17233F),
                          fontSize: widget.compact ? 18 : 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF667085),
                          fontSize: widget.compact ? 10.5 : 11.5,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: <Widget>[
                          Text(
                            widget.actionLabel,
                            style: GoogleFonts.dmSans(
                              color: widget.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: widget.accent,
                            size: 16,
                          ),
                        ],
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

class _ModeVisual extends StatelessWidget {
  const _ModeVisual({
    required this.playerAsset,
    required this.opponentAsset,
    required this.online,
    super.key,
  });

  final String playerAsset;
  final String opponentAsset;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: online ? const Color(0xFFF0ECFC) : const Color(0xFFEAF2FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 7, 5, 0),
        child: _ModeAvatar(
          key: ValueKey<String>(
            online ? 'online-player-avatar' : 'bot-opponent-avatar',
          ),
          assetPath: online ? playerAsset : opponentAsset,
        ),
      ),
    );
  }
}

class _ModeAvatar extends StatelessWidget {
  const _ModeAvatar({required this.assetPath, super.key});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final double scale =
        assetPath.contains('rare_ignis') || assetPath.contains('legend_luna')
        ? 1.18
        : 1;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
