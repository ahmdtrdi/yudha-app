import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_controller.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/domain/entities/game_economy_state.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';

class HiredPassPage extends ConsumerWidget {
  const HiredPassPage({super.key});

  static const int _seasonMaxPoints = 1000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameEconomyState economy = ref.watch(gameEconomyProvider);
    final double progress = (economy.passPoints / _seasonMaxPoints).clamp(0, 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F0FA),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('HIRED PASS'),
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
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            _PassHeroCard(
              economy: economy,
              progress: progress,
              onActivate: () => _showResult(
                context,
                ref
                    .read(gameEconomyProvider.notifier)
                    .activatePremiumPassForBeta(),
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(
              title: 'Misi musim ini',
              subtitle: 'Aktivitas belajar menghasilkan Pass Points.',
              trailing: TextButton.icon(
                key: const ValueKey<String>('add-pass-points-beta'),
                onPressed: () {
                  ref
                      .read(gameEconomyProvider.notifier)
                      .addPassPointsForTesting();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Beta +100 Pass Points.')),
                    );
                },
                icon: const Icon(Icons.science_rounded, size: 16),
                label: const Text('+100 beta'),
              ),
            ),
            const SizedBox(height: 10),
            const _MissionCard(
              icon: Icons.menu_book_rounded,
              title: 'Latihan harian',
              subtitle: 'Selesaikan 3 sesi practice',
              progress: 2,
              target: 3,
              points: 100,
              color: Color(0xFF2878F0),
            ),
            const SizedBox(height: 8),
            const _MissionCard(
              icon: Icons.sports_martial_arts_rounded,
              title: 'Pejuang mingguan',
              subtitle: 'Mainkan 5 battle PvP',
              progress: 3,
              target: 5,
              points: 250,
              color: Color(0xFFF05E5E),
            ),
            const SizedBox(height: 8),
            const _MissionCard(
              icon: Icons.mic_rounded,
              title: 'Siap interview',
              subtitle: 'Selesaikan 1 mock interview',
              progress: 0,
              target: 1,
              points: 200,
              color: Color(0xFF8B6FE8),
            ),
            const SizedBox(height: 22),
            const _SectionTitle(
              title: 'Reward track',
              subtitle: 'Free untuk semua, Premium memberi bonus kosmetik.',
            ),
            const SizedBox(height: 10),
            ...<int>[100, 300, 600, 1000].map(
              (int milestone) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RewardMilestone(
                  milestone: milestone,
                  economy: economy,
                  onClaim: (PassReward reward) => _showResult(
                    context,
                    ref
                        .read(gameEconomyProvider.notifier)
                        .claimPassReward(reward),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warriorNavy.withAlpha(18)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.balance_rounded,
                    color: AppColors.levelUpTeal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hired Pass bersifat kosmetik: tidak menambah HP, damage, waktu jawab, atau rank points.',
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
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

  void _showResult(BuildContext context, EconomyActionResult result) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? AppColors.levelUpTeal
              : const Color(0xFFB64040),
        ),
      );
  }
}

class _PassHeroCard extends StatelessWidget {
  const _PassHeroCard({
    required this.economy,
    required this.progress,
    required this.onActivate,
  });

