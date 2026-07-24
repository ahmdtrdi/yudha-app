import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';

class StorePage extends ConsumerWidget {
  const StorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameEconomyState economy = ref.watch(gameEconomyProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('STORE'),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: YCoinBalanceChip(
                  balance: economy.yCoins,
                  onTap: () => showYCoinTopUpSheet(context),
                  dark: true,
                ),
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.fireGold,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withAlpha(170),
            labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
            tabs: const <Widget>[
              Tab(text: 'Karakter'),
              Tab(text: 'Tower'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            _StoreIntro(
              onPassTap: () => context.push(AppRoutes.hiredPass),
              onTopUpTap: () => showYCoinTopUpSheet(context),
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _CosmeticGrid(
                    items: GameEconomyCatalog.characters,
                    economy: economy,
                    onItemTap: (CosmeticItem item) =>
                        _handleItemTap(context, ref, item, economy),
                  ),
                  _CosmeticGrid(
                    items: GameEconomyCatalog.towers,
                    economy: economy,
                    onItemTap: (CosmeticItem item) =>
                        _handleItemTap(context, ref, item, economy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleItemTap(
    BuildContext context,
    WidgetRef ref,
    CosmeticItem item,
    GameEconomyState economy,
  ) async {
    if (item.passExclusive && !economy.owns(item.id)) {
      context.push(AppRoutes.hiredPass);
      return;
    }

    final GameEconomyController controller = ref.read(
      gameEconomyProvider.notifier,
    );
    if (economy.owns(item.id)) {
      final EconomyActionResult result = await controller.equipAuthoritative(
        item,
      );
      if (context.mounted) {
        _showResult(context, result);
      }
      return;
    }

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(
              'Beli ${item.name}?',
              style: GoogleFonts.fredoka(fontWeight: FontWeight.w700),
            ),
            content: Row(
              children: <Widget>[
                const YCoinMark(size: 30),
                const SizedBox(width: 10),
                Text(
                  '${formatYCoins(item.price)} Y-Coin',
                  style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Nanti'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Beli & pakai'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    final EconomyActionResult result = await controller.purchaseAuthoritative(
      item,
    );
    if (context.mounted) {
      _showResult(context, result);
    }
  }

  void _showResult(BuildContext context, EconomyActionResult result) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? AppColors.levelUpTeal
              : const Color(0xFFB64040),
          action: result.success
              ? null
              : SnackBarAction(
                  label: 'TOP UP',
                  textColor: Colors.white,
                  onPressed: () => showYCoinTopUpSheet(context),
                ),
        ),
      );
  }
}

class _StoreIntro extends StatelessWidget {
  const _StoreIntro({required this.onPassTap, required this.onTopUpTap});

  final VoidCallback onPassTap;
  final VoidCallback onTopUpTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warriorNavy.withAlpha(20)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0C7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.castle_outlined,
                color: Color(0xFF9A6413),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Bangun loadout favoritmu',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Karakter dan tower bersifat kosmetik dan permanen.',
                    style: GoogleFonts.dmSans(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Aksi Store',
              onSelected: (String value) {
                if (value == 'pass') {
                  onPassTap();
                } else {
                  onTopUpTap();
                }
              },
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'topup',
                      child: Text('Top up Y-Coin'),
                    ),
                    PopupMenuItem<String>(
                      value: 'pass',
                      child: Text('Buka Hired Pass'),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CosmeticGrid extends StatelessWidget {
  const _CosmeticGrid({
    required this.items,
    required this.economy,
    required this.onItemTap,
  });

  final List<CosmeticItem> items;
  final GameEconomyState economy;
  final ValueChanged<CosmeticItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 680 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final CosmeticItem item = items[index];
            final bool owned = economy.owns(item.id);
            final bool equipped = switch (item.type) {
              CosmeticType.character => economy.equippedCharacterId == item.id,
              CosmeticType.tower => economy.equippedTowerId == item.id,
              CosmeticType.arena => false,
            };
            return _CosmeticCard(
              item: item,
              owned: owned,
              equipped: equipped,
              onTap: () => onItemTap(item),
            );
          },
        );
      },
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  final CosmeticItem item;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = switch (item.rarity) {
      CosmeticRarity.common => const Color(0xFF7B879C),
      CosmeticRarity.rare => const Color(0xFF2878F0),
      CosmeticRarity.epic => const Color(0xFF8B6FE8),
      CosmeticRarity.legendary => const Color(0xFFF0A436),
    };
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: ValueKey<String>('store-item-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: equipped
                  ? AppColors.levelUpTeal
                  : rarityColor.withAlpha(75),
              width: equipped ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: rarityColor.withAlpha(18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.all(
                        item.type == CosmeticType.character ? 2 : 9,
                      ),
                      child: CosmeticPreview(item: item),
                    ),
                    if (equipped)
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.levelUpTeal,
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 3, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textStrong,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StoreItemAction(
                      item: item,
                      owned: owned,
                      equipped: equipped,
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

class _StoreItemAction extends StatelessWidget {
  const _StoreItemAction({
    required this.item,
    required this.owned,
    required this.equipped,
  });

  final CosmeticItem item;
  final bool owned;
  final bool equipped;

  @override
  Widget build(BuildContext context) {
    if (equipped) {
      return _actionLine('Dipakai', AppColors.levelUpTeal, Icons.check_rounded);
    }
    if (owned) {
      return _actionLine(
        'Pakai',
        AppColors.warriorNavy,
        Icons.checkroom_rounded,
      );
    }
    if (item.passExclusive) {
      return _actionLine(
        'Hired Pass',
        const Color(0xFF8B6FE8),
        Icons.workspace_premium_rounded,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const YCoinMark(size: 20),
        const SizedBox(width: 5),
        Text(
          formatYCoins(item.price),
          style: GoogleFonts.jetBrainsMono(
            color: AppColors.textStrong,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _actionLine(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
