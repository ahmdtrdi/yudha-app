part of '../pvp_page.dart';

enum _ArenaSetupStep { arena, loadout }

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
              balance: economy.yCoins,
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
            SizedBox(
              height: 54,
              child: FilledButton(
                key: ValueKey<String>(
                  step == _ArenaSetupStep.arena
                      ? 'continue-to-loadout'
                      : 'continue-to-mode',
                ),
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF173A67),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        step == _ArenaSetupStep.arena
                            ? 'Pilih karakter & tower'
                            : 'Lanjut pilih mode',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
  final int balance;
  final VoidCallback onBack;
  final VoidCallback onTopUp;
  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    final int activeStep = step == _ArenaSetupStep.arena ? 1 : 2;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 40,
          child: Row(
            children: <Widget>[
              if (step == _ArenaSetupStep.loadout)
                IconButton(
                  key: const ValueKey<String>('back-to-arena'),
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
                  step == _ArenaSetupStep.arena
                      ? 'Pilih arena'
                      : 'Siapkan loadout',
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
                onTap: onTopUp,
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
                        formatYCoins(balance),
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
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '01  PILIH ARENA',
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
            style: GoogleFonts.dmSans(
              color: const Color(0xFF667085),
              fontSize: 12.5,
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 13 : 18),
          SizedBox(
            height: compact ? 330 : 380,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double cardWidth = min<double>(
                  MediaQuery.sizeOf(context).width - 58,
                  334,
                );
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(right: 20),
                  itemCount: GameEconomyCatalog.arenas.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 13),
                  itemBuilder: (BuildContext context, int index) {
                    final CosmeticItem arena = GameEconomyCatalog.arenas[index];
                    final bool locked =
                        profileTarget != null &&
                        !profileTarget!.allowsArena(arena.id);
                    return _ArenaChoiceCard(
                      arena: arena,
                      selected: arena.id == selectedArena.id,
                      locked: locked,
                      width: cardWidth,
                      compact: compact,
                      onTap: () =>
                          locked ? onLockedTap(arena) : onSelect(arena),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaChoiceCard extends StatelessWidget {
  const _ArenaChoiceCard({
    required this.arena,
    required this.selected,
    required this.locked,
    required this.width,
    required this.compact,
    required this.onTap,
  });

  final CosmeticItem arena;
  final bool selected;
  final bool locked;
  final double width;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget arenaImage = Image.asset(
      arena.assetPath!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      cacheWidth: 1024,
      filterQuality: FilterQuality.low,
    );

    return Semantics(
      button: true,
      enabled: !locked,
      label: locked ? '${arena.name}, terkunci' : arena.name,
      child: Material(
        color: locked ? const Color(0xFFE5E7EB) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('arena-choice-${arena.id}'),
          onTap: onTap,
          child: Ink(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2878F0)
                    : locked
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFFE0D9CC),
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (locked)
                        ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0.62,
                            0,
                          ]),
                          child: arenaImage,
                        )
                      else
                        arenaImage,
                      if (selected)
                        const Positioned(
                          top: 13,
                          right: 13,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFF2878F0),
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      if (locked)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xDD374151),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'TERKUNCI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(15, compact ? 11 : 14, 15, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        arena.name,
                        style: GoogleFonts.fredoka(
                          color: locked
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF17233F),
                          fontSize: compact ? 20 : 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locked
                            ? 'Pindah tujuan Anda di Pengaturan jika ingin '
                                  'bermain di ${arena.name}.'
                            : arena.description,
                        maxLines: locked ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: locked
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF667085),
                          fontSize: locked ? 10.5 : 11.5,
                          height: 1.3,
                          fontWeight: locked
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
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

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
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
          SizedBox(height: compact ? 14 : 18),
          _LoadoutRail(
            title: 'Karakter',
            hint: 'Geser untuk melihat',
            items: GameEconomyCatalog.characters,
            selectedId: selectedCharacter.id,
            economy: economy,
            compact: compact,
            onSelect: onSelect,
            onLockedTap: onLockedTap,
          ),
          SizedBox(height: compact ? 12 : 16),
          _LoadoutRail(
            title: 'Tower',
            hint: 'Tower lain tersedia di Store',
            items: GameEconomyCatalog.towers,
            selectedId: selectedTower.id,
            economy: economy,
            compact: compact,
            onSelect: onSelect,
            onLockedTap: onLockedTap,
          ),
          const SizedBox(height: 4),
        ],
      ),
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
      height: compact ? 204 : 228,
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

class _LoadoutRail extends StatelessWidget {
  const _LoadoutRail({
    required this.title,
    required this.hint,
    required this.items,
    required this.selectedId,
    required this.economy,
    required this.compact,
    required this.onSelect,
    required this.onLockedTap,
  });

  final String title;
  final String hint;
  final List<CosmeticItem> items;
  final String selectedId;
  final GameEconomyState economy;
  final bool compact;
  final ValueChanged<CosmeticItem> onSelect;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    final bool characters = items.first.type == CosmeticType.character;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              title,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF17233F),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              hint,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF8A8F9C),
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: compact ? 108 : 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (BuildContext context, int index) {
              final CosmeticItem item = items[index];
              final bool owned = economy.owns(item.id);
              return _LoadoutChoiceCard(
                item: item,
                selected: item.id == selectedId,
                owned: owned,
                character: characters,
                onTap: owned ? () => onSelect(item) : onLockedTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LoadoutChoiceCard extends StatelessWidget {
  const _LoadoutChoiceCard({
    required this.item,
    required this.selected,
    required this.owned,
    required this.character,
    required this.onTap,
  });

  final CosmeticItem item;
  final bool selected;
  final bool owned;
  final bool character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF2FC) : Colors.white,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('loadout-${item.id}'),
        onTap: onTap,
        child: Ink(
          width: 108,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2878F0)
                  : const Color(0xFFE2DDD3),
              width: 2,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      key: ValueKey<String>('loadout-preview-${item.id}'),
                      borderRadius: BorderRadius.circular(10),
                      child: ColoredBox(
                        color: selected
                            ? const Color(0xFFDCE9FA)
                            : const Color(0xFFF4F0E8),
                        child: Opacity(
                          opacity: owned ? 1 : 0.56,
                          child: Transform.scale(
                            scale: character
                                ? _characterPreviewScale(item)
                                : 0.84,
                            child: Image.asset(
                              item.assetPath!,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              cacheWidth: character ? 320 : 240,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF17233F),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 4,
                right: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2878F0)
                        : const Color(0xD9FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: Icon(
                      selected
                          ? Icons.check_rounded
                          : owned
                          ? Icons.inventory_2_outlined
                          : Icons.lock_outline_rounded,
                      color: selected ? Colors.white : const Color(0xFF5F6673),
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
