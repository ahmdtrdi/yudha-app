import 'package:yudha_mobile/features/leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_page_payload.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_query.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_scope.dart';

class MockLeaderboardRepository extends LeaderboardRepository {
  const MockLeaderboardRepository();

  @override
  Future<LeaderboardPagePayload> fetchPage(LeaderboardQuery query) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));

    final List<LeaderboardEntry> source = switch (query.scope) {
      LeaderboardScope.global => _globalEntries,
      LeaderboardScope.weekly => _weeklyEntries,
    };

    final int start = (query.page - 1) * query.pageSize;
    if (start >= source.length) {
      return const LeaderboardPagePayload(
        entries: <LeaderboardEntry>[],
        hasMore: false,
      );
    }

    final int end = (start + query.pageSize).clamp(0, source.length);
    return LeaderboardPagePayload(
      entries: source.sublist(start, end),
      hasMore: end < source.length,
    );
  }
}

const List<LeaderboardEntry> _globalEntries = <LeaderboardEntry>[
  LeaderboardEntry(
    playerId: 'u001',
    playerName: 'Raka',
    points: 1420,
    winRate: 0.82,
    streak: 7,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u002',
    playerName: 'Sinta',
    points: 1385,
    winRate: 0.79,
    streak: 6,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u003',
    playerName: 'Rendy',
    points: 1270,
    winRate: 0.76,
    streak: 4,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u004',
    playerName: 'Diva',
    points: 1210,
    winRate: 0.74,
    streak: 3,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u005',
    playerName: 'Alya',
    points: 1165,
    winRate: 0.71,
    streak: 2,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u006',
    playerName: 'Hafiz',
    points: 1100,
    winRate: 0.69,
    streak: 2,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u007',
    playerName: 'Nadine',
    points: 1040,
    winRate: 0.66,
    streak: 1,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u008',
    playerName: 'Bagas',
    points: 990,
    winRate: 0.64,
    streak: 1,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u009',
    playerName: 'Vina',
    points: 930,
    winRate: 0.62,
    streak: 2,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u010',
    playerName: 'Arga',
    points: 880,
    winRate: 0.6,
    streak: 1,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u011',
    playerName: 'Rani',
    points: 835,
    winRate: 0.57,
    streak: 0,
    isCurrentUser: false,
  ),
  LeaderboardEntry(
    playerId: 'u012',
    playerName: 'Gio',
    points: 790,
    winRate: 0.55,
    streak: 1,
    isCurrentUser: false,
  ),
];

const List<LeaderboardEntry> _weeklyEntries = <LeaderboardEntry>[];
