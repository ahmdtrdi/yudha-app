import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';
import 'package:yudha_mobile/features/pass/application/hired_pass_providers.dart';
import 'package:yudha_mobile/features/pass/data/repositories/hired_pass_repository.dart';
import 'package:yudha_mobile/features/pass/domain/entities/hired_pass_status.dart';

class HiredPassPage extends ConsumerWidget {
  const HiredPassPage({super.key});

  static const int _seasonMaxPoints = 1000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final economy = ref.watch(gameEconomyProvider);
    final AsyncValue<HiredPassStatus> status = ref.watch(
      hiredPassStatusProvider,
    );
    final HiredPassStatus? serverStatus = status.asData?.value;
    final _PassAccessState passAccess = serverStatus == null
        ? const _PassAccessState.unavailable()
        : _PassAccessState.fromStatus(serverStatus);
    final List<PassReward> passRewards = serverStatus == null
        ? const <PassReward>[]
        : serverStatus.rewards.map(_toPassReward).toList(growable: false);
    final List<int> milestones =
        passRewards
            .map((PassReward reward) => reward.pointsRequired)
            .toSet()
            .toList()
          ..sort();
    final double progress = (passAccess.passPoints / _seasonMaxPoints).clamp(
      0,
      1,
    );

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
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            _PassHeroCard(
              access: passAccess,
              progress: progress,
              onActivate: serverStatus == null
                  ? null
                  : () => _activateBeta(context, ref, serverStatus),
            ),
            const SizedBox(height: 16),
            _SectionTitle(
              title: 'Misi musim ini',
              subtitle: 'Aktivitas belajar menghasilkan Pass Points.',
              trailing: TextButton.icon(
                key: const ValueKey<String>('refresh-pass-missions'),
                onPressed: () {
                  ref.invalidate(hiredPassStatusProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Muat ulang'),
              ),
            ),
            const SizedBox(height: 10),
            ..._missionWidgets(status, ref),
            const SizedBox(height: 22),
            const _SectionTitle(
              title: 'Reward track',
              subtitle: 'Free untuk semua, Premium memberi bonus kosmetik.',
            ),
            const SizedBox(height: 10),
            ...milestones.map(
              (int milestone) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RewardMilestone(
                  milestone: milestone,
                  access: passAccess,
                  rewards: passRewards,
                  onClaim: (PassReward reward) =>
                      _claimReward(context, ref, reward),
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

  PassReward _toPassReward(HiredPassReward reward) {
    return PassReward(
      id: reward.id,
      pointsRequired: reward.pointsRequired,
      track: reward.track == 'premium' ? PassTrack.premium : PassTrack.free,
      label: reward.label,
      yCoins: reward.coins,
      cosmeticItemId: reward.itemId,
    );
  }

  Future<void> _activateBeta(
    BuildContext context,
    WidgetRef ref,
    HiredPassStatus? status,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? seasonId = status?.seasonId;
    if (seasonId == null || seasonId.isEmpty) {
      _showMessage(messenger, 'Belum ada musim Hired Pass aktif.', false);
      return;
    }
    try {
      final HiredPassMutationResult result = await ref
          .read(hiredPassRepositoryProvider)
          .activateBeta(seasonId);
      ref.invalidate(hiredPassStatusProvider);
      await ref.read(gameEconomyProvider.notifier).refresh();
      _showMessage(
        messenger,
        'Hired Pass Premium aktif sampai ${result.expiresAt ?? 'akhir musim'}.',
        true,
      );
    } catch (error) {
      _showMessage(messenger, error.toString(), false);
    }
  }

  Future<void> _claimReward(
    BuildContext context,
    WidgetRef ref,
    PassReward reward,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(hiredPassRepositoryProvider).claimReward(reward.id);
      ref.invalidate(hiredPassStatusProvider);
      await ref.read(gameEconomyProvider.notifier).refresh();
      _showMessage(messenger, '${reward.label} berhasil diklaim.', true);
    } catch (error) {
      _showMessage(messenger, error.toString(), false);
    }
  }

  void _showMessage(
    ScaffoldMessengerState messenger,
    String message,
    bool success,
  ) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success
              ? AppColors.levelUpTeal
              : const Color(0xFFB64040),
        ),
      );
  }

