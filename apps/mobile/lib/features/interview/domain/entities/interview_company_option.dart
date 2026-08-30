class InterviewCompanyOption {
  const InterviewCompanyOption({
    required this.id,
    required this.name,
    this.defaultRole,
  });

  final String id;
  final String name;
  final String? defaultRole;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InterviewCompanyOption &&
            other.id == id &&
            other.name == name &&
            other.defaultRole == defaultRole;
  }

  @override
  int get hashCode => Object.hash(id, name, defaultRole);
}
