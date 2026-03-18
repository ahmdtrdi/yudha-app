import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';

class LeaderboardPagePayload {
  const LeaderboardPagePayload({required this.entries, required this.hasMore});

  final List<LeaderboardEntry> entries;
  final bool hasMore;
}
