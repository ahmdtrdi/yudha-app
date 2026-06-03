class InterviewLaunchConfig {
  const InterviewLaunchConfig({
    required this.companyId,
    required this.companyName,
    required this.targetRole,
    this.mode = 'coaching',
    this.language = 'id',
  });

  factory InterviewLaunchConfig.bumnDefault() {
    return const InterviewLaunchConfig(
      companyId: 'bank-mandiri',
      companyName: 'PT Bank Mandiri',
      targetRole: 'Officer Development Program',
    );
  }

  factory InterviewLaunchConfig.cpnsDefault() {
    return const InterviewLaunchConfig(
      companyId: 'kementerian-keuangan',
      companyName: 'Kementerian Keuangan',
      targetRole: 'Staf Pengelola Keuangan Negara',
    );
  }

  final String companyId;
  final String companyName;
  final String targetRole;
  final String mode;
  final String language;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InterviewLaunchConfig &&
            other.companyId == companyId &&
            other.companyName == companyName &&
            other.targetRole == targetRole &&
            other.mode == mode &&
            other.language == language;
  }

  @override
  int get hashCode =>
      Object.hash(companyId, companyName, targetRole, mode, language);
}
