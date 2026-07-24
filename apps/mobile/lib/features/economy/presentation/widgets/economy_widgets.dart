import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/arena_visual_theme.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';

String formatYCoins(int value) {
  final String digits = value.toString();
  final StringBuffer result = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    final int remaining = digits.length - index;
    result.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      result.write('.');
    }
  }
  return result.toString();
}

class YCoinMark extends StatelessWidget {
  const YCoinMark({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFE8A6), width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33573705),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'Y',
        style: GoogleFonts.fredoka(
          color: const Color(0xFF6E4809),
          fontSize: size * 0.54,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class YCoinBalanceChip extends StatelessWidget {
  const YCoinBalanceChip({
    required this.balance,
    this.onTap,
    this.dark = false,
    super.key,
  });

  final int balance;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? Colors.white.withAlpha(24) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          key: const ValueKey<String>('y-coin-balance'),
          padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: dark
                  ? Colors.white.withAlpha(60)
                  : AppColors.warriorNavy.withAlpha(24),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const YCoinMark(size: 22),
              const SizedBox(width: 6),
              Text(
                formatYCoins(balance),
                style: GoogleFonts.jetBrainsMono(
                  color: dark ? Colors.white : AppColors.textStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: 3),
                Icon(
                  Icons.add_circle_rounded,
                  size: 16,
                  color: dark ? const Color(0xFFFFC857) : AppColors.levelUpTeal,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CosmeticPreview extends StatelessWidget {
  const CosmeticPreview({
    required this.item,
    this.heroAlignment = Alignment.topCenter,
    super.key,
  });

  final CosmeticItem item;
  final Alignment heroAlignment;

  @override
  Widget build(BuildContext context) {
    if (item.type == CosmeticType.character && item.assetPath != null) {
      return Image.asset(
        item.assetPath!,
        fit: BoxFit.contain,
        alignment: heroAlignment,
        cacheWidth: 480,
        filterQuality: FilterQuality.low,
      );
    }

    if (item.assetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          item.assetPath!,
          fit: item.type == CosmeticType.arena ? BoxFit.cover : BoxFit.contain,
          alignment: Alignment.center,
          cacheWidth: item.type == CosmeticType.arena ? 640 : 320,
          filterQuality: FilterQuality.low,
        ),
      );
    }

    final ArenaVisualTheme theme = ArenaVisualTheme.fromId(item.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _ArenaPreviewPainter(theme),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArenaPreviewPainter extends CustomPainter {
  const _ArenaPreviewPainter(this.theme);

  final ArenaVisualTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..isAntiAlias = true;
    paint.color = theme.field;
    canvas.drawRect(Offset.zero & size, paint);
    paint.color = theme.fieldAccent.withAlpha(90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, 0, size.width * 0.18, size.height),
        const Radius.circular(16),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.70, 0, size.width * 0.18, size.height),
        const Radius.circular(16),
      ),
      paint,
    );
    final double riverTop = size.height * 0.42;
    final double riverHeight = size.height * 0.20;
    paint.color = theme.riverEdge;
    canvas.drawRect(
      Rect.fromLTWH(0, riverTop - 3, size.width, riverHeight + 6),
      paint,
    );
    paint.color = theme.river;
    canvas.drawRect(Rect.fromLTWH(0, riverTop, size.width, riverHeight), paint);
    final Rect bridge = Rect.fromCenter(
      center: Offset(size.width / 2, riverTop + riverHeight / 2),
      width: size.width * 0.28,
      height: riverHeight + 12,
    );
    paint.color = theme.bridge;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bridge, const Radius.circular(7)),
      paint,
    );
    paint.color = theme.bridgeLine;
    paint.strokeWidth = 1.5;
    for (int index = 1; index < 3; index++) {
      final double x = bridge.left + bridge.width * index / 3;
      canvas.drawLine(
        Offset(x, bridge.top + 3),
        Offset(x, bridge.bottom - 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaPreviewPainter oldDelegate) {
    return oldDelegate.theme.id != theme.id;
  }
}

Future<void> showYCoinTopUpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const _YCoinTopUpSheet(),
  );
}

class _YCoinTopUpSheet extends ConsumerStatefulWidget {
  const _YCoinTopUpSheet();

  @override
  ConsumerState<_YCoinTopUpSheet> createState() => _YCoinTopUpSheetState();
}

class _YCoinTopUpSheetState extends ConsumerState<_YCoinTopUpSheet> {
  String? _pendingPackageId;

  Future<void> _topUp(YCoinTopUpPackage package) async {
    if (_pendingPackageId != null) {
      return;
    }
    setState(() {
      _pendingPackageId = package.id;
    });
    try {
      final EconomyActionResult result = await ref
          .read(gameEconomyProvider.notifier)
          .topUpAuthoritative(package);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) {
        setState(() {
          _pendingPackageId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int balance = ref.watch(
      gameEconomyProvider.select((state) => state.yCoins),
    );
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.warriorNavy.withAlpha(35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Top up Y-Coin',
                        style: GoogleFonts.fredoka(
                          color: AppColors.textStrong,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Saldo beta saat ini',
                        style: GoogleFonts.dmSans(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                YCoinBalanceChip(balance: balance),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD77B)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.science_rounded, color: Color(0xFF865710)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Beta sandbox: belum ada pembayaran nyata. Semua paket langsung menambah saldo uji.',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF6E4B12),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: GameEconomyCatalog.topUpPackages
                      .map(
                        (YCoinTopUpPackage package) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TopUpPackageTile(
                            package: package,
                            isLoading: _pendingPackageId == package.id,
                            onTap: _pendingPackageId == null
                                ? () => _topUp(package)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopUpPackageTile extends StatelessWidget {
  const _TopUpPackageTile({
    required this.package,
    required this.isLoading,
    required this.onTap,
  });

  final YCoinTopUpPackage package;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool beta = package.isBetaCredit;
    return Material(
      color: beta ? const Color(0xFFE8F7F1) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey<String>('top-up-${package.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: beta
                  ? AppColors.levelUpTeal.withAlpha(80)
                  : AppColors.warriorNavy.withAlpha(22),
            ),
          ),
          child: Row(
            children: <Widget>[
              const YCoinMark(size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '+${formatYCoins(package.totalCoins)} Y-Coin',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (package.bonusCoins > 0)
                      Text(
                        'Termasuk bonus +${package.bonusCoins}',
                        style: GoogleFonts.dmSans(
                          color: AppColors.levelUpTeal,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (beta)
                      Text(
                        'Bisa ditekan sepuasnya selama beta',
                        style: GoogleFonts.dmSans(
                          color: AppColors.levelUpTeal,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isLoading
                    ? const SizedBox(
                        key: ValueKey<String>('top-up-loading'),
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: AppColors.levelUpTeal,
                        ),
                      )
                    : Container(
                        key: const ValueKey<String>('top-up-price'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: beta
                              ? AppColors.levelUpTeal
                              : AppColors.warriorNavy,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          package.priceLabel,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
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
