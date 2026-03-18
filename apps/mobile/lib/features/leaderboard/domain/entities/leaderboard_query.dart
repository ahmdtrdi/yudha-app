import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_scope.dart';

class LeaderboardQuery {
  const LeaderboardQuery({
    required this.scope,
    required this.page,
    required this.pageSize,
  });

  final LeaderboardScope scope;
  final int page;
  final int pageSize;
}
