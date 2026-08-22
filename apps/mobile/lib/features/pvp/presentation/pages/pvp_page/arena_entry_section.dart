part of '../pvp_page.dart';

enum _ArenaSetupStep { arena, loadout, mode }

class _ArenaEntrySection extends StatelessWidget {
  const _ArenaEntrySection({
    required this.step,
    required this.playerDisplayName,
    required this.economy,
    required this.selectedCharacter,
    required this.selectedTower,
    required this.selectedArena,
    required this.profileTarget,
    required this.onSelectCosmetic,
    required this.onSelectArena,
    required this.onLockedArenaTap,
    required this.onOpenStore,
    required this.onTopUp,
    required this.onBack,
    required this.onContinue,
  });

  final _ArenaSetupStep step;
  final String playerDisplayName;
  final GameEconomyState economy;
  final CosmeticItem selectedCharacter;
  final CosmeticItem selectedTower;
  final CosmeticItem selectedArena;
  final ProfileTarget? profileTarget;
  final ValueChanged<CosmeticItem> onSelectCosmetic;
  final ValueChanged<CosmeticItem> onSelectArena;
  final ValueChanged<CosmeticItem> onLockedArenaTap;
  final VoidCallback onOpenStore;
  final VoidCallback onTopUp;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 690;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SetupHeader(
              step: step,
              balance: economy.isAuthoritative ? economy.yCoins : null,
              onBack: onBack,
              onTopUp: onTopUp,
              onOpenStore: onOpenStore,
            ),
            SizedBox(height: compact ? 9 : 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder:
                    (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[...previousChildren, ?currentChild],
                      );
                    },
                child: step == _ArenaSetupStep.arena
                    ? _ArenaPickerView(
                        key: const ValueKey<String>('arena-step'),
                        selectedArena: selectedArena,
                        profileTarget: profileTarget,
                        compact: compact,
                        onSelect: onSelectArena,
                        onLockedTap: onLockedArenaTap,
                      )
                    : _LoadoutPickerView(
                        key: const ValueKey<String>('loadout-step'),
                        playerDisplayName: playerDisplayName,
                        economy: economy,
                        selectedArena: selectedArena,
                        selectedCharacter: selectedCharacter,
                        selectedTower: selectedTower,
                        compact: compact,
                        onSelect: onSelectCosmetic,
                        onLockedTap: onOpenStore,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _ClaySetupButton(
              buttonKey: ValueKey<String>(
                step == _ArenaSetupStep.arena
                    ? 'continue-to-loadout'
                    : 'continue-to-mode',
              ),
              label: step == _ArenaSetupStep.arena
                  ? 'PILIH KARAKTER & TOWER'
                  : 'LANJUT PILIH MODE',
              onPressed: onContinue,
            ),
          ],
        );
      },
    );
  }
}

