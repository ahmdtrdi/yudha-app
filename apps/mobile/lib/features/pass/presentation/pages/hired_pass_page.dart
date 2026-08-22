import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/data/game_economy_catalog.dart';
import 'package:yudha_mobile/features/economy/domain/entities/cosmetic_item.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/payment_confirmation_modal.dart';
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
              subtitle: 'Capai milestone dan klaim hadiahmu.',
            ),
            const SizedBox(height: 10),
            if (milestones.isNotEmpty)
              _RewardTrackTable(
                milestones: milestones,
                access: passAccess,
                rewards: passRewards,
                onClaim: (PassReward reward) =>
                    _claimReward(context, ref, reward),
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

    final bool? confirmed = await showDummyPaymentConfirmation(
      context: context,
      title: 'Hired Pass Premium',
      subtitle: 'Season 01: Jalur Sang Juara • Akses Reward Track Premium',
      priceLabel: 'Rp29.000 (Beta)',
      badgeText: 'PREMIUM PASS',
      icon: Icons.workspace_premium_rounded,
      themeColor: const Color(0xFF7957C8),
    );
    if (confirmed != true) {
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

class _RewardTrackTable extends StatelessWidget {
  const _RewardTrackTable({
    required this.milestones,
    required this.access,
    required this.rewards,
    required this.onClaim,
  });

  static const double _milestoneWidth = 52;
  static const double _laneGap = 8;

  final List<int> milestones;
  final _PassAccessState access;
  final List<PassReward> rewards;
  final ValueChanged<PassReward> onClaim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double laneWidth =
              (constraints.maxWidth - _milestoneWidth - _laneGap) / 2;
          final double premiumLaneLeft = _milestoneWidth + laneWidth + _laneGap;

          return Stack(
            key: const ValueKey<String>('reward-track-table'),
            children: <Widget>[
              Positioned(
                key: const ValueKey<String>('premium-reward-lane'),
                top: 0,
                bottom: 0,
                left: premiumLaneLeft,
                width: laneWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE5FA),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              Column(
                children: <Widget>[
                  const _RewardTrackHeader(),
                  for (int index = 0; index < milestones.length; index++)
                    _RewardMilestone(
                      milestone: milestones[index],
                      access: access,
                      freeReward: _rewardFor(milestones[index], PassTrack.free),
                      premiumReward: _rewardFor(
                        milestones[index],
                        PassTrack.premium,
                      ),
                      showConnector: index < milestones.length - 1,
                      onClaim: onClaim,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  PassReward? _rewardFor(int milestone, PassTrack track) {
    for (final PassReward reward in rewards) {
      if (reward.pointsRequired == milestone && reward.track == track) {
        return reward;
      }
    }
    return null;
  }
}

class _RewardTrackHeader extends StatelessWidget {
  const _RewardTrackHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: <Widget>[
          const SizedBox(width: _RewardTrackTable._milestoneWidth),
          Expanded(
            child: Center(
              child: Text(
                'FREE PASS',
                key: const ValueKey<String>('free-pass-header'),
                style: GoogleFonts.dmSans(
                  color: AppColors.warriorNavy,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: _RewardTrackTable._laneGap),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF7957C8),
                  size: 17,
                ),
                const SizedBox(width: 5),
                Text(
                  'PREMIUM PASS',
                  key: const ValueKey<String>('premium-pass-header'),
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF6545B0),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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
    required this.freeReward,
    required this.premiumReward,
    required this.showConnector,
    required this.onClaim,
  });

  final int milestone;
  final _PassAccessState access;
  final PassReward? freeReward;
  final PassReward? premiumReward;
  final bool showConnector;
  final ValueChanged<PassReward> onClaim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _RewardTrackTable._milestoneWidth,
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                if (showConnector)
                  Positioned(
                    top: 38,
                    bottom: 0,
                    child: Container(
                      key: ValueKey<String>('reward-connector-$milestone'),
                      width: 3,
                      color: const Color(0xFFC9D3E3),
                    ),
                  ),
                Container(
                  key: ValueKey<String>('reward-milestone-$milestone'),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: access.passPoints >= milestone
                        ? const Color(0xFF2878F0)
                        : const Color(0xFFD7DCE5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
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
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _RewardTile(
                reward: freeReward,
                premium: false,
                slotId: 'free-$milestone',
                access: access,
                onTap: freeReward == null ? null : () => onClaim(freeReward!),
              ),
            ),
          ),
          const SizedBox(width: _RewardTrackTable._laneGap),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _RewardTile(
                reward: premiumReward,
                premium: true,
                slotId: 'premium-$milestone',
                access: access,
                onTap: premiumReward == null
                    ? null
                    : () => onClaim(premiumReward!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RewardTileState { claimable, locked, claimed }

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.premium,
    required this.slotId,
    required this.access,
    required this.onTap,
  });

  final PassReward? reward;
  final bool premium;
  final String slotId;
  final _PassAccessState access;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PassReward? currentReward = reward;
    if (currentReward == null) {
      return SizedBox(
        key: ValueKey<String>('pass-reward-empty-$slotId'),
        height: 92,
      );
    }

    final bool claimed = access.hasClaimed(currentReward.id);
    final bool unlocked =
        access.available &&
        access.passPoints >= currentReward.pointsRequired &&
        (!premium || access.premiumActive);
    final _RewardTileState state = claimed
        ? _RewardTileState.claimed
        : unlocked
        ? _RewardTileState.claimable
        : _RewardTileState.locked;
    final CosmeticItem? cosmetic = currentReward.cosmeticItemId == null
        ? null
        : GameEconomyCatalog.findCosmetic(currentReward.cosmeticItemId!);
    final double faceTop = switch (state) {
      _RewardTileState.claimable => 0,
      _RewardTileState.locked => 2,
      _RewardTileState.claimed => 7,
    };
    final double faceBottom = switch (state) {
      _RewardTileState.claimable => 7,
      _RewardTileState.locked => 4,
      _RewardTileState.claimed => 0,
    };
    final Color faceColor = switch ((premium, state)) {
      (false, _RewardTileState.claimable) => Colors.white,
      (false, _RewardTileState.locked) => const Color(0xFFF0F1F3),
      (false, _RewardTileState.claimed) => const Color(0xFFE5E8EC),
      (true, _RewardTileState.claimable) => const Color(0xFFDCCEFF),
      (true, _RewardTileState.locked) => const Color(0xFFDCD6E8),
      (true, _RewardTileState.claimed) => const Color(0xFFCFC5E3),
    };
    final Color baseColor = switch ((premium, state)) {
      (false, _RewardTileState.claimable) => const Color(0xFFBBC2CD),
      (false, _) => const Color(0xFFD0D4DA),
      (true, _RewardTileState.claimable) => const Color(0xFF8E6BCC),
      (true, _) => const Color(0xFFB6AACB),
    };

    return Semantics(
      button: state == _RewardTileState.claimable,
      enabled: state == _RewardTileState.claimable,
      label: _semanticsLabel(currentReward, cosmetic, state),
      child: SizedBox(
        key: ValueKey<String>('pass-reward-${currentReward.id}'),
        height: 92,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                key: ValueKey<String>('pass-reward-base-${currentReward.id}'),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Positioned(
              top: faceTop,
              bottom: faceBottom,
              left: 0,
              right: 0,
              child: Material(
                color: faceColor,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: state == _RewardTileState.claimable ? onTap : null,
                  child: Stack(
                    children: <Widget>[
                      Center(
                        child: _RewardContent(
                          reward: currentReward,
                          cosmetic: cosmetic,
                          premium: premium,
                          muted: state != _RewardTileState.claimable,
                        ),
                      ),
                      if (state != _RewardTileState.claimable)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: state == _RewardTileState.claimed
                                  ? const Color(0xFF47B99A)
                                  : const Color(0xFF8C929D),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              state == _RewardTileState.claimed
                                  ? Icons.check_rounded
                                  : Icons.lock_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _semanticsLabel(
    PassReward reward,
    CosmeticItem? cosmetic,
    _RewardTileState state,
  ) {
    final String label = cosmetic?.name ?? reward.label;
    final String status = switch (state) {
      _RewardTileState.claimable => 'dapat diklaim',
      _RewardTileState.locked => 'terkunci',
      _RewardTileState.claimed => 'sudah diklaim',
    };
    return '$label, $status';
  }
}

class _RewardContent extends StatelessWidget {
  const _RewardContent({
    required this.reward,
    required this.cosmetic,
    required this.premium,
    required this.muted,
  });

  final PassReward reward;
  final CosmeticItem? cosmetic;
  final bool premium;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Color foreground = muted
        ? const Color(0xFF858B96)
        : premium
        ? const Color(0xFF6242AA)
        : AppColors.warriorNavy;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (cosmetic != null) ...<Widget>[
            if (cosmetic?.assetPath != null)
              ClipRRect(
                key: ValueKey<String>('reward-item-clip-${reward.id}'),
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Image.asset(
                    cosmetic!.assetPath!,
                    fit: BoxFit.contain,
                    color: muted ? const Color(0xFF999DA6) : null,
                    colorBlendMode: muted ? BlendMode.saturation : null,
                  ),
                ),
              )
            else
              Icon(Icons.redeem_rounded, color: foreground, size: 40),
            const SizedBox(height: 3),
            Text(
              cosmetic!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: foreground,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ] else if (reward.yCoins > 0)
            _CoinAmount(
              rewardId: reward.id,
              amount: reward.yCoins,
              muted: muted,
            )
          else ...<Widget>[
            Icon(Icons.redeem_rounded, color: foreground, size: 40),
            const SizedBox(height: 4),
            Text(
              reward.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoinAmount extends StatelessWidget {
  const _CoinAmount({
    required this.rewardId,
    required this.amount,
    required this.muted,
  });

  final String rewardId;
  final int amount;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Color textColor = muted
        ? const Color(0xFF858B96)
        : AppColors.warriorNavy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _YCoinMark(
          key: ValueKey<String>('y-coin-$rewardId'),
          muted: muted,
          size: 38,
        ),
        const SizedBox(height: 4),
        Text(
          '$amount',
          style: GoogleFonts.dmSans(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _YCoinMark extends StatelessWidget {
  const _YCoinMark({required this.muted, required this.size, super.key});

  final bool muted;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFC5C8CE) : const Color(0xFFFFC928),
        shape: BoxShape.circle,
        border: Border.all(
          color: muted ? const Color(0xFFAEB2BA) : const Color(0xFFFFA800),
          width: 1.5,
        ),
      ),
      child: Text(
        'Y',
        style: GoogleFonts.fredoka(
          color: muted ? const Color(0xFF777D87) : const Color(0xFF7B5200),
          fontSize: size * 0.52,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
