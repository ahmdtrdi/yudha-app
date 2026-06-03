import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';

class LeaderboardPagePayload {
  const LeaderboardPagePayload({
    required this.entries,
    required this.hasMore,
    this.currentUserRank,
    this.currentUserEntry,
  });

  final List<LeaderboardEntry> entries;
  final bool hasMore;
  final int? currentUserRank;
  final LeaderboardEntry? currentUserEntry;
}