  List<Widget> _missionWidgets(
    AsyncValue<HiredPassStatus> status,
    WidgetRef ref,
  ) {
    return status.when(
      data: (HiredPassStatus value) {
        if (value.missions.isEmpty) {
          return const <Widget>[Text('Belum ada misi aktif untuk musim ini.')];
        }
        return <Widget>[
          for (int index = 0; index < value.missions.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _MissionCard(
              icon: _missionIcon(value.missions[index].id),
              title: value.missions[index].title,
              subtitle: value.missions[index].description,
              progress: value.missions[index].progress,
              target: value.missions[index].target,
              passPointsReward: value.missions[index].passPointsReward,
              color: _missionColor(value.missions[index].id),
            ),
          ],
        ];
      },
      loading: () => const <Widget>[Center(child: CircularProgressIndicator())],
      error: (Object error, StackTrace stackTrace) => <Widget>[
        TextButton.icon(
          onPressed: () => ref.invalidate(hiredPassStatusProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: Text('Misi gagal dimuat: $error'),
        ),
      ],
    );
  }

  IconData _missionIcon(String id) {
    if (id.contains('practice')) {
      return Icons.menu_book_rounded;
    }
    if (id.contains('ranked') || id.contains('battle')) {
      return Icons.sports_martial_arts_rounded;
    }
    return Icons.mic_rounded;
  }

  Color _missionColor(String id) {
    if (id.contains('practice')) {
      return const Color(0xFF2878F0);
    }
    if (id.contains('ranked') || id.contains('battle')) {
      return const Color(0xFFF05E5E);
    }
    return const Color(0xFF8B6FE8);
  }
}

class _PassAccessState {
  const _PassAccessState({
    required this.available,
    required this.passPoints,
    required this.premiumActive,
    required this.claimedRewardIds,
  });

  const _PassAccessState.unavailable()
    : available = false,
      passPoints = 0,
      premiumActive = false,
      claimedRewardIds = const <String>{};

  factory _PassAccessState.fromStatus(HiredPassStatus status) {
    return _PassAccessState(
      available: true,
      passPoints: status.passPoints,
      premiumActive: status.premiumActive,
      claimedRewardIds: status.claimedRewardIds,
    );
  }

  final bool available;
  final int passPoints;
  final bool premiumActive;
  final Set<String> claimedRewardIds;

  bool hasClaimed(String rewardId) => claimedRewardIds.contains(rewardId);
}

class _PassHeroCard extends StatelessWidget {
  const _PassHeroCard({
    required this.access,
    required this.progress,
    required this.onActivate,
  });

  final _PassAccessState access;
  final double progress;
  final VoidCallback? onActivate;

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
                          letterSpacing: 0,
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
                      '${access.passPoints} PASS POINTS',
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
                if (access.premiumActive)
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
                        letterSpacing: 0,
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    key: const ValueKey<String>('activate-premium-pass'),
                    onPressed: access.available ? onActivate : null,
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
    required this.passPointsReward,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int progress;
  final int target;
  final int passPointsReward;
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
                      '+$passPointsReward PASS POINTS',
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
    required this.access,
    required this.rewards,
    required this.onClaim,
  });

  final int milestone;
  final _PassAccessState access;
  final List<PassReward> rewards;
  final ValueChanged<PassReward> onClaim;

  @override
  Widget build(BuildContext context) {
    final PassReward freeReward = rewards.firstWhere(
      (PassReward reward) =>
          reward.pointsRequired == milestone && reward.track == PassTrack.free,
    );
    final PassReward premiumReward = rewards.firstWhere(
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
                  color: access.passPoints >= milestone
                      ? AppColors.warriorNavy
                      : const Color(0xFFD9D4E2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$milestone',
                  style: GoogleFonts.jetBrainsMono(
                    color: access.passPoints >= milestone
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
                  access: access,
                  onTap: () => onClaim(freeReward),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RewardTile(
                  reward: premiumReward,
                  access: access,
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
    required this.access,
    required this.onTap,
  });

  final PassReward reward;
  final _PassAccessState access;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool premium = reward.track == PassTrack.premium;
    final bool claimed = access.hasClaimed(reward.id);
    final bool unlocked =
        access.available &&
        access.passPoints >= reward.pointsRequired &&
        (!premium || access.premiumActive);
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
                    : premium && !access.premiumActive
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
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
