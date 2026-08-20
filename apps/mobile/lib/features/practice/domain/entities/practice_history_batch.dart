import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';

class PracticeHistoryBatch {
  const PracticeHistoryBatch({
    required this.items,
    required this.limit,
    required this.offset,
    required this.total,
  });

  final List<PracticeRecentActivity> items;
  final int limit;
  final int offset;
  final int total;

  bool get hasMore => offset + items.length < total;
}
