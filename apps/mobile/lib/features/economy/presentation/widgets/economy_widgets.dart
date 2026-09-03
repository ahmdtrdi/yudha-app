import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/arena_visual_theme.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/payment_confirmation_modal.dart';

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

  final int? balance;
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
                balance == null ? '—' : formatYCoins(balance!),
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

class EnergyBalanceChip extends StatelessWidget {
  const EnergyBalanceChip({
    required this.energy,
    required this.isPro,
    this.maxEnergy = 100,
    this.onTap,
    this.dark = false,
    super.key,
  });

  final int? energy;
  final bool isPro;
  final int maxEnergy;
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
          key: const ValueKey<String>('energy-balance'),
          padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isPro
                  ? const Color(0xFFFFC857)
                  : (dark
                      ? Colors.white.withAlpha(60)
                      : AppColors.warriorNavy.withAlpha(24)),
              width: isPro ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.bolt_rounded,
                size: 20,
                color: isPro ? const Color(0xFFFFC857) : const Color(0xFFFF9800),
              ),
              const SizedBox(width: 4),
              Text(
                isPro
                    ? '∞'
                    : (energy == null ? '—' : '$energy'),
                style: GoogleFonts.jetBrainsMono(
                  color: isPro
                      ? const Color(0xFFFFC857)
                      : (dark ? Colors.white : AppColors.textStrong),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (onTap != null && !isPro) ...<Widget>[
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

class ProBadge extends StatelessWidget {
  const ProBadge({
    this.compact = false,
    this.onTap,
    super.key,
  });

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFFD700), Color(0xFFFF8C00)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x40FFD700),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.star_rounded,
              size: 14,
              color: Color(0xFF5A2A00),
            ),
            const SizedBox(width: 4),
            Text(
              'PRO',
              style: GoogleFonts.fredoka(
                color: const Color(0xFF5A2A00),
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
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

Future<void> showEnergyTopUpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const _EnergyTopUpSheet(),
  );
}

class _EnergyTopUpSheet extends ConsumerStatefulWidget {
  const _EnergyTopUpSheet();

  @override
  ConsumerState<_EnergyTopUpSheet> createState() => _EnergyTopUpSheetState();
}

class _EnergyTopUpSheetState extends ConsumerState<_EnergyTopUpSheet> {
  String? _pendingPackageId;

  Future<void> _buyPack(String packageId, String packageName, int cost) async {
    final GameEconomyState economy = ref.read(gameEconomyProvider);
    if (economy.yCoins < cost) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Y-Coin tidak cukup. Silakan top up Y-Coin terlebih dahulu.'),
          ),
        );
      return;
    }
    setState(() => _pendingPackageId = packageId);
    try {
      final EconomyActionResult result = await ref
          .read(gameEconomyProvider.notifier)
          .buyEnergyPackAuthoritative(packageId, packageName);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) setState(() => _pendingPackageId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameEconomyState economy = ref.watch(gameEconomyProvider);
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
                  color: AppColors.textMuted.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(Icons.bolt_rounded, color: Color(0xFFFF9800), size: 24),
                const SizedBox(width: 8),
                Text(
                  'Recharge Energy',
                  style: GoogleFonts.fredoka(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textStrong,
                  ),
                ),
                const Spacer(),
                YCoinBalanceChip(
                  balance: economy.isAuthoritative ? economy.yCoins : null,
                  onTap: () {
                    Navigator.pop(context);
                    showYCoinTopUpSheet(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFB85C1E), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Energi digunakan untuk masuk mode Solo & PvP (2 ⚡). Bebas isi ulang dengan Y-Coin!',
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
            _EnergyPackCard(
              title: '+5 Energy',
              costText: '50 Y-Coin',
              cost: 50,
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFFF9800),
              isLoading: _pendingPackageId == 'energy-5',
              onTap: economy.isPro || _pendingPackageId != null
                  ? null
                  : () => _buyPack('energy-5', '+5 Energy', 50),
            ),
            const SizedBox(height: 8),
            _EnergyPackCard(
              title: '+12 Energy',
              costText: '100 Y-Coin',
              cost: 100,
              badge: 'LEBIH HEMAT',
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFFFF9800),
              isLoading: _pendingPackageId == 'energy-12',
              onTap: economy.isPro || _pendingPackageId != null
                  ? null
                  : () => _buyPack('energy-12', '+12 Energy', 100),
            ),
            if (!economy.isPro && economy.energy < economy.maxEnergy && economy.nextRefillAt != null) ...<Widget>[
              const SizedBox(height: 12),
              _EnergyRefillTimer(nextRefillAt: economy.nextRefillAt!),
            ],
            const SizedBox(height: 12),
            if (economy.isPro)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF22C55E)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Kamu memiliki YUDHA Pro (Energi Tak Terbatas)',
                      style: GoogleFonts.fredoka(
                        color: const Color(0xFF15803D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EnergyPackCard extends StatelessWidget {
  const _EnergyPackCard({
    required this.title,
    required this.costText,
    required this.cost,
    required this.icon,
    required this.iconColor,
    required this.isLoading,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String costText;
  final int cost;
  final IconData icon;
  final Color iconColor;
  final bool isLoading;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.warriorNavy.withAlpha(20)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          title,
                          style: GoogleFonts.fredoka(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textStrong,
                          ),
                        ),
                        if (badge != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: GoogleFonts.fredoka(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      costText,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6E4809)),
                  ),
                  child: Text(
                    'BELI',
                    style: GoogleFonts.fredoka(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF5A2A00),
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

class _EnergyRefillTimer extends StatefulWidget {
  const _EnergyRefillTimer({required this.nextRefillAt});

  final DateTime nextRefillAt;

  @override
  State<_EnergyRefillTimer> createState() => _EnergyRefillTimerState();
}

class _EnergyRefillTimerState extends State<_EnergyRefillTimer> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final Duration diff = widget.nextRefillAt.difference(DateTime.now());
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration duration) {
    final int hours = duration.inHours;
    final String minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      final String hoursStr = hours.toString().padLeft(2, '0');
      return '$hoursStr:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.timer_outlined, color: Color(0xFF1D4ED8), size: 18),
          const SizedBox(width: 8),
          Text(
            'Reset gratis 10 ⚡ harian dalam ',
            style: GoogleFonts.dmSans(
              color: const Color(0xFF1E40AF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _format(_remaining),
            style: GoogleFonts.fredoka(
              color: const Color(0xFF1D4ED8),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _YCoinTopUpSheet extends ConsumerStatefulWidget {
  const _YCoinTopUpSheet();

  @override
  ConsumerState<_YCoinTopUpSheet> createState() => _YCoinTopUpSheetState();
}

class _YCoinTopUpSheetState extends ConsumerState<_YCoinTopUpSheet> {
  String? _pendingPackageId;

  Future<void> _handlePackageTap(YCoinTopUpPackage package) async {
    if (_pendingPackageId != null) {
      return;
    }
    final bool? confirmed = await showDummyPaymentConfirmation(
      context: context,
      title: '+${formatYCoins(package.totalCoins)} Y-Coin',
      subtitle: package.bonusCoins > 0
          ? 'Termasuk bonus +${package.bonusCoins} Y-Coin (Paket Beta)'
          : 'Paket Y-Coin Top Up (Beta Access Available)',
      priceLabel: '${package.priceLabel} (Beta)',
      badgeText: 'BETA ACCESS AVAILABLE',
      icon: Icons.monetization_on_rounded,
      themeColor: AppColors.levelUpTeal,
    );

    if (confirmed == true && mounted) {
      await _topUp(package);
    }
  }

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
    final GameEconomyState economy = ref.watch(gameEconomyProvider);
    final int? balance = economy.isAuthoritative ? economy.yCoins : null;
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
            if (!economy.isAuthoritative) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECE8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Sinkronisasi ekonomi belum tersedia. Saldo dan transaksi dinonaktifkan.',
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(gameEconomyProvider.notifier).refresh(),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                      'Beta sandbox: konfirmasi pembayaran simulasi. Semua paket aktif (Beta Access Available).',
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
                            onTap:
                                economy.isAuthoritative &&
                                    _pendingPackageId == null
                                ? () => _handlePackageTap(package)
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
    return Material(
      color: Colors.white,
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
              color: AppColors.levelUpTeal.withAlpha(80),
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
                    Row(
                      children: <Widget>[
                        Text(
                          '+${formatYCoins(package.totalCoins)} Y-Coin',
                          style: GoogleFonts.dmSans(
                            color: AppColors.textStrong,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.levelUpTeal.withAlpha(22),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'BETA',
                            style: GoogleFonts.dmSans(
                              color: AppColors.levelUpTeal,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      package.bonusCoins > 0
                          ? 'Bonus +${package.bonusCoins} • Beta Access Available'
                          : 'Beta Access Available',
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
                          color: AppColors.levelUpTeal,
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
