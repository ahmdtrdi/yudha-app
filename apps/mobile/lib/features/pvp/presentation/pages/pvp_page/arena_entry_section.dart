part of '../pvp_page.dart';

class _ArenaEntrySection extends StatelessWidget {
  const _ArenaEntrySection({
    required this.playerDisplayName,
    required this.economy,
    required this.selectedCharacter,
    required this.selectedArena,
    required this.onSelectCosmetic,
    required this.onOpenStore,
    required this.onTopUp,
    required this.onEnterArena,
  });

  final String playerDisplayName;
  final GameEconomyState economy;
  final CosmeticItem selectedCharacter;
  final CosmeticItem selectedArena;
  final ValueChanged<CosmeticItem> onSelectCosmetic;
  final VoidCallback onOpenStore;
  final VoidCallback onTopUp;
  final VoidCallback onEnterArena;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxHeight < 690;
        final String trimmedName = playerDisplayName.trim();
        final String firstName = trimmedName.isEmpty
            ? 'Kamu'
            : trimmedName.split(RegExp(r'\s+')).first;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(2, compact ? 2 : 6, 2, 4),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: max<double>(0, constraints.maxHeight - 8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _EntryTopBar(
                  balance: economy.yCoins,
                  onTopUp: onTopUp,
                  onOpenStore: onOpenStore,
                ),
                SizedBox(height: compact ? 10 : 14),
                Text(
                  'Siapkan loadout, $firstName',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fredoka(
                    color: const Color(0xFF17233F),
                    fontSize: compact ? 25 : 29,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Pilih karakter dan arena sebelum mencari lawan.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF667085),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: compact ? 10 : 14),
                _EntryLoadoutDiorama(
                  selectedCharacter: selectedCharacter,
                  selectedArena: selectedArena,
                  compact: compact,
                ),
                SizedBox(height: compact ? 11 : 15),
                _LoadoutSelector(
                  title: 'Karakter',
                  icon: Icons.person_rounded,
                  items: GameEconomyCatalog.characters,
                  selectedId: selectedCharacter.id,
                  economy: economy,
                  onSelect: onSelectCosmetic,
                  onLockedTap: onOpenStore,
                  compact: compact,
                ),
                SizedBox(height: compact ? 9 : 12),
                _LoadoutSelector(
                  title: 'Arena',
                  icon: Icons.stadium_rounded,
                  items: GameEconomyCatalog.arenas,
                  selectedId: selectedArena.id,
                  economy: economy,
                  onSelect: onSelectCosmetic,
                  onLockedTap: onOpenStore,
                  compact: compact,
                ),
                SizedBox(height: compact ? 12 : 18),
                _EntryPrimaryButton(onPressed: onEnterArena),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EntryTopBar extends StatelessWidget {
  const _EntryTopBar({
    required this.balance,
    required this.onTopUp,
    required this.onOpenStore,
  });

  final int balance;
  final VoidCallback onTopUp;
  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE8B0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.shield_rounded,
                size: 15,
                color: Color(0xFF9A6413),
              ),
              const SizedBox(width: 5),
              Text(
                'PVP LOADOUT',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF865710),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        YCoinBalanceChip(balance: balance, onTap: onTopUp),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          key: const ValueKey<String>('pvp-open-store'),
          onPressed: onOpenStore,
          tooltip: 'Buka Store',
          style: IconButton.styleFrom(
            minimumSize: const Size(38, 38),
            foregroundColor: AppColors.warriorNavy,
            backgroundColor: Colors.white,
          ),
          icon: const Icon(Icons.storefront_rounded, size: 20),
        ),
      ],
    );
  }
}

class _EntryLoadoutDiorama extends StatelessWidget {
  const _EntryLoadoutDiorama({
    required this.selectedCharacter,
    required this.selectedArena,
    required this.compact,
  });

  final CosmeticItem selectedCharacter;
  final CosmeticItem selectedArena;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 142 : 168,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
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
          CosmeticPreview(item: selectedArena),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withAlpha(10),
                    const Color(0xAA17233F),
                  ],
                  stops: const <double>[0.48, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 0,
            width: compact ? 126 : 150,
            height: compact ? 132 : 158,
            child: CosmeticPreview(item: selectedCharacter),
          ),
          Positioned(
            right: 16,
            top: 17,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  selectedCharacter.name,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: compact ? 18 : 21,
                    fontWeight: FontWeight.w700,
                    shadows: const <Shadow>[
                      Shadow(color: Color(0x66000000), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  constraints: const BoxConstraints(maxWidth: 145),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(225),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.stadium_rounded,
                        color: AppColors.levelUpTeal,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          selectedArena.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: AppColors.textStrong,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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

class _LoadoutSelector extends StatelessWidget {
  const _LoadoutSelector({
    required this.title,
    required this.icon,
    required this.items,
    required this.selectedId,
    required this.economy,
    required this.onSelect,
    required this.onLockedTap,
    required this.compact,
  });

  final String title;
  final IconData icon;
  final List<CosmeticItem> items;
  final String selectedId;
  final GameEconomyState economy;
  final ValueChanged<CosmeticItem> onSelect;
  final VoidCallback onLockedTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, color: AppColors.warriorNavy, size: 17),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.dmSans(
                color: AppColors.textStrong,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              'Tap untuk memilih',
              style: GoogleFonts.dmSans(
                color: AppColors.textMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: compact ? 62 : 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final CosmeticItem item = items[index];
              final bool owned = economy.owns(item.id);
              final bool selected = item.id == selectedId;
              return _LoadoutChoice(
                item: item,
                owned: owned,
                selected: selected,
                width: title == 'Karakter' ? 126 : 142,
                onTap: owned ? () => onSelect(item) : onLockedTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LoadoutChoice extends StatelessWidget {
  const _LoadoutChoice({
    required this.item,
    required this.owned,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final CosmeticItem item;
  final bool owned;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEAF2FE) : Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: ValueKey<String>('loadout-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2878F0)
                  : AppColors.warriorNavy.withAlpha(22),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                height: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: item.type == CosmeticType.character
                      ? CosmeticPreview(item: item)
                      : Padding(
                          padding: const EdgeInsets.all(2),
                          child: CosmeticPreview(item: item),
                        ),
                ),
              ),
              const SizedBox(width: 6),
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
                        color: AppColors.textStrong,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : owned
                              ? Icons.inventory_2_rounded
                              : Icons.lock_rounded,
                          size: 12,
                          color: selected
                              ? const Color(0xFF2878F0)
                              : owned
                              ? AppColors.levelUpTeal
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            selected
                                ? 'DIPILIH'
                                : owned
                                ? 'DIMILIKI'
                                : 'STORE',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: selected
                                  ? const Color(0xFF2878F0)
                                  : owned
                                  ? AppColors.levelUpTeal
                                  : AppColors.textMuted,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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
          height: 54,
          child: FilledButton(
            key: const ValueKey<String>('enter-arena-with-loadout'),
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
                  'Pilih lawan',
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
