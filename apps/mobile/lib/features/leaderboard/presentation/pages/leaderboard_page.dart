import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_providers.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_state.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_scope.dart';

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardState = ref.watch(leaderboardControllerProvider);
    final leaderboardController = ref.read(
      leaderboardControllerProvider.notifier,
    );
    final progress = ref.watch(playerProgressProvider);

    int userRank = 13; // Fixed prototype rank representing your global position out of the total database!
    bool isUserInLoadedList = false;
    if (leaderboardState.status == LeaderboardViewStatus.success) {
      final idx = leaderboardState.entries.indexWhere((e) => e.isCurrentUser);
      if (idx != -1) {
        userRank = idx + 1;
        isUserInLoadedList = true;
      }
    }

    // Split top 3 vs others
    final topThree = leaderboardState.entries.take(3).toList();
    final otherRanks = leaderboardState.entries.skip(3).toList();

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        title: Text(
          'LEADERBOARD',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.warriorNavy,
        centerTitle: true,
        elevation: 0,
      ),
      body: switch (leaderboardState.status) {
        LeaderboardViewStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        LeaderboardViewStatus.error => _ErrorState(
          onRetry: () => leaderboardController.loadInitial(),
        ),
        LeaderboardViewStatus.empty => _EmptyState(
            onRefresh: leaderboardController.refresh,
          ),
        LeaderboardViewStatus.success => RefreshIndicator(
          onRefresh: leaderboardController.refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.warriorNavy,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _HeroRankCard(
                    rank: userRank,
                    name: progress.displayName.isEmpty
                        ? 'Kamu'
                        : progress.displayName,
                    tierLabel: progress.tier.label.toUpperCase(),
                    totalPoints: progress.totalPoints,
                    streak: progress.streak,
                    winRate: progress.winRate,
                  ),
                ),
              ),
                if (leaderboardState.errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _InlineInfoBanner(
                      text: leaderboardState.errorMessage!,
                      isError: true,
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: _TopThreePodium(entries: topThree)),
              if (otherRanks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 8, top: 8),
                    child: Text(
                      'PERINGKAT LAINNYA',
                      style: GoogleFonts.orbitron(
                        color: AppColors.warriorNavy.withAlpha(150),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = otherRanks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _LeaderboardTile(rank: index + 4, entry: entry),
                    );
                  }, childCount: otherRanks.length),
                ),
              ),
              if (!isUserInLoadedList &&
                  leaderboardState.status == LeaderboardViewStatus.success)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Icon(
                          Icons.more_vert,
                          color: AppColors.warriorNavy.withAlpha(80),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _LeaderboardTile(
                          rank: userRank,
                          entry: LeaderboardEntry(
                            playerId: progress.playerId,
                            playerName: progress.displayName.isEmpty
                                ? 'Kamu'
                                : progress.displayName,
                            points: progress.totalPoints,
                            winRate: progress.winRate,
                            streak: progress.streak,
                            isCurrentUser: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: leaderboardState.isLoadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : (leaderboardState.hasMore
                              ? TextButton(
                                  onPressed: leaderboardController.loadMore,
                                  child: Text(
                                    'Muat lebih banyak',
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.warriorNavy.withAlpha(
                                        150,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : const SizedBox(height: 24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}

class _HeroRankCard extends StatelessWidget {
  const _HeroRankCard({
    required this.rank,
    required this.name,
    required this.tierLabel,
    required this.totalPoints,
    required this.streak,
    required this.winRate,
    this.currentXp = 120, // mocked default
    this.targetXp = 400,
  });

  final int rank;
  final String name;
  final String tierLabel;
  final int totalPoints;
  final int streak;
  final double winRate;
  final int currentXp;
  final int targetXp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F4194),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(50), width: 1),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.levelUpTeal.withAlpha(180),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_outlined,
                          color: AppColors.levelUpTeal,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.military_tech,
                                color: AppColors.fireGold,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tierLabel,
                                style: GoogleFonts.orbitron(
                                  color: AppColors.fireGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _StatColumn(label: 'POIN', value: '$totalPoints'),
                    const SizedBox(width: 24),
                    _StatColumn(
                      label: 'WINRATE',
                      value: '${(winRate * 100).toStringAsFixed(0)}%',
                    ),
                    const SizedBox(width: 24),
                    _StatColumn(label: 'STREAK', value: '$streak'),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'XP ke peringkat berikutnya',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withAlpha(150),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '$currentXp / $targetXp',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withAlpha(150),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(60),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (currentXp / targetXp).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.levelUpTeal, AppColors.fireGold],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.fireGold.withAlpha(120),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withAlpha(10),
              ),
              child: Column(
                children: [
                  Text(
                    rank > 0 ? '#$rank' : '-',
                    style: GoogleFonts.orbitron(
                      color: AppColors.fireGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'PERINGKAT',
                    style: GoogleFonts.dmSans(
                      color: AppColors.fireGold.withAlpha(200),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.orbitron(
            color: Colors.white.withAlpha(160),
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TopThreePodium extends StatelessWidget {
  const _TopThreePodium({required this.entries});
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final hasTwo = entries.length >= 2;
    final hasThree = entries.length >= 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (hasTwo) Expanded(child: _PodiumCard(rank: 2, entry: entries[1])),
          if (hasTwo) const SizedBox(width: 10),
          Expanded(
            child: _PodiumCard(rank: 1, entry: entries[0], isFirst: true),
          ),
          if (hasThree) const SizedBox(width: 10),
          if (hasThree)
            Expanded(child: _PodiumCard(rank: 3, entry: entries[2])),
          if (!hasThree && hasTwo) const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.rank,
    required this.entry,
    this.isFirst = false,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color circleBorder;
    Color circleBg;
    Color textColor;

    if (rank == 1) {
      bgColor = const Color(0xFFFDECDA);
      circleBorder = const Color(0xFFE89A4F);
      circleBg = const Color(0xFFFDECDA);
      textColor = const Color(0xFFE89A4F);
    } else if (rank == 2) {
      bgColor = const Color(0xFFE8EDF2);
      circleBorder = const Color(0xFFA5B4C2);
      circleBg = const Color(0xFFE8EDF2);
      textColor = AppColors.warriorNavy;
    } else {
      bgColor = const Color(0xFFF3EBE1);
      circleBorder = const Color(0xFFD6BEA0);
      circleBg = const Color(0xFFF3EBE1);
      textColor = const Color(0xFFC4A27B);
    }

    return Container(
      padding: EdgeInsets.only(
        top: isFirst ? 18 : 14,
        bottom: 14,
        left: 4,
        right: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: circleBorder.withAlpha(100), width: 1),
      ),
      child: Column(
        children: [
          Container(
            height: isFirst ? 36 : 30,
            width: isFirst ? 36 : 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleBg,
              border: Border.all(color: circleBorder, width: 2),
              boxShadow: [
                BoxShadow(
                  color: circleBorder.withAlpha(80),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$rank',
                style: GoogleFonts.dmSans(
                  color: isFirst ? AppColors.fireGold : textColor,
                  fontSize: isFirst ? 16 : 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            entry.playerName,
            style: GoogleFonts.dmSans(
              color: AppColors.warriorNavy,
              fontSize: isFirst ? 16 : 14,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${entry.points}',
            style: GoogleFonts.dmSans(
              color: isFirst ? AppColors.fireGold : AppColors.warriorNavy,
              fontSize: isFirst ? 16 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'WR ${(entry.winRate * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.dmSans(
              color: AppColors.warriorNavy.withAlpha(140),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final bool isKamu = entry.isCurrentUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isKamu ? const Color(0xFFEAF8FA) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isKamu
              ? AppColors.levelUpTeal.withAlpha(180)
              : AppColors.warriorNavy.withAlpha(30),
          width: isKamu ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isKamu
                  ? AppColors.levelUpTeal.withAlpha(40)
                  : AppColors.warriorNavy.withAlpha(20),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: GoogleFonts.dmSans(
                  color: isKamu
                      ? AppColors.levelUpTeal
                      : AppColors.warriorNavy.withAlpha(180),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.playerName,
                      style: GoogleFonts.dmSans(
                        color: AppColors.warriorNavy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isKamu) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.levelUpTeal.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.levelUpTeal),
                        ),
                        child: Text(
                          'KAMU',
                          style: GoogleFonts.orbitron(
                            color: AppColors.levelUpTeal,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'WR ${(entry.winRate * 100).toStringAsFixed(0)}%  •  Streak ${entry.streak}',
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
            '${entry.points}',
            style: GoogleFonts.dmSans(
              color: isKamu ? AppColors.levelUpTeal : AppColors.warriorNavy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.wifi_off_rounded,
            size: 32,
            color: AppColors.fireGold,
          ),
          const SizedBox(height: 8),
          const Text('Failed to load leaderboard'),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.emoji_events_outlined, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 8),
          const Text('Belum ada peringkat global.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

class _InlineInfoBanner extends StatelessWidget {
  const _InlineInfoBanner({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFECE8) : const Color(0xFFE9F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isError ? AppColors.fireGold : AppColors.levelUpTeal)
              .withAlpha(170),
        ),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.textStrong)),
    );
  }
}
