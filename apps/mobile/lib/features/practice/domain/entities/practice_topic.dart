class PracticeTopic {
  const PracticeTopic({
    required this.id,
    required this.name,
    required this.description,
    required this.groupTitle,
    this.badgeLabel,
    this.questionCount = 0,
    this.isLocked = false,
  });

  final String id;
  final String name;
  final String description;
  final String groupTitle;
  final String? badgeLabel;
  final int questionCount;
  final bool isLocked;
}
