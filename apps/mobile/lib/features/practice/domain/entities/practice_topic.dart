class PracticeTopic {
  const PracticeTopic({
    required this.id,
    required this.name,
    required this.description,
    this.isLocked = false,
  });

  final String id;
  final String name;
  final String description;
  final bool isLocked;
}
