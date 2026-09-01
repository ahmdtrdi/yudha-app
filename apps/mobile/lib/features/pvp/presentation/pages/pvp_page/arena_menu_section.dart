part of '../pvp_page.dart';

class _ArenaMenuSection extends StatefulWidget {
  const _ArenaMenuSection({
    required this.playerDisplayName,
    required this.playerAvatarAsset,
    required this.selectedArena,
    required this.selectedTower,
    required this.balance,
    required this.onBackLoadout,
    required this.onTopUp,
    required this.onOpenStore,
    required this.onStartBot,
    required this.onStartCasual,
    required this.onStartRanked,
    required this.onStartPrivateRoom,
  });

  final String playerDisplayName;
  final String playerAvatarAsset;
  final CosmeticItem selectedArena;
  final CosmeticItem selectedTower;
  final int? balance;
  final VoidCallback onBackLoadout;
  final VoidCallback onTopUp;
  final VoidCallback onOpenStore;
  final VoidCallback onStartBot;
  final VoidCallback onStartCasual;
  final VoidCallback onStartRanked;
  final VoidCallback onStartPrivateRoom;

  @override
  State<_ArenaMenuSection> createState() => _ArenaMenuSectionState();
}

class _ArenaMenuSectionState extends State<_ArenaMenuSection> {
  int _selectedModeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<_BattleModeOption> options = <_BattleModeOption>[
      _BattleModeOption(
        id: 'bot',
        title: 'Bot',
        actionLabel: 'MULAI LATIHAN',
        accent: const Color(0xFF2878F0),
        surface: const Color(0xFFE7F0FF),
        shadow: const Color(0xFF9ABBEF),
        illustrationAsset: 'assets/icons/mode_bot.svg',
        onStart: widget.onStartBot,
      ),
      _BattleModeOption(
        id: 'ranked',
        title: 'Ranked',
        actionLabel: 'MULAI RANKED',
        accent: const Color(0xFFE0922F),
        surface: const Color(0xFFFFEEDB),
        shadow: const Color(0xFFE9B578),
        illustrationAsset: 'assets/icons/mode_ranked.svg',
        onStart: widget.onStartRanked,
      ),
      _BattleModeOption(
        id: 'online',
        title: 'Casual',
        actionLabel: 'MULAI CASUAL',
        accent: const Color(0xFF7559D4),
        surface: const Color(0xFFF0EBFF),
        shadow: const Color(0xFFB9A9E8),
        illustrationAsset: 'assets/icons/mode_casual.svg',
        onStart: widget.onStartCasual,
      ),
      _BattleModeOption(
        id: 'private',
        title: 'Private',
        actionLabel: 'BUKA ROOM PRIVAT',
        accent: const Color(0xFF2FAE7D),
        surface: const Color(0xFFE7F8F1),
        shadow: const Color(0xFF96CDB4),
        illustrationAsset: 'assets/icons/mode_private.svg',
        onStart: widget.onStartPrivateRoom,
      ),
    ];
    final _BattleModeOption selected = options[_selectedModeIndex];

