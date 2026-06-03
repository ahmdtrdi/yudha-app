import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_scope.dart';

enum LeaderboardViewStatus { loading, success, empty, error }

class LeaderboardState {
  const LeaderboardState({
    required this.scope,
    required this.entries,
    required this.status,
    required this.page,
    required this.hasMore,
    required this.isLoadingMore,
    required this.currentUserRank,
    required this.currentUserEntry,
    required this.errorMessage,
  });

  factory LeaderboardState.initial() {
    return const LeaderboardState(
      scope: LeaderboardScope.global,
      entries: <LeaderboardEntry>[],
      status: LeaderboardViewStatus.loading,
      page: 1,
      hasMore: false,
      isLoadingMore: false,
      currentUserRank: null,
      currentUserEntry: null,
      errorMessage: null,
    );
  }

  final LeaderboardScope scope;
  final List<LeaderboardEntry> entries;
  final LeaderboardViewStatus status;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final int? currentUserRank;
  final LeaderboardEntry? currentUserEntry;
  final String? errorMessage;

  LeaderboardState copyWith({
    LeaderboardScope? scope,
    List<LeaderboardEntry>? entries,
    LeaderboardViewStatus? status,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    int? currentUserRank,
    LeaderboardEntry? currentUserEntry,
    bool clearCurrentUser = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LeaderboardState(
      scope: scope ?? this.scope,
      entries: entries ?? this.entries,
      status: status ?? this.status,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentUserRank: clearCurrentUser
          ? null
          : currentUserRank ?? this.currentUserRank,
      currentUserEntry: clearCurrentUser
          ? null
          : currentUserEntry ?? this.currentUserEntry,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
