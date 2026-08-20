import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';

enum PracticeHistoryViewStatus { loading, success, empty, error }

class PracticeHistoryState {
  const PracticeHistoryState({
    required this.status,
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.errorMessage,
  });

  factory PracticeHistoryState.initial() {
    return const PracticeHistoryState(
      status: PracticeHistoryViewStatus.loading,
      items: <PracticeRecentActivity>[],
      hasMore: false,
      isLoadingMore: false,
      errorMessage: null,
    );
  }

  final PracticeHistoryViewStatus status;
  final List<PracticeRecentActivity> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  PracticeHistoryState copyWith({
    PracticeHistoryViewStatus? status,
    List<PracticeRecentActivity>? items,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PracticeHistoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
