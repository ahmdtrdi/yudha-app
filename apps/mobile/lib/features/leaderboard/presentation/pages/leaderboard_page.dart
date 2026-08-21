import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yudha_mobile/core/theme/app_colors.dart';
import 'package:yudha_mobile/features/gamification/application/player_progress_providers.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_providers.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_state.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardState = ref.watch(leaderboardControllerProvider);
    final leaderboardController = ref.read(
      leaderboardControllerProvider.notifier,
    );
    final progress = ref.watch(playerProgressProvider);
    final int? userRank =
        leaderboardState.currentUserEntry?.rank ??
        leaderboardState.currentUserRank;
    final LeaderboardEntry currentUserEntry =
        leaderboardState.currentUserEntry ??
        LeaderboardEntry(
          rank: userRank ?? 0,
          playerId: progress.playerId,
          playerName: progress.displayName.isEmpty
              ? 'Kamu'
              : progress.displayName,
          points: progress.totalPoints,
          winRate: progress.winRate,
          totalMatches: progress.matchesPlayed,
          isCurrentUser: true,
        );

    final bool isUserInLoadedList = leaderboardState.entries.any(
      (LeaderboardEntry entry) =>
          entry.isCurrentUser || entry.playerId == currentUserEntry.playerId,
    );
    final List<LeaderboardEntry> topThree = leaderboardState.entries
        .where((LeaderboardEntry entry) => entry.rank <= 3)
        .toList(growable: false);
    final List<LeaderboardEntry> otherRanks = leaderboardState.entries
        .where((LeaderboardEntry entry) => entry.rank > 3)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.scholarCream,
      appBar: AppBar(
        title: Text(
          'LEADERBOARD',
          style: GoogleFonts.fredoka(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D49B5),
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
                child: _LeaderboardPlayerStage(
                  rank: userRank,
                  name: currentUserEntry.playerName,
                  tierLabel: progress.tier.label.toUpperCase(),
                  totalPoints: currentUserEntry.points,
                  totalMatches: currentUserEntry.totalMatches,
                  winRate: currentUserEntry.winRate,
                  tierProgress: progress.tierProgress,
                  pointsUntilNextTier: progress.pointsUntilNextTier,
                  nextTierLabel: progress.nextTier?.label,
                ),
              ),
              if (leaderboardState.errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _InlineInfoBanner(
                      text: leaderboardState.errorMessage!,
                      isError: true,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _TopThreePodiumBoard(entries: topThree),
              ),
              if (otherRanks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Text(
                      'PERINGKAT LAINNYA',
                      style: GoogleFonts.fredoka(
                        color: AppColors.warriorNavy.withAlpha(150),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _LeaderboardTable(
                    entries: otherRanks,
                    surfaceKey: const ValueKey<String>(
                      'leaderboard-ranks-surface',
                    ),
                    baseKey: const ValueKey<String>(
                      'leaderboard-ranks-clay-base',
                    ),
                  ),
                ),
              ),
              if (!isUserInLoadedList &&
                  userRank != null &&
                  leaderboardState.status == LeaderboardViewStatus.success)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                        child: Text(
                          'POSISIMU',
                          style: GoogleFonts.fredoka(
                            color: AppColors.warriorNavy.withAlpha(150),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _LeaderboardTable(
                          entries: <LeaderboardEntry>[currentUserEntry],
                          surfaceKey: const ValueKey<String>(
                            'leaderboard-current-user-surface',
                          ),
                          baseKey: const ValueKey<String>(
                            'leaderboard-current-user-clay-base',
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

class _LeaderboardPlayerStage extends StatelessWidget {
  const _LeaderboardPlayerStage({
    required this.rank,
    required this.name,
    required this.tierLabel,
    required this.totalPoints,
    required this.totalMatches,
    required this.winRate,
    required this.tierProgress,
    required this.pointsUntilNextTier,
    required this.nextTierLabel,
  });

  final int? rank;
  final String name;
  final String tierLabel;
  final int totalPoints;
  final int totalMatches;
  final double winRate;
  final double tierProgress;
  final int pointsUntilNextTier;
  final String? nextTierLabel;

  @override
  Widget build(BuildContext context) {
    final _RankVisual rankVisual = _RankVisual.forRank(rank);
    final String progressLabel = nextTierLabel == null
        ? 'Tier maksimal sudah tercapai'
        : 'Menuju tier $nextTierLabel';
    final String progressValue = nextTierLabel == null
        ? 'MAKSIMAL'
        : '$pointsUntilNextTier poin lagi';

    return ColoredBox(
      color: AppColors.scholarCream,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              key: ValueKey<String>('leaderboard-stage-clay-base'),
              decoration: BoxDecoration(
                color: Color(0xFF06378F),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
            ),
          ),
          Container(
            key: const ValueKey<String>('leaderboard-stage-surface'),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF0D49B5),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFF087C9E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF75E0E8),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
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
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              tierLabel,
                              style: GoogleFonts.dmSans(
                                color: AppColors.fireGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      key: const ValueKey<String>('leaderboard-rank-medallion'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: rankVisual.fill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: rankVisual.accent),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            rank != null && rank! > 0 ? '#$rank' : '-',
                            style: GoogleFonts.jetBrainsMono(
                              color: rankVisual.accent,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'GLOBAL',
                            style: TextStyle(
                              color: rankVisual.accent,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StageStat(
                        label: 'RANK POINTS',
                        value: '$totalPoints',
                      ),
                    ),
                    const _StageStatDivider(),
                    Expanded(
                      child: _StageStat(
                        label: 'WIN RATE',
                        value: '${(winRate * 100).toStringAsFixed(0)}%',
                      ),
                    ),
                    const _StageStatDivider(),
                    Expanded(
                      child: _StageStat(
                        label: 'PERTANDINGAN',
                        value: '$totalMatches',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        progressLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFFC7D9FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      progressValue,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF07368D),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: tierProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.levelUpTeal, AppColors.fireGold],
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
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

class _StageStat extends StatelessWidget {
  const _StageStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
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
          style: GoogleFonts.dmSans(
            color: const Color(0xFFC7D9FF),
            fontSize: 9,
            letterSpacing: 0,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _StageStatDivider extends StatelessWidget {
  const _StageStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _TopThreePodiumBoard extends StatelessWidget {
  const _TopThreePodiumBoard({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    LeaderboardEntry? entryForRank(int rank) {
      for (final LeaderboardEntry entry in entries) {
        if (entry.rank == rank) return entry;
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: 7,
            child: DecoratedBox(
              key: const ValueKey<String>('leaderboard-podium-clay-base'),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DC),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Container(
            key: const ValueKey<String>('leaderboard-podium-surface'),
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE7E9ED)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: _PodiumPlace(entry: entryForRank(2), rank: 2),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _PodiumPlace(
                        entry: entryForRank(1),
                        rank: 1,
                        isFirst: true,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _PodiumPlace(entry: entryForRank(3), rank: 3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.entry,
    required this.rank,
    this.isFirst = false,
  });

  final LeaderboardEntry? entry;
  final int rank;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final _RankVisual visual = _RankVisual.forRank(rank);
    final Color accent = visual.accent;
    final Color fill = visual.fill;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (isFirst)
          Icon(Icons.workspace_premium_rounded, color: accent, size: 22)
        else
          const SizedBox(height: 22),
        const SizedBox(height: 3),
        Container(
          width: isFirst ? 46 : 40,
          height: isFirst ? 46 : 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2),
          ),
          child: Text(
            '$rank',
            style: GoogleFonts.dmSans(
              color: accent,
              fontSize: isFirst ? 18 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          entry?.playerName ?? '-',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: AppColors.warriorNavy,
            fontSize: isFirst ? 14 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          entry == null ? '-' : '${entry!.points} pts',
          style: GoogleFonts.dmSans(
            color: accent,
            fontSize: isFirst ? 14 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          entry == null
              ? 'Belum tersedia'
              : 'WR ${(entry!.winRate * 100).toStringAsFixed(0)}%',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: isFirst ? 58 : 42,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(top: BorderSide(color: accent, width: 2)),
          ),
          child: Text(
            '#$rank',
            style: GoogleFonts.jetBrainsMono(
              color: accent,
              fontSize: isFirst ? 18 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankVisual {
  const _RankVisual({required this.fill, required this.accent});

  final Color fill;
  final Color accent;

  factory _RankVisual.forRank(int? rank) {
    return switch (rank) {
      1 => const _RankVisual(
        fill: Color(0xFFFFE7C7),
        accent: Color(0xFFE89A4F),
      ),
      2 => const _RankVisual(
        fill: Color(0xFFE8EDF2),
        accent: Color(0xFF73879B),
      ),
      3 => const _RankVisual(
        fill: Color(0xFFF1E5D8),
        accent: Color(0xFFC49A70),
      ),
      final int value when value > 3 => const _RankVisual(
        fill: Color(0xFFE4EEFF),
        accent: Color(0xFF315A9B),
      ),
      _ => const _RankVisual(
        fill: Color(0xFFF0F2F6),
        accent: Color(0xFF7C8797),
      ),
    };
  }
}

class _LeaderboardTable extends StatelessWidget {
  const _LeaderboardTable({
    required this.entries,
    required this.surfaceKey,
    required this.baseKey,
  });

  final List<LeaderboardEntry> entries;
  final Key surfaceKey;
  final Key baseKey;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: <Widget>[
        Positioned.fill(
          top: 7,
          child: DecoratedBox(
            key: baseKey,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DC),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
        Container(
          key: surfaceKey,
          margin: const EdgeInsets.only(bottom: 7),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7E9ED)),
          ),
          child: Column(
            children: <Widget>[
              for (int index = 0; index < entries.length; index++) ...<Widget>[
                _LeaderboardRow(entry: entries[index]),
                if (index < entries.length - 1)
                  const Divider(
                    height: 1,
                    indent: 58,
                    endIndent: 14,
                    color: Color(0xFFE7E9ED),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = entry.isCurrentUser;

    return ColoredBox(
      color: isCurrentUser ? const Color(0xFFE7F5F8) : Colors.white,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 14),
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentUser
                  ? const Color(0xFFBFEFF4)
                  : const Color(0xFFF0F2F6),
            ),
            child: Text(
              '${entry.rank}',
              style: GoogleFonts.dmSans(
                color: isCurrentUser
                    ? const Color(0xFF087C9E)
                    : AppColors.warriorNavy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          entry.playerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: AppColors.warriorNavy,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...<Widget>[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBFEFF4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'KAMU',
                            style: TextStyle(
                              color: Color(0xFF087C9E),
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'WR ${(entry.winRate * 100).toStringAsFixed(0)}%  •  ${entry.totalMatches} pertandingan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${entry.points}',
                style: GoogleFonts.jetBrainsMono(
                  color: isCurrentUser
                      ? const Color(0xFF087C9E)
                      : AppColors.warriorNavy,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'PTS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
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
          const Text(
            'Leaderboard belum dapat dimuat.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
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
          const Icon(
            Icons.emoji_events_outlined,
            size: 34,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          const Text(
            'Belum ada peringkat global.',
            textAlign: TextAlign.center,
          ),
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
