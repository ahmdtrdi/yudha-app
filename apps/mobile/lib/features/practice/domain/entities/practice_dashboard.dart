import 'package:yudha_mobile/features/practice/domain/entities/practice_recent_activity.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_topic.dart';

class PracticeDashboard {
  const PracticeDashboard({
    required this.topics,
    required this.overallProgressPercent,
    required this.recentActivities,
  });

  final List<PracticeTopic> topics;
  final int overallProgressPercent;
  final List<PracticeRecentActivity> recentActivities;
}
