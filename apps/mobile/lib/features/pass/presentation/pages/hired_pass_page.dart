import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';

class HiredPassPage extends ConsumerWidget {
  const HiredPassPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final economy = ref.watch(gameEconomyProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0D49B5),
              Color(0xFF072C73),
              Color(0xFF041945),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                title: Text(
                  'YUDHA PRO',
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                centerTitle: true,
                actions: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: YCoinBalanceChip(
                        balance: economy.isAuthoritative ? economy.yCoins : null,
                        onTap: economy.isAuthoritative
                            ? () => showYCoinTopUpSheet(context)
                            : null,
                        dark: true,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const ProBadge(),
                          const SizedBox(height: 10),
                          Text(
                            'Akses Tanpa Batas',
                            style: GoogleFonts.fredoka(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tingkatkan pengalaman belajarmu ke level maksimal',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(210),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _buildClayBenefitCard(
                            icon: Icons.bolt_rounded,
                            iconColor: const Color(0xFFFF9800),
                            title: 'Unlimited Energy',
                            subtitle:
                                'Bebas main Solo & PvP tanpa pernah kehabisan energi harian.',
                          ),
                          const SizedBox(height: 12),
                          _buildClayBenefitCard(
                            icon: Icons.monetization_on_rounded,
                            iconColor: const Color(0xFFFFC857),
                            title: '+500 Y-Coins Monthly',
                            subtitle:
                                'Bonus hibah 500 Y-Coins otomatis tiap siklus 30 hari.',
                          ),
                          const SizedBox(height: 12),
                          _buildClayBenefitCard(
                            icon: Icons.checkroom_rounded,
                            iconColor: const Color(0xFFA855F7),
                            title: 'Exclusive Skin Selection',
                            subtitle:
                                'Klaim 1 skin karakter eksklusif YUDHA Pro secara gratis saat aktivasi.',
                          ),
                          const SizedBox(height: 12),
                          _buildClayBenefitCard(
                            icon: Icons.block_rounded,
                            iconColor: const Color(0xFFEF4444),
                            title: 'Ad-Free Experience',
                            subtitle:
                                'Pengalaman belajar dan bertanding yang bersih tanpa gangguan iklan.',
                          ),
                        ],
                      ),
                      if (economy.isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF22C55E),
                              width: 2,
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0xFF15803D),
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF15803D),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'YUDHA PRO AKTIF',
                                style: GoogleFonts.fredoka(
                                  color: const Color(0xFF15803D),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC857),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF6E4809),
                              width: 2,
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0xFF6E4809),
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Fitur langganan YUDHA Pro akan segera aktif!',
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    'LANGGANAN YUDHA PRO',
                                    style: GoogleFonts.fredoka(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF5A2A00),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClayBenefitCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.warriorNavy.withAlpha(25),
          width: 2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1F06378F),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor.withAlpha(80), width: 1.5),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.3,
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
