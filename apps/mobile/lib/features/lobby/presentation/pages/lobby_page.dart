import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/economy/application/game_economy_providers.dart';
import 'package:yudha_mobile/features/economy/presentation/widgets/economy_widgets.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';

class LobbyPage extends ConsumerWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProgressProvider);
    final List<Map<String, Object?>> dailyMissions = progress.dailyMissions;
    final Map<String, Object?>? practiceMission = dailyMissions.firstWhere(
      (Map<String, Object?> mission) =>
          mission['key'] == 'daily_practice',
      orElse: () => const <String, Object?>{
        'key': 'daily_practice',
        'title': 'Daily Question',
        'rewardRankPoints': 50,
        'completed': false,
      },
    );
    final Map<String, Object?>? pvpMission = dailyMissions.firstWhere(
      (Map<String, Object?> mission) => mission['key'] == 'daily_pvp',
      orElse: () => const <String, Object?>{
        'key': 'daily_pvp',
        'title': 'Daily PvP',
        'rewardRankPoints': 80,
        'completed': false,
      },
    );

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        title: Text(
          'YUDHA',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          Center(
            child: YCoinBalanceChip(
              balance: ref.watch(
                gameEconomyProvider.select((state) => state.yCoins),
              ),
              onTap: () => showYCoinTopUpSheet(context),
              dark: true,
            ),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.hiredPass),
            tooltip: 'Hired Pass',
            icon: const Icon(Icons.workspace_premium_rounded),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.store),
            tooltip: 'Store',
            icon: const Icon(Icons.storefront_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxHeight < 720;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: compact ? 6 : 7,
                    child: _LobbyHeroCard(
                      compact: compact,
                      displayName: progress.displayName,
                      tierLabel: progress.tier.label,
                      totalPoints: progress.totalPoints,
                      winRate: progress.winRate,
                      streak: progress.streak,
                      currentTierPoints:
                          progress.totalPoints - progress.currentTierBasePoints,
                      pointsUntilNextTier: progress.pointsUntilNextTier,
                      tierProgress: progress.tierProgress,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  _TodayQuestsSection(
                    compact: compact,
                    practiceMission: practiceMission,
                    pvpMission: pvpMission,
                    onPracticeTap: () => context.go(AppRoutes.practice),
                    onPvpTap: () => context.go(AppRoutes.pvp),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  SizedBox(
                    width: double.infinity,
                    height: compact ? 50 : 56,
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.pvp),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.warriorNavy.withValues(alpha: 0.25),
                          width: 2,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'START BATTLE',
                        style: GoogleFonts.fredoka(
                          fontSize: compact ? 15 : 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warriorNavy,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LobbyHeroCard extends StatelessWidget {
  const _LobbyHeroCard({
    required this.compact,
    required this.displayName,
    required this.tierLabel,
    required this.totalPoints,
    required this.winRate,
    required this.streak,
    required this.currentTierPoints,
    required this.pointsUntilNextTier,
    required this.tierProgress,
  });

  final bool compact;
  final String displayName;
  final String tierLabel;
  final int totalPoints;
  final double winRate;
  final int streak;
  final int currentTierPoints;
  final int pointsUntilNextTier;
  final double tierProgress;

  @override
  Widget build(BuildContext context) {
    final String winRateLabel = '${(winRate * 100).toStringAsFixed(0)}%';
    final String progressLabel = pointsUntilNextTier == 0
        ? 'Tier maksimum'
        : '$currentTierPoints pts';
    final String nextTierLabel = pointsUntilNextTier == 0
        ? 'MAX'
        : '$pointsUntilNextTier pts lagi';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0C3D9D), AppColors.warriorNavy],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _HeroPill(label: 'Winrate', value: winRateLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroPill(label: 'Streak', value: '$streak'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroPill(label: 'Points', value: '$totalPoints'),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: compact ? 62 : 78,
                      height: compact ? 62 : 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.scholarCream.withAlpha(20),
                        border: Border.all(
                          color: AppColors.levelUpTeal.withValues(alpha: 0.6),
                          width: 2.5,
                        ),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: compact ? 32 : 40,
                        color: AppColors.levelUpTeal,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: AppColors.scholarCream,
                        fontSize: compact ? 24 : 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${tierLabel.toUpperCase()} TIER',
                      style: GoogleFonts.dmSans(
                        color: AppColors.fireGold,
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'XP to next rank',
                style: GoogleFonts.dmSans(
                  color: AppColors.scholarCream.withAlpha(190),
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$progressLabel • $nextTierLabel',
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.scholarCream.withAlpha(220),
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: <Widget>[
                  Container(color: AppColors.scholarCream.withAlpha(40)),
                  FractionallySizedBox(
                    widthFactor: tierProgress == 0
                        ? 0.02
                        : tierProgress.clamp(0, 1),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            AppColors.levelUpTeal,
                            AppColors.fireGold,
                          ],
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
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.scholarCream.withAlpha(26),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.scholarCream.withAlpha(58)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: AppColors.fireGold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              color: AppColors.scholarCream,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayQuestsSection extends StatelessWidget {
  const _TodayQuestsSection({
    required this.compact,
    required this.practiceMission,
    required this.pvpMission,
    required this.onPracticeTap,
    required this.onPvpTap,
  });

  final bool compact;
  final Map<String, Object?>? practiceMission;
  final Map<String, Object?>? pvpMission;
  final VoidCallback onPracticeTap;
  final VoidCallback onPvpTap;

  @override
  Widget build(BuildContext context) {
    final int totalQuests = [practiceMission, pvpMission]
        .whereType<Map<String, Object?>>()
        .length;
    final int completedQuests = [practiceMission, pvpMission]
        .whereType<Map<String, Object?>>()
        .where((Map<String, Object?> mission) =>
            mission['completed'] == true)
        .length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warriorNavy.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                "TODAY'S QUESTS",
                style: GoogleFonts.fredoka(
                  color: AppColors.warriorNavy,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.levelUpTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$completedQuests / $totalQuests',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppColors.levelUpTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          _QuestTile(
            title: (practiceMission?['title'] ?? 'Daily Question')
                .toString(),
            subtitle: practiceMission?['completed'] == true
                ? 'Selesai hari ini'
                : 'Practice one question',
            xpReward:
                '+${((practiceMission?['rewardRankPoints'] as num?) ?? 50).toInt()} XP',
            completed: practiceMission?['completed'] == true,
            onTap: onPracticeTap,
          ),
          const SizedBox(height: 4),
          _QuestTile(
            title: (pvpMission?['title'] ?? 'Daily PvP').toString(),
            subtitle: pvpMission?['completed'] == true
                ? 'Selesai hari ini'
                : 'Win one battle',
            xpReward:
                '+${((pvpMission?['rewardRankPoints'] as num?) ?? 80).toInt()} XP',
            completed: pvpMission?['completed'] == true,
            onTap: onPvpTap,
          ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.title,
    required this.subtitle,
    required this.xpReward,
    required this.completed,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String xpReward;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: completed
                      ? AppColors.levelUpTeal
                      : AppColors.textMuted.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed ? Icons.check : Icons.circle_outlined,
                  color: completed ? Colors.white : AppColors.textMuted,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        color: AppColors.warriorNavy,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                xpReward,
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.fireGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