    return ColoredBox(
      color: const Color(0xFFFFF8EC),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxHeight < 690;
          final String trimmedName = widget.playerDisplayName.trim();
          final String firstName = trimmedName.isEmpty
              ? 'Kamu'
              : trimmedName.split(RegExp(r'\s+')).first;
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: max<double>(0, constraints.maxHeight - 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SetupHeader(
                    step: _ArenaSetupStep.mode,
                    balance: widget.balance,
                    onBack: widget.onBackLoadout,
                    onTopUp: widget.onTopUp,
                    onOpenStore: widget.onOpenStore,
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Text(
                    '03  PILIH MODE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF8B6B39),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
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
                  SizedBox(height: compact ? 12 : 16),
                  _ModeShowcase(
                    option: selected,
                    arena: widget.selectedArena,
                    characterAsset: widget.playerAvatarAsset,
                    tower: widget.selectedTower,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 10 : 13),
                  _ModeCardSelector(
                    options: options,
                    selectedIndex: _selectedModeIndex,
                    compact: compact,
                    onSelect: (int index) {
                      setState(() => _selectedModeIndex = index);
                    },
                  ),
                  SizedBox(height: compact ? 11 : 14),
                  _ClaySetupButton(
                    buttonKey: ValueKey<String>('mode-${selected.id}'),
                    label: selected.actionLabel,
                    onPressed: selected.onStart,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BattleModeOption {
  const _BattleModeOption({
    required this.id,
    required this.title,
    required this.actionLabel,
    required this.accent,
    required this.surface,
    required this.shadow,
    required this.illustrationAsset,
    required this.onStart,
  });

  final String id;
  final String title;
  final String actionLabel;
  final Color accent;
  final Color surface;
  final Color shadow;
  final String illustrationAsset;
  final VoidCallback onStart;
}

class _ModeShowcase extends StatelessWidget {
  const _ModeShowcase({
    required this.option,
    required this.arena,
    required this.characterAsset,
    required this.tower,
    required this.compact,
  });

  final _BattleModeOption option;
  final CosmeticItem arena;
  final String characterAsset;
  final CosmeticItem tower;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const ValueKey<String>('mode-selected-showcase'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: compact ? 245 : 290,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: option.accent.withAlpha(130), width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: option.accent.withAlpha(45),
            blurRadius: 0,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            key: const ValueKey<String>('mode-selected-arena'),
            arena.assetPath!,
            fit: BoxFit.cover,
            cacheWidth: 1024,
            filterQuality: FilterQuality.low,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  option.accent.withAlpha(20),
                  option.accent.withAlpha(92),
                  const Color(0xB817233F),
                ],
                stops: const <double>[0, 0.58, 1],
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(225),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                arena.name,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF173A67),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            top: compact ? 30 : 38,
            bottom: 8,
            left: 42,
            right: 76,
            child: _ModeAvatar(
              key: const ValueKey<String>('mode-selected-character'),
              assetPath: characterAsset,
            ),
          ),
          Positioned(
            right: 13,
            bottom: 13,
            child: SizedBox(
              width: compact ? 66 : 78,
              height: compact ? 80 : 94,
              child: Image.asset(
                key: const ValueKey<String>('mode-selected-tower'),
                tower.assetPath!,
                fit: BoxFit.contain,
                cacheWidth: 280,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCardSelector extends StatelessWidget {
  const _ModeCardSelector({
    required this.options,
    required this.selectedIndex,
    required this.compact,
    required this.onSelect,
  });

  final List<_BattleModeOption> options;
  final int selectedIndex;
  final bool compact;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final int rowCount = (options.length / 2).ceil();
    return Column(
      children: List<Widget>.generate(rowCount, (int row) {
        final int first = row * 2;
        final int second = first + 1;
        return Padding(
          padding: EdgeInsets.only(top: row == 0 ? 0 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _buildCard(first)),
              if (second < options.length)
                Expanded(child: _buildCard(second))
              else
                const Spacer(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCard(int index) {
    return Padding(
      padding: EdgeInsets.only(right: index.isOdd ? 0 : 8),
      child: _ModePortraitCard(
        option: options[index],
        selected: index == selectedIndex,
        compact: compact,
        onTap: () => onSelect(index),
      ),
    );
  }
}

class _ModePortraitCard extends StatelessWidget {
  const _ModePortraitCard({
    required this.option,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _BattleModeOption option;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 92 : 102,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: option.shadow,
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 5,
            child: Material(
              color: selected ? option.surface : Colors.white,
              borderRadius: BorderRadius.circular(17),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey<String>('mode-choice-${option.id}'),
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 11 : 13,
                    vertical: compact ? 9 : 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: selected ? option.accent : const Color(0xFFE0E2E7),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 24,
                              height: 4,
                              decoration: BoxDecoration(
                                color: option.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              option.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.fredoka(
                                color: const Color(0xFF17233F),
                                fontSize: compact ? 14 : 15,
                                height: 1.05,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SvgPicture.asset(
                        option.illustrationAsset,
                        key: ValueKey<String>('mode-illustration-${option.id}'),
                        width: compact ? 44 : 50,
                        height: compact ? 36 : 41,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
          key: const ValueKey<String>('mode-selected-character-image'),
          assetPath,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          cacheWidth: 320,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}