class _ClaySetupButton extends StatelessWidget {
  const _ClaySetupButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF0A35F),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 7,
            child: Material(
              color: const Color(0xFFFFD7A3),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: buttonKey,
                onTap: onPressed,
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fredoka(
                      color: const Color(0xFFC66B24),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({
    required this.step,
    required this.balance,
    required this.onBack,
    required this.onTopUp,
    required this.onOpenStore,
  });

  final _ArenaSetupStep step;
  final int? balance;
  final VoidCallback onBack;
  final VoidCallback onTopUp;
  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    final int activeStep = switch (step) {
      _ArenaSetupStep.arena => 1,
      _ArenaSetupStep.loadout => 2,
      _ArenaSetupStep.mode => 3,
    };
    final String title = switch (step) {
      _ArenaSetupStep.arena => 'Pilih arena',
      _ArenaSetupStep.loadout => 'Siapkan loadout',
      _ArenaSetupStep.mode => 'Pilih mode',
    };
    return Column(
      children: <Widget>[
        SizedBox(
          height: 40,
          child: Row(
            children: <Widget>[
              if (step != _ArenaSetupStep.arena)
                IconButton(
                  key: ValueKey<String>(
                    step == _ArenaSetupStep.loadout
                        ? 'back-to-arena'
                        : 'back-to-loadout',
                  ),
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF17233F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                )
              else
                const SizedBox(width: 40),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF17233F),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                onTap: balance == null ? null : onTopUp,
                borderRadius: BorderRadius.circular(11),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                  child: Row(
                    children: <Widget>[
                      const YCoinMark(size: 20),
                      const SizedBox(width: 5),
                      Text(
                        balance == null ? '—' : formatYCoins(balance!),
                        style: GoogleFonts.jetBrainsMono(
                          color: AppColors.textStrong,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey<String>('pvp-open-store'),
                onPressed: onOpenStore,
                tooltip: 'Buka Store',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF173A67),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.storefront_outlined, size: 19),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: List<Widget>.generate(3, (int index) {
            final bool active = index < activeStep;
            return Expanded(
              child: Container(
                key: ValueKey<String>('setup-progress-step-${index + 1}'),
                height: 3,
                margin: EdgeInsets.only(right: index == 2 ? 0 : 7),
                color: active
                    ? const Color(0xFF173A67)
                    : const Color(0xFFD8D3C8),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ArenaPickerView extends StatelessWidget {
  const _ArenaPickerView({
    required this.selectedArena,
    required this.profileTarget,
    required this.compact,
    required this.onSelect,
    required this.onLockedTap,
    super.key,
  });

  final CosmeticItem selectedArena;
  final ProfileTarget? profileTarget;
  final bool compact;
  final ValueChanged<CosmeticItem> onSelect;
  final ValueChanged<CosmeticItem> onLockedTap;

  @override
  Widget build(BuildContext context) {
    final List<CosmeticItem> arenas = GameEconomyCatalog.arenas;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '01  PILIH ARENA',
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
            'Mau bertanding di mana?',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: const Color(0xFF17233F),
              fontSize: compact ? 27 : 31,
              height: 1.05,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            profileTarget == null
                ? 'Setiap arena memiliki kelompok soal yang berbeda.'
                : 'Tujuan ${profileTarget!.label} aktif. Arena lain terkunci '
                      'agar materi dan lawan tetap sesuai tujuan belajarmu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: const Color(0xFF667085),
              fontSize: 12.5,
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          _ArenaShowcase(arena: selectedArena, compact: compact),
          SizedBox(height: compact ? 12 : 16),
          Row(
            children: <Widget>[
              for (int index = 0; index < arenas.length; index++) ...<Widget>[
                Expanded(
                  child: _ArenaOptionTile(
                    arena: arenas[index],
                    selected: arenas[index].id == selectedArena.id,
                    locked:
                        profileTarget != null &&
                        !profileTarget!.allowsArena(arenas[index].id),
                    onTap: () {
                      final CosmeticItem arena = arenas[index];
                      final bool locked =
                          profileTarget != null &&
                          !profileTarget!.allowsArena(arena.id);
                      locked ? onLockedTap(arena) : onSelect(arena);
                    },
                  ),
                ),
                if (index < arenas.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ArenaShowcase extends StatelessWidget {
  const _ArenaShowcase({required this.arena, required this.compact});

  final CosmeticItem arena;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('arena-selected-showcase'),
      height: compact ? 270 : 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0D49B5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF0A3D98), width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33063A91),
            blurRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            arena.assetPath!,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            cacheWidth: 1024,
            filterQuality: FilterQuality.low,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x0017233F), Color(0xCC101B35)],
                stops: <double>[0.45, 1],
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            left: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  arena.name,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: compact ? 24 : 27,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  arena.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFDCE8FF),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
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

class _ArenaOptionTile extends StatelessWidget {
  const _ArenaOptionTile({
    required this.arena,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final CosmeticItem arena;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !locked,
      label: locked ? '${arena.name}, terkunci' : arena.name,
      child: SizedBox(
        height: 78,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              top: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF91AFE4)
                      : const Color(0xFFD4D7DD),
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
            Positioned.fill(
              bottom: 5,
              child: Material(
                color: selected
                    ? const Color(0xFFE4EEFF)
                    : const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(17),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey<String>('arena-choice-${arena.id}'),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Opacity(
                            opacity: locked ? 0.42 : 1,
                            child: Image.asset(
                              arena.assetPath!,
                              fit: BoxFit.cover,
                              cacheWidth: 180,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                arena.name.replaceFirst('Arena ', ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.fredoka(
                                  color: locked
                                      ? const Color(0xFF7E8490)
                                      : const Color(0xFF173A67),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                locked
                                    ? 'Terkunci'
                                    : selected
                                    ? 'Terpilih'
                                    : 'Pilih',
                                style: GoogleFonts.dmSans(
                                  color: locked
                                      ? const Color(0xFF9A6A50)
                                      : selected
                                      ? const Color(0xFF2878F0)
                                      : const Color(0xFF7A8290),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          locked
                              ? Icons.lock_rounded
                              : selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: locked
                              ? const Color(0xFF8A8F9C)
                              : selected
                              ? const Color(0xFF2878F0)
                              : const Color(0xFF9AA1AD),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadoutPickerView extends StatelessWidget {
  const _LoadoutPickerView({
    required this.playerDisplayName,
    required this.economy,
    required this.selectedArena,
    required this.selectedCharacter,
    required this.selectedTower,
    required this.compact,
    required this.onSelect,
    required this.onLockedTap,
    super.key,
  });

  final String playerDisplayName;
  final GameEconomyState economy;
  final CosmeticItem selectedArena;
  final CosmeticItem selectedCharacter;
  final CosmeticItem selectedTower;
  final bool compact;
  final ValueChanged<CosmeticItem> onSelect;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    final String trimmedName = playerDisplayName.trim();
    final String firstName = trimmedName.isEmpty
        ? 'Kamu'
        : trimmedName.split(RegExp(r'\s+')).first;

    return Column(
      key: const ValueKey<String>('loadout-fixed-layout'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '02  SIAPKAN LOADOUT',
          style: GoogleFonts.dmSans(
            color: const Color(0xFF8B6B39),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Pilih jagoanmu, $firstName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.fredoka(
            color: const Color(0xFF17233F),
            fontSize: compact ? 27 : 31,
            height: 1.05,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        _LoadoutDiorama(
          selectedArena: selectedArena,
          selectedCharacter: selectedCharacter,
          selectedTower: selectedTower,
          compact: compact,
        ),
        SizedBox(height: compact ? 10 : 14),
        _LoadoutCardCarousel(
          title: 'Karakter',
          items: economy.characters,
          selectedId: selectedCharacter.id,
          economy: economy,
          compact: compact,
          onSelect: onSelect,
          onLockedTap: onLockedTap,
        ),
        SizedBox(height: compact ? 9 : 12),
        _LoadoutCardCarousel(
          title: 'Tower',
          items: economy.towers,
          selectedId: selectedTower.id,
          economy: economy,
          compact: compact,
          onSelect: onSelect,
          onLockedTap: onLockedTap,
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

class _LoadoutDiorama extends StatelessWidget {
  const _LoadoutDiorama({
    required this.selectedArena,
    required this.selectedCharacter,
    required this.selectedTower,
    required this.compact,
  });

  final CosmeticItem selectedArena;
  final CosmeticItem selectedCharacter;
  final CosmeticItem selectedTower;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 180 : 208,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8D0C1)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x24735B39),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Transform.scale(
            key: const ValueKey<String>('loadout-arena-blur'),
            scale: 1.04,
            child: Image.asset(
              selectedArena.assetPath!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              cacheWidth: 1024,
              filterQuality: FilterQuality.low,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0x3317233F), Color(0x8A17233F)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 13,
              compact ? 10 : 13,
              compact ? 10 : 13,
              compact ? 9 : 11,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _LoadoutPreviewSlot(
                    typeLabel: 'KARAKTER',
                    name: selectedCharacter.name,
                    assetPath: selectedCharacter.characterVisuals!.ready,
                    labelKey: const ValueKey<String>('loadout-character-label'),
                    previewKey: const ValueKey<String>(
                      'loadout-character-preview',
                    ),
                    nameFirst: true,
                    scale: 1.08 * _characterPreviewScale(selectedCharacter),
                  ),
                ),
                Container(
                  width: 1,
                  margin: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 11,
                    vertical: 5,
                  ),
                  color: const Color(0x5CFFFFFF),
                ),
                Expanded(
                  child: _LoadoutPreviewSlot(
                    typeLabel: 'TOWER',
                    name: selectedTower.name,
                    assetPath: selectedTower.assetPath!,
                    labelKey: const ValueKey<String>('loadout-tower-label'),
                    previewKey: const ValueKey<String>('loadout-tower-preview'),
                    nameFirst: true,
                    scale: 0.92,
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

class _LoadoutPreviewSlot extends StatelessWidget {
  const _LoadoutPreviewSlot({
    required this.typeLabel,
    required this.name,
    required this.assetPath,
    required this.labelKey,
    required this.previewKey,
    required this.nameFirst,
    required this.scale,
  });

  final String typeLabel;
  final String name;
  final String assetPath;
  final Key labelKey;
  final Key previewKey;
  final bool nameFirst;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final Widget label = SizedBox(
      key: labelKey,
      height: 38,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: nameFirst
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            typeLabel,
            style: GoogleFonts.dmSans(
              color: const Color(0xBFFFFFFF),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: nameFirst ? TextAlign.left : TextAlign.right,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w700,
              shadows: const <Shadow>[
                Shadow(color: Color(0x7A000000), blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
    final Widget preview = Expanded(
      child: ClipRect(
        key: previewKey,
        child: Transform.scale(
          scale: scale,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            cacheWidth: 480,
            filterQuality: FilterQuality.low,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: nameFirst
          ? <Widget>[label, const SizedBox(height: 2), preview]
          : <Widget>[preview, const SizedBox(height: 2), label],
    );
  }
}

class _LoadoutCardCarousel extends StatefulWidget {
  const _LoadoutCardCarousel({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.economy,
    required this.compact,
    required this.onSelect,
    required this.onLockedTap,
  });

  final String title;
  final List<CosmeticItem> items;
  final String selectedId;
  final GameEconomyState economy;
  final bool compact;
  final ValueChanged<CosmeticItem> onSelect;
  final VoidCallback onLockedTap;

  @override
  State<_LoadoutCardCarousel> createState() => _LoadoutCardCarouselState();
}

class _LoadoutCardCarouselState extends State<_LoadoutCardCarousel> {
  static const double _cardWidth = 94;
  static const double _cardSpacing = 10;

  final ScrollController _scrollController = ScrollController();
  late int _focusedIndex;

  @override
  void initState() {
    super.initState();
    _focusedIndex = _selectedIndex();
    _scheduleScrollToFocus(jump: true);
  }

  @override
  void didUpdateWidget(covariant _LoadoutCardCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId &&
        widget.items[_focusedIndex].id != widget.selectedId) {
      _focusedIndex = _selectedIndex();
      _scheduleScrollToFocus();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _selectedIndex() {
    final int index = widget.items.indexWhere(
      (CosmeticItem item) => item.id == widget.selectedId,
    );
    return index < 0 ? 0 : index;
  }

  void _focusItem(int index) {
    setState(() => _focusedIndex = index);
    _scheduleScrollToFocus();
    final CosmeticItem item = widget.items[index];
    if (widget.economy.owns(item.id)) {
      widget.onSelect(item);
    } else {
      widget.onLockedTap();
    }
  }

  void _scheduleScrollToFocus({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final double target = (_focusedIndex * (_cardWidth + _cardSpacing))
          .clamp(0, _scrollController.position.maxScrollExtent)
          .toDouble();
      if (jump) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final int ownedCount = widget.items
        .where((CosmeticItem item) => widget.economy.owns(item.id))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              widget.title,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF17233F),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: widget.onLockedTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  '$ownedCount dimiliki \u2022 Lihat Store',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF6E7F9E),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: widget.compact ? 108 : 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ListView.separated(
              key: ValueKey<String>(
                'loadout-${widget.title.toLowerCase()}-carousel',
              ),
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: _cardSpacing),
              itemBuilder: (BuildContext context, int index) {
                final CosmeticItem item = widget.items[index];
                return _LoadoutPortraitCard(
                  cardKey: ValueKey<String>('loadout-${item.id}'),
                  item: item,
                  selected: item.id == widget.selectedId,
                  focused: index == _focusedIndex,
                  owned: widget.economy.owns(item.id),
                  compact: widget.compact,
                  onTap: () => _focusItem(index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadoutPortraitCard extends StatelessWidget {
  const _LoadoutPortraitCard({
    required this.cardKey,
    required this.item,
    required this.selected,
    required this.focused,
    required this.owned,
    required this.compact,
    required this.onTap,
  });

  final Key cardKey;
  final CosmeticItem item;
  final bool selected;
  final bool focused;
  final bool owned;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool character = item.type == CosmeticType.character;
    return SizedBox(
      width: _LoadoutCardCarouselState._cardWidth,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF91AFE4)
                    : const Color(0xFFD1D5DC),
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
          Positioned.fill(
            bottom: 4,
            child: Material(
              color: selected
                  ? const Color(0xFFE4EEFF)
                  : owned
                  ? Colors.white
                  : const Color(0xFFF0F1F3),
              borderRadius: BorderRadius.circular(17),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: cardKey,
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: focused
                          ? const Color(0xFF2878F0)
                          : const Color(0xFFE1DDD5),
                      width: focused ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: SizedBox(
                          key: ValueKey<String>('loadout-preview-${item.id}'),
                          width: double.infinity,
                          child: Opacity(
                            opacity: owned ? 1 : 0.48,
                            child: Transform.scale(
                              scale: character
                                  ? 0.88 * _characterPreviewScale(item)
                                  : 0.72,
                              child: Image.asset(
                                item.assetPath!,
                                fit: BoxFit.contain,
                                cacheWidth: character ? 300 : 220,
                                filterQuality: FilterQuality.low,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: owned
                              ? const Color(0xFF173A67)
                              : const Color(0xFF858B96),
                          fontSize: compact ? 8 : 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              key: owned ? null : ValueKey<String>('loadout-lock-${item.id}'),
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2878F0)
                    : const Color(0xE6FFFFFF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                selected
                    ? Icons.check_rounded
                    : owned
                    ? Icons.inventory_2_outlined
                    : Icons.lock_rounded,
                color: selected ? Colors.white : const Color(0xFF747B87),
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _characterPreviewScale(CosmeticItem item) {
  return switch (item.id) {
    'character-rare-ignis' || 'character-legend-luna' => 1.18,
    _ => 1,
  };
}
