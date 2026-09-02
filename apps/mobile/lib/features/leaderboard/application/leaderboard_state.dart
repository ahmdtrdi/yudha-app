import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';

enum LeaderboardViewStatus { loading, success, empty, error }

class LeaderboardState {
  const LeaderboardState({
    required this.entries,
    required this.status,
    required this.page,
    required this.hasMore,
    required this.isLoadingMore,
    required this.currentUserRank,
    required this.currentUserEntry,
    required this.errorMessage,
    required this.target,
  });

  factory LeaderboardState.initial() {
    return const LeaderboardState(
      entries: <LeaderboardEntry>[],
      status: LeaderboardViewStatus.loading,
      page: 1,
      hasMore: false,
      isLoadingMore: false,
      currentUserRank: null,
      currentUserEntry: null,
      errorMessage: null,
      target: null,
    );
  }

  final List<LeaderboardEntry> entries;
  final LeaderboardViewStatus status;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final int? currentUserRank;
  final LeaderboardEntry? currentUserEntry;
  final String? errorMessage;
  final String? target;

  LeaderboardState copyWith({
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
    String? target,
  }) {
    return LeaderboardState(
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
      target: target ?? this.target,
    );
  }
}
