import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_state.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_query.dart';

class LeaderboardController extends StateNotifier<LeaderboardState> {
  LeaderboardController({required LeaderboardRepository repository})
    : _repository = repository,
      super(LeaderboardState.initial()) {
    loadInitial();
  }

  final LeaderboardRepository _repository;

  static const int pageSize = 8;

  Future<void> loadInitial() async {
    state = state.copyWith(
      status: LeaderboardViewStatus.loading,
      entries: const <LeaderboardEntry>[],
      page: 1,
      hasMore: false,
      isLoadingMore: false,
      clearCurrentUser: true,
      clearError: true,
    );
    await _fetchPage(page: 1, append: false);
  }

  Future<void> refresh() async {
    await _fetchPage(page: 1, append: false);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);
    await _fetchPage(page: state.page + 1, append: true);
  }

  Future<void> _fetchPage({required int page, required bool append}) async {
    try {
      final payload = await _repository.fetchPage(
        LeaderboardQuery(page: page, pageSize: pageSize),
      );

      final List<LeaderboardEntry> entries = append
          ? <LeaderboardEntry>[...state.entries, ...payload.entries]
          : payload.entries;

      final bool isEmpty = entries.isEmpty;

      state = state.copyWith(
        entries: entries,
        page: page,
        hasMore: payload.hasMore,
        isLoadingMore: false,
        currentUserRank: payload.currentUserRank,
        currentUserEntry: payload.currentUserEntry,
        status: isEmpty
            ? LeaderboardViewStatus.empty
            : LeaderboardViewStatus.success,
        clearError: true,
      );
    } catch (_) {
      final LeaderboardViewStatus fallbackStatus = state.entries.isEmpty
          ? LeaderboardViewStatus.error
          : LeaderboardViewStatus.success;

      state = state.copyWith(
        status: fallbackStatus,
        isLoadingMore: false,
        errorMessage: 'Gagal memuat leaderboard. Coba lagi.',
      );
    }
  }
}
