import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/practice/application/practice_history_state.dart';
import 'package:yudha_mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_history_batch.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';

class PracticeHistoryController extends StateNotifier<PracticeHistoryState> {
  PracticeHistoryController({required PracticeRepository repository})
    : _repository = repository,
      super(PracticeHistoryState.initial()) {
    loadInitial();
  }

  static const int pageSize = 20;

  final PracticeRepository _repository;

  Future<void> loadInitial() async {
    state = state.copyWith(
      status: PracticeHistoryViewStatus.loading,
      items: const <PracticeRecentActivity>[],
      hasMore: false,
      isLoadingMore: false,
      clearError: true,
    );
    await _fetch(offset: 0, append: false);
  }

  Future<void> refresh() => _fetch(offset: 0, append: false);

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearError: true);
    await _fetch(offset: state.items.length, append: true);
  }

  Future<void> _fetch({required int offset, required bool append}) async {
    try {
      final PracticeHistoryBatch batch = await _repository.fetchHistory(
        limit: pageSize,
        offset: offset,
      );
      final List<PracticeRecentActivity> items = append
          ? <PracticeRecentActivity>[...state.items, ...batch.items]
          : batch.items;
      state = state.copyWith(
        status: items.isEmpty
            ? PracticeHistoryViewStatus.empty
            : PracticeHistoryViewStatus.success,
        items: items,
        hasMore: batch.hasMore,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        status: state.items.isEmpty
            ? PracticeHistoryViewStatus.error
            : PracticeHistoryViewStatus.success,
        isLoadingMore: false,
        errorMessage: 'Gagal memuat riwayat latihan. Coba lagi.',
      );
    }
  }
}
