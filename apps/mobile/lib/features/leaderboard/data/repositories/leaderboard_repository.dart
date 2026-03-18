import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_page_payload.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_query.dart';

abstract class LeaderboardRepository {
  const LeaderboardRepository();

  Future<LeaderboardPagePayload> fetchPage(LeaderboardQuery query);
}