  final GameEconomyState economy;
  final double progress;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF24164E), Color(0xFF013192)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x3324164E),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            right: -35,
            top: -38,
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 180,
              color: Color(0x15FFFFFF),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC857),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'SEASON 01',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF4D360B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '28 hari tersisa',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withAlpha(190),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Jalur Sang Juara',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Belajar konsisten, buka reward eksklusif.',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withAlpha(190),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${economy.passPoints} PASS POINTS',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFFFC857),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    color: const Color(0xFFFFC857),
                    backgroundColor: Colors.white.withAlpha(35),
                  ),
                ),
                const SizedBox(height: 16),
                if (economy.premiumPassActive)
                  Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF47CFA0).withAlpha(35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF6AE4BB)),
                    ),
                    child: Text(
                      'PREMIUM AKTIF  •  BEBAS IKLAN',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFFA7F1D7),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    key: const ValueKey<String>('activate-premium-pass'),
                    onPressed: onActivate,
                    icon: const Icon(Icons.workspace_premium_rounded),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFFFFC857),
                      foregroundColor: const Color(0xFF352507),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: Text(
                      'Aktifkan Premium • Rp29.000 (Beta)',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: GoogleFonts.fredoka(
                  color: AppColors.textStrong,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.target,
    required this.points,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int progress;
  final int target;
  final int points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(18)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.dmSans(
                          color: AppColors.textStrong,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '+$points PP',
                      style: GoogleFonts.jetBrainsMono(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$subtitle  •  $progress/$target',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress / target,
                    minHeight: 6,
                    color: color,
                    backgroundColor: color.withAlpha(18),
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

class _RewardMilestone extends StatelessWidget {
  const _RewardMilestone({
    required this.milestone,
    required this.economy,
    required this.onClaim,
  });

  final int milestone;
  final GameEconomyState economy;
  final ValueChanged<PassReward> onClaim;

  @override
  Widget build(BuildContext context) {
    final PassReward freeReward = GameEconomyCatalog.passRewards.firstWhere(
      (PassReward reward) =>
          reward.pointsRequired == milestone && reward.track == PassTrack.free,
    );
    final PassReward premiumReward = GameEconomyCatalog.passRewards.firstWhere(
      (PassReward reward) =>
          reward.pointsRequired == milestone &&
          reward.track == PassTrack.premium,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 52,
          child: Column(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: economy.passPoints >= milestone
                      ? AppColors.warriorNavy
                      : const Color(0xFFD9D4E2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$milestone',
                  style: GoogleFonts.jetBrainsMono(
                    color: economy.passPoints >= milestone
                        ? Colors.white
                        : AppColors.textMuted,
                    fontSize: milestone >= 1000 ? 9 : 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(width: 3, height: 86, color: const Color(0xFFD9D4E2)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _RewardTile(
                  reward: freeReward,
                  economy: economy,
                  onTap: () => onClaim(freeReward),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RewardTile(
                  reward: premiumReward,
                  economy: economy,
                  onTap: () => onClaim(premiumReward),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.economy,
    required this.onTap,
  });

  final PassReward reward;
  final GameEconomyState economy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool premium = reward.track == PassTrack.premium;
    final bool claimed = economy.hasClaimed(reward.id);
    final bool unlocked =
        economy.passPoints >= reward.pointsRequired &&
        (!premium || economy.premiumPassActive);
    final CosmeticItem? cosmetic = reward.cosmeticItemId == null
        ? null
        : GameEconomyCatalog.findCosmetic(reward.cosmeticItemId!);

    return Material(
      color: premium ? const Color(0xFFF2ECFF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey<String>('pass-reward-${reward.id}'),
        onTap: unlocked && !claimed ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 118,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: premium
                  ? const Color(0xFFBDA8EC)
                  : AppColors.warriorNavy.withAlpha(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    premium
                        ? Icons.workspace_premium_rounded
                        : Icons.redeem_rounded,
                    color: premium
                        ? const Color(0xFF8B6FE8)
                        : AppColors.levelUpTeal,
                    size: 18,
                  ),
                  const Spacer(),
                  Text(
                    premium ? 'PREMIUM' : 'FREE',
                    style: GoogleFonts.dmSans(
                      color: premium
                          ? const Color(0xFF7258BF)
                          : AppColors.levelUpTeal,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                cosmetic?.name ?? reward.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: AppColors.textStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                claimed
                    ? 'SUDAH DIKLAIM'
                    : unlocked
                    ? 'TAP UNTUK KLAIM'
                    : premium && !economy.premiumPassActive
                    ? 'KUNCI PREMIUM'
                    : 'BELUM TERBUKA',
                style: GoogleFonts.dmSans(
                  color: claimed
                      ? AppColors.levelUpTeal
                      : unlocked
                      ? AppColors.warriorNavy
                      : AppColors.textMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
