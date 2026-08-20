import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';

class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  String? _pendingMessage;

  bool get _isTransactionPending => _pendingMessage != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(gameEconomyProvider.notifier).refresh());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final GameEconomyState economy = ref.watch(gameEconomyProvider);

    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: !_isTransactionPending,
        child: Scaffold(
          backgroundColor: AppColors.scholarCream,
          appBar: AppBar(
            leading: IconButton(
              onPressed: _isTransactionPending ? null : () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text('STORE'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: YCoinBalanceChip(
                    balance: economy.isAuthoritative ? economy.yCoins : null,
                    onTap: _isTransactionPending || !economy.isAuthoritative
                        ? null
                        : () => showYCoinTopUpSheet(context),
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
          body: Stack(
            children: <Widget>[
              AbsorbPointer(
                absorbing: _isTransactionPending,
                child: Column(
                  children: <Widget>[
                    if (!economy.isAuthoritative)
                      _EconomySyncBanner(
                        economy: economy,
                        onRetry: () =>
                            ref.read(gameEconomyProvider.notifier).refresh(),
                      ),
                    _StoreIntro(
                      onPassTap: () => context.push(AppRoutes.hiredPass),
                      onTopUpTap: () => showYCoinTopUpSheet(context),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: <Widget>[
                          _CosmeticGrid(
                            items: economy.characters,
                            economy: economy,
                            authoritative: economy.isAuthoritative,
                            onItemTap: (CosmeticItem item) =>
                                _handleItemTap(item, economy),
                          ),
                          _CosmeticGrid(
                            items: economy.towers,
                            economy: economy,
                            authoritative: economy.isAuthoritative,
                            onItemTap: (CosmeticItem item) =>
                                _handleItemTap(item, economy),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_pendingMessage case final String message)
                Positioned.fill(
                  child: ColoredBox(
                    key: const ValueKey<String>('store-transaction-loading'),
                    color: AppColors.warriorNavy.withAlpha(70),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.levelUpTeal,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                color: AppColors.textStrong,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jangan tutup halaman ini.',
                              style: GoogleFonts.dmSans(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
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
      ),
    );
  }

  Future<void> _handleItemTap(
    CosmeticItem item,
    GameEconomyState economy,
  ) async {
    if (_isTransactionPending) {
      return;
    }
    if (!economy.isAuthoritative) {
      _showResult(
        context,
        const EconomyActionResult(
          success: false,
          message:
              'Sinkronisasi ekonomi belum tersedia. Muat ulang lalu coba lagi.',
        ),
      );
      return;
    }
    if (item.passExclusive && !economy.owns(item.id)) {
      context.push(AppRoutes.hiredPass);
      return;
    }

    final GameEconomyController controller = ref.read(
      gameEconomyProvider.notifier,
    );
    if (economy.owns(item.id)) {
      setState(() {
        _pendingMessage = 'Memasang ${item.name}...';
      });
      try {
        final EconomyActionResult result = await controller.equipAuthoritative(
          item,
        );
        if (mounted) {
          _showResult(context, result);
        }
      } finally {
        if (mounted) {
          setState(() {
            _pendingMessage = null;
          });
        }
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
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _pendingMessage = 'Memproses pembelian ${item.name}...';
    });
    try {
      final EconomyActionResult result = await controller.purchaseAuthoritative(
        item,
      );
      if (mounted) {
        _showResult(context, result);
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingMessage = null;
        });
      }
    }
  }

  void _showResult(BuildContext context, EconomyActionResult result) {
    final String normalizedMessage = result.message.toLowerCase();
    final bool shouldOfferTopUp =
        !result.success &&
        normalizedMessage.contains('y-coin') &&
        (normalizedMessage.contains('cukup') ||
            normalizedMessage.contains('saldo'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? AppColors.levelUpTeal
              : const Color(0xFFB64040),
          action: !shouldOfferTopUp
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

class _EconomySyncBanner extends StatelessWidget {
  const _EconomySyncBanner({required this.economy, required this.onRetry});

  final GameEconomyState economy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool loading = economy.syncStatus == EconomySyncStatus.loading;
    return Container(
      key: const ValueKey<String>('store-economy-sync-banner'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: loading ? const Color(0xFFE8F2FF) : const Color(0xFFFFECE8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.cloud_off_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading
                  ? 'Menyinkronkan Store…'
                  : economy.syncErrorMessage ??
                        'Sinkronisasi Store tidak tersedia.',
            ),
          ),
          if (!loading)
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
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
    required this.authoritative,
    required this.onItemTap,
  });

  final List<CosmeticItem> items;
  final GameEconomyState economy;
  final bool authoritative;
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
              authoritative: authoritative,
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
    required this.authoritative,
    required this.onTap,
  });

  final CosmeticItem item;
  final bool owned;
  final bool equipped;
  final bool authoritative;
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
                      authoritative: authoritative,
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
    required this.authoritative,
  });

  final CosmeticItem item;
  final bool owned;
  final bool equipped;
  final bool authoritative;

  @override
  Widget build(BuildContext context) {
    if (!authoritative) {
      return _actionLine(
        'Sinkronisasi diperlukan',
        AppColors.textMuted,
        Icons.sync_problem_rounded,
      );
    }
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
      children: <Widget>[
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
