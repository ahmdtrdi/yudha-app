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
    required this.onSelectCosmetic,
    required this.onSelectArena,
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
  final ValueChanged<CosmeticItem> onSelectCosmetic;
  final ValueChanged<CosmeticItem> onSelectArena;
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
            SizedBox(height: compact ? 12 : 18),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: step == _ArenaSetupStep.arena
                    ? _ArenaPickerView(
                        key: const ValueKey<String>('arena-step'),
                        selectedArena: selectedArena,
                        compact: compact,
                        onSelect: onSelectArena,
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
        Row(
          children: <Widget>[
            if (step == _ArenaSetupStep.loadout)
              IconButton(
                key: const ValueKey<String>('back-to-arena'),
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF17233F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              )
            else
              const SizedBox(width: 48),
            const Spacer(),
            InkWell(
              onTap: onTopUp,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  children: <Widget>[
                    const YCoinMark(size: 22),
                    const SizedBox(width: 6),
                    Text(
                      formatYCoins(balance),
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.textStrong,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            IconButton(
              key: const ValueKey<String>('pvp-open-store'),
              onPressed: onOpenStore,
              tooltip: 'Buka Store',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF173A67),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.storefront_outlined, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
    required this.compact,
    required this.onSelect,
    super.key,
  });

  final CosmeticItem selectedArena;
  final bool compact;
  final ValueChanged<CosmeticItem> onSelect;

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
            'Setiap arena memiliki kelompok soal yang berbeda. Arena bebas dipilih dan tidak perlu dibeli.',
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
                    return _ArenaChoiceCard(
                      arena: arena,
                      selected: arena.id == selectedArena.id,
                      width: cardWidth,
                      compact: compact,
                      onTap: () => onSelect(arena),
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
    required this.width,
    required this.compact,
    required this.onTap,
  });

  final CosmeticItem arena;
  final bool selected;
  final double width;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
                    Image.asset(
                      arena.assetPath!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                    ),
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
                        color: const Color(0xFF17233F),
                        fontSize: compact ? 20 : 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      arena.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF667085),
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      height: compact ? 210 : 242,
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
          Image.asset(
            selectedArena.assetPath!,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x0D000000), Color(0xB817233F)],
                stops: <double>[0.42, 1],
              ),
            ),
          ),
          Positioned(
            left: compact ? 38 : 48,
            bottom: -7,
            width: compact ? 190 : 220,
            height: compact ? 196 : 226,
            child: Image.asset(
              selectedCharacter.characterVisuals!.ready,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned(
            right: 12,
            bottom: compact ? 22 : 26,
            width: compact ? 80 : 94,
            height: compact ? 80 : 94,
            child: Image.asset(
              selectedTower.assetPath!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned(
            left: 15,
            right: 15,
            bottom: 12,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    selectedCharacter.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      shadows: const <Shadow>[
                        Shadow(color: Color(0x99000000), blurRadius: 7),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 92),
                Text(
                  selectedTower.name,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    shadows: const <Shadow>[
                      Shadow(color: Color(0x99000000), blurRadius: 7),
                    ],
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
          height: characters
              ? compact
                    ? 104
                    : 116
              : compact
              ? 84
              : 94,
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
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('loadout-${item.id}'),
        onTap: onTap,
        child: Ink(
          width: character ? 112 : 158,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2878F0)
                  : const Color(0xFFE2DDD3),
              width: selected ? 2 : 1,
            ),
          ),
          child: character
              ? Stack(
                  children: <Widget>[
                    Positioned.fill(
                      bottom: 18,
                      child: Image.asset(
                        item.assetPath!,
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF17233F),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!owned)
                      const Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF717784),
                          size: 16,
                        ),
                      ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    SizedBox(
                      width: 62,
                      child: Image.asset(
                        item.assetPath!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: const Color(0xFF17233F),
                              fontSize: 10.5,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            selected
                                ? Icons.check_rounded
                                : owned
                                ? Icons.inventory_2_outlined
                                : Icons.lock_outline_rounded,
                            color: selected
                                ? const Color(0xFF2878F0)
                                : const Color(0xFF717784),
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
