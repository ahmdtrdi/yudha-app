import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';

class LobbyPage extends ConsumerWidget {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(title: const Text('YUDHA Lobby')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxHeight < 560;
            final double heroHeight = compact
                ? 172
                : (constraints.maxHeight * 0.40).clamp(220.0, 280.0).toDouble();
            final double sectionGap = compact ? 6 : 10;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 4 : 12, 16, 14),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.interview),
                        icon: const Icon(
                          Icons.record_voice_over_outlined,
                          size: 18,
                        ),
                        label: Text(compact ? 'Interview' : 'Interview Prep'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.warriorNavy,
                          side: BorderSide(
                            color: AppColors.warriorNavy.withAlpha(75),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 8 : 12,
                            vertical: compact ? 6 : 10,
                          ),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          _TopActionButton(
                            icon: Icons.storefront_outlined,
                            tooltip: 'Store',
                            compact: compact,
                            onPressed: () => context.push(AppRoutes.store),
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          _TopMetricChip(
                            label: 'Streak',
                            value: '${progress.streak}',
                            compact: compact,
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          _TopActionButton(
                            icon: Icons.settings_outlined,
                            tooltip: 'Settings',
                            compact: compact,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Settings coming soon'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: sectionGap),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          height: heroHeight,
                          width: double.infinity,
                          child: _LobbyHeroCard(
                            compact: compact,
                            displayName: progress.displayName,
                            tierLabel: progress.tier.label,
                            totalPoints: progress.totalPoints,
                            streak: progress.streak,
                            winRate: progress.winRate,
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        _TodayQuestCard(
                          compact: compact,
                          onPracticeTap: () => context.go(AppRoutes.practice),
                          onPvpTap: () => context.go(AppRoutes.pvp),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.pvp),
                      icon: const Icon(Icons.sports_martial_arts_outlined),
                      label: const Text('Start Battle'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warriorNavy,
                        foregroundColor: AppColors.scholarCream,
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 10 : 16,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.practice),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Practice'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.levelUpTeal,
                            side: const BorderSide(
                              color: AppColors.levelUpTeal,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 8 : 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.leaderboard),
                          icon: const Icon(Icons.emoji_events_outlined),
                          label: const Text('Leaderboard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.levelUpTeal,
                            side: const BorderSide(
                              color: AppColors.levelUpTeal,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 8 : 12,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.tooltip,
    required this.compact,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 34 : 40;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warriorNavy.withAlpha(55)),
            ),
            child: Icon(
              icon,
              color: AppColors.warriorNavy,
              size: compact ? 20 : 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopMetricChip extends StatelessWidget {
  const _TopMetricChip({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(55)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: AppColors.warriorNavy,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
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
    required this.streak,
    required this.winRate,
  });

  final bool compact;
  final String displayName;
  final String tierLabel;
  final int totalPoints;
  final int streak;
  final double winRate;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactHeroCard(
        displayName: displayName,
        tierLabel: tierLabel,
        totalPoints: totalPoints,
        winRate: winRate,
      );
    }

    final int tierPoints = totalPoints % 400;
    final double tierProgress = tierPoints / 400;
    final String winRateLabel = '${(winRate * 100).toStringAsFixed(0)}%';
    final String objective = streak > 0
        ? 'Keep your streak: win one battle today'
        : 'Start your streak with one victory today';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool dense = constraints.maxHeight < 260;
        final double avatarSize = dense ? 60 : 88;
        final double iconSize = dense ? 34 : 44;
        final double nameSize = dense ? 20 : 24;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(dense ? 12 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF0C3D9D), AppColors.warriorNavy],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x2B013192),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
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
              SizedBox(height: dense ? 6 : 10),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.scholarCream.withAlpha(30),
                            border: Border.all(
                              color: AppColors.fireGold,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            size: iconSize,
                            color: AppColors.scholarCream,
                          ),
                        ),
                        SizedBox(height: dense ? 6 : 10),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.scholarCream,
                            fontSize: nameSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$tierLabel Tier',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.scholarCream.withAlpha(220),
                            fontSize: dense ? 12 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!dense) ...<Widget>[
                Text(
                  objective,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.scholarCream.withAlpha(225),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: tierProgress == 0 ? 0.02 : tierProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.scholarCream.withAlpha(50),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.levelUpTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$tierPoints / 400',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.scholarCream.withAlpha(210),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CompactHeroCard extends StatelessWidget {
  const _CompactHeroCard({
    required this.displayName,
    required this.tierLabel,
    required this.totalPoints,
    required this.winRate,
  });

  final String displayName;
  final String tierLabel;
  final int totalPoints;
  final double winRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0C3D9D), AppColors.warriorNavy],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x2B013192),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.scholarCream.withAlpha(30),
              border: Border.all(color: AppColors.fireGold, width: 2),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 32,
              color: AppColors.scholarCream,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayName,
            style: const TextStyle(
              color: AppColors.scholarCream,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$tierLabel Tier',
            style: TextStyle(
              color: AppColors.scholarCream.withAlpha(220),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _StatChip(label: 'Points', value: '$totalPoints', compact: true),
              const SizedBox(width: 6),
              _StatChip(
                label: 'Winrate',
                value: '${(winRate * 100).toStringAsFixed(0)}%',
                compact: true,
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scholarCream.withAlpha(34),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.scholarCream.withAlpha(80)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: AppColors.scholarCream.withAlpha(230),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.scholarCream.withAlpha(38),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.scholarCream.withAlpha(90)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: AppColors.scholarCream.withAlpha(225),
            fontSize: compact ? 11 : 12,
          ),
          children: <TextSpan>[
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayQuestCard extends StatelessWidget {
  const _TodayQuestCard({
    required this.compact,
    required this.onPracticeTap,
    required this.onPvpTap,
  });

  final bool compact;
  final VoidCallback onPracticeTap;
  final VoidCallback onPvpTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warriorNavy.withAlpha(45)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14013192),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.task_alt_outlined,
                color: AppColors.levelUpTeal,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Today\'s Quest',
                style: TextStyle(
                  color: AppColors.warriorNavy,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 3 : 8),
          _QuestTile(
            title: 'Daily Question',
            compact: compact,
            onTap: onPracticeTap,
          ),
          SizedBox(height: compact ? 3 : 6),
          _QuestTile(title: 'Daily PvP', compact: compact, onTap: onPvpTap),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.title,
    required this.compact,
    required this.onTap,
  });

  final String title;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warriorNavy.withAlpha(32)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: compact ? 14 : 18,
                height: compact ? 14 : 18,
                decoration: const BoxDecoration(
                  color: AppColors.levelUpTeal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: compact ? 10 : 13,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.warriorNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
