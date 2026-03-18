import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/gamification/domain/entities/player_progress.dart';
import 'package:yudha_mobile/features/leaderboard/application/leaderboard_state.dart';
import 'package:yudha_mobile/features/leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_query.dart';
import 'package:yudha_mobile/features/leaderboard/domain/entities/leaderboard_scope.dart';

class LeaderboardController extends StateNotifier<LeaderboardState> {
  LeaderboardController({
    required LeaderboardRepository repository,
    required PlayerProgress currentProgress,
  }) : _repository = repository,
       _currentProgress = currentProgress,
       super(LeaderboardState.initial()) {
    loadInitial();
  }

  final LeaderboardRepository _repository;
  final PlayerProgress _currentProgress;

  static const int pageSize = 8;

  Future<void> loadInitial() async {
    state = state.copyWith(
      status: LeaderboardViewStatus.loading,
      entries: const <LeaderboardEntry>[],
      page: 1,
      hasMore: false,
      isLoadingMore: false,
      clearError: true,
    );
    await _fetchPage(page: 1, append: false);
  }

  Future<void> refresh() async {
    await _fetchPage(page: 1, append: false);
  }

  Future<void> setScope(LeaderboardScope scope) async {
    if (scope == state.scope) {
      return;
    }

    state = state.copyWith(
      scope: scope,
      status: LeaderboardViewStatus.loading,
      entries: const <LeaderboardEntry>[],
      page: 1,
      hasMore: false,
      clearError: true,
    );
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
        LeaderboardQuery(scope: state.scope, page: page, pageSize: pageSize),
      );

      final List<LeaderboardEntry> baseEntries = append
          ? <LeaderboardEntry>[...state.entries, ...payload.entries]
          : payload.entries;
      final List<LeaderboardEntry> normalizedEntries = _normalizeEntries(
        baseEntries,
      );

      final bool isEmpty = normalizedEntries.isEmpty;

      state = state.copyWith(
        entries: normalizedEntries,
        page: page,
        hasMore: payload.hasMore,
        isLoadingMore: false,
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

  List<LeaderboardEntry> _normalizeEntries(List<LeaderboardEntry> entries) {
    final List<LeaderboardEntry> mutable = entries
        .where(
          (LeaderboardEntry entry) =>
              entry.playerId != _currentProgress.playerId,
        )
        .toList(growable: true);

    if (state.scope == LeaderboardScope.global) {
      mutable.add(
        LeaderboardEntry(
          playerId: _currentProgress.playerId,
          playerName: _currentProgress.displayName,
          points: _currentProgress.totalPoints,
          winRate: _currentProgress.winRate,
          streak: _currentProgress.streak,
          isCurrentUser: true,
        ),
      );
    }

    mutable.sort((LeaderboardEntry a, LeaderboardEntry b) {
      return b.points.compareTo(a.points);
    });

    return mutable;
  }
}
