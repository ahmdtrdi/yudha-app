import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';

class LobbyPage extends ConsumerWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProgressProvider);
    final int tierPoints = progress.totalPoints % 400;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(title: Text('YUDHA', style: GoogleFonts.orbitron())),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxHeight < 720;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _TopStreakChip(streak: progress.streak, compact: compact),
                      const Spacer(),
                      _TopSettingsButton(
                        compact: compact,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings coming soon'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Expanded(
                    flex: compact ? 6 : 7,
                    child: _LobbyHeroCard(
                      compact: compact,
                      displayName: progress.displayName,
                      tierLabel: progress.tier.label,
                      totalPoints: progress.totalPoints,
                      winRate: progress.winRate,
                      tierPoints: tierPoints,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  _TodayQuestsSection(
                    compact: compact,
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
                        style: GoogleFonts.orbitron(
                          fontSize: compact ? 15 : 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warriorNavy,
                          letterSpacing: 1.4,
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
    required this.tierPoints,
  });

  final bool compact;
  final String displayName;
  final String tierLabel;
  final int totalPoints;
  final double winRate;
  final int tierPoints;

  @override
  Widget build(BuildContext context) {
    final String winRateLabel = '${(winRate * 100).toStringAsFixed(0)}%';
    final double tierProgress = tierPoints / 400;

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _HeroPill(label: 'Winrate', value: winRateLabel),
                  _HeroPill(label: 'Points', value: '$totalPoints'),
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
                              color: AppColors.levelUpTeal.withValues(
                                alpha: 0.6,
                              ),
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
                          style: GoogleFonts.orbitron(
                            color: AppColors.fireGold,
                            fontSize: compact ? 12 : 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
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
                    '$tierPoints / 400',
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

class _TopStreakChip extends StatelessWidget {
  const _TopStreakChip({required this.streak, required this.compact});

  final int streak;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.warriorNavy,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.fireGold,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'Streak $streak',
            style: GoogleFonts.dmSans(
              color: AppColors.scholarCream,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSettingsButton extends StatelessWidget {
  const _TopSettingsButton({required this.compact, required this.onTap});

  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warriorNavy,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(compact ? 9 : 10),
          child: const Icon(
            Icons.settings_outlined,
            color: AppColors.scholarCream,
            size: 20,
          ),
        ),
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
        children: <Widget>[
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: AppColors.fireGold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              color: AppColors.scholarCream,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
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
    required this.onPracticeTap,
    required this.onPvpTap,
  });

  final bool compact;
  final VoidCallback onPracticeTap;
  final VoidCallback onPvpTap;

  @override
  Widget build(BuildContext context) {
    const int totalQuests = 2;
    const int completedQuests = 0; // TODO: wire to real completion data

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
                style: GoogleFonts.orbitron(
                  color: AppColors.warriorNavy,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
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
            title: 'Daily Question',
            subtitle: 'Practice one question',
            xpReward: '+50 XP',
            completed: false,
            onTap: onPracticeTap,
          ),
          const SizedBox(height: 4),
          _QuestTile(
            title: 'Daily PvP',
            subtitle: 'Win one battle',
            xpReward: '+80 XP',
            completed: false,
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
