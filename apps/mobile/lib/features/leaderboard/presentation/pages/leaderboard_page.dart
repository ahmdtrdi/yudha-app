import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            _ProgressCard(
              tierLabel: progress.tier.label,
              totalPoints: progress.totalPoints,
              streak: progress.streak,
              winRate: progress.winRate,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<LeaderboardScope>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<LeaderboardScope>>[
                  ButtonSegment<LeaderboardScope>(
                    value: LeaderboardScope.global,
                    label: Text('Global'),
                  ),
                  ButtonSegment<LeaderboardScope>(
                    value: LeaderboardScope.weekly,
                    label: Text('Weekly'),
                  ),
                ],
                selected: <LeaderboardScope>{leaderboardState.scope},
                onSelectionChanged: (Set<LeaderboardScope> selected) {
                  leaderboardController.setScope(selected.first);
                },
              ),
            ),
            const SizedBox(height: 8),
            if (leaderboardState.errorMessage != null &&
                leaderboardState.status == LeaderboardViewStatus.success)
              _InlineInfoBanner(
                text: leaderboardState.errorMessage!,
                isError: true,
              ),
            Expanded(
              child: switch (leaderboardState.status) {
                LeaderboardViewStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                LeaderboardViewStatus.error => _ErrorState(
                  onRetry: () {
                    leaderboardController.loadInitial();
                  },
                ),
                LeaderboardViewStatus.empty => _EmptyState(
                  scope: leaderboardState.scope,
                  onRefresh: () {
                    leaderboardController.refresh();
                  },
                ),
                LeaderboardViewStatus.success => RefreshIndicator(
                  onRefresh: leaderboardController.refresh,
                  child: ListView.separated(
                    itemCount:
                        leaderboardState.entries.length +
                        (leaderboardState.hasMore ? 1 : 0) +
                        (leaderboardState.isLoadingMore ? 1 : 0),
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      if (index < leaderboardState.entries.length) {
                        final LeaderboardEntry entry =
                            leaderboardState.entries[index];
                        return _LeaderboardTile(rank: index + 1, entry: entry);
                      }

                      final int loadMoreIndex = leaderboardState.entries.length;
                      if (leaderboardState.hasMore && index == loadMoreIndex) {
                        return OutlinedButton.icon(
                          onPressed: leaderboardController.loadMore,
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Load More'),
                        );
                      }

                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.tierLabel,
    required this.totalPoints,
    required this.streak,
    required this.winRate,
  });

  final String tierLabel;
  final int totalPoints;
  final int streak;
  final double winRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.warriorNavy, Color(0xFF0E4AAE)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Your Progress',
            style: TextStyle(
              color: AppColors.scholarCream,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$tierLabel • $totalPoints pts',
            style: const TextStyle(
              color: AppColors.scholarCream,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Winrate ${(winRate * 100).toStringAsFixed(0)}%  •  Streak $streak',
            style: TextStyle(color: AppColors.scholarCream.withAlpha(220)),
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
    final Color borderColor = entry.isCurrentUser
        ? AppColors.levelUpTeal
        : AppColors.warriorNavy.withAlpha(45);

    return Container(
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? const Color(0xFFEAF8FA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: entry.isCurrentUser ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.warriorNavy,
          foregroundColor: AppColors.scholarCream,
          child: Text('$rank'),
        ),
        title: Text(
          entry.playerName,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: entry.isCurrentUser
                ? AppColors.warriorNavy
                : AppColors.textStrong,
          ),
        ),
        subtitle: Text(
          'WR ${(entry.winRate * 100).toStringAsFixed(0)}%  •  Streak ${entry.streak}',
        ),
        trailing: Text(
          '${entry.points}',
          style: const TextStyle(
            color: AppColors.warriorNavy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
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
  const _EmptyState({required this.scope, required this.onRefresh});

  final LeaderboardScope scope;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final String message = switch (scope) {
      LeaderboardScope.global => 'No players found yet.',
      LeaderboardScope.weekly => 'No weekly records yet. Play a match first.',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.emoji_events_outlined,
            size: 34,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
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
