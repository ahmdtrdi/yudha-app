enum PracticeRecentActivityType { quiz, insight, interview }

class PracticeRecentActivity {
  const PracticeRecentActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.scoreLabel,
  });

  final PracticeRecentActivityType type;
  final String title;
  final String subtitle;
  final String scoreLabel;
}
