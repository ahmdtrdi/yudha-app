class InterviewLaunchConfig {
  const InterviewLaunchConfig({
    required this.companyId,
    required this.companyName,
    required this.targetRole,
    this.mode = 'coaching',
    this.language = 'id',
    this.responseStyle = 'text',
    this.resumeSessionId,
  });

  factory InterviewLaunchConfig.bumnDefault() {
    return const InterviewLaunchConfig(
      companyId: 'bank-mandiri',
      companyName: 'PT Bank Mandiri',
      targetRole: 'Officer Development Program',
      mode: 'coaching',
      language: 'id',
      responseStyle: 'text',
    );
  }

  factory InterviewLaunchConfig.cpnsDefault() {
    return const InterviewLaunchConfig(
      companyId: 'kementerian-keuangan',
      companyName: 'Kementerian Keuangan',
      targetRole: 'Staf Pengelola Keuangan Negara',
      mode: 'coaching',
      language: 'id',
      responseStyle: 'text',
    );
  }

  final String companyId;
  final String companyName;
  final String targetRole;
  final String mode;
  final String language;
  final String responseStyle;
  final String? resumeSessionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InterviewLaunchConfig &&
            other.companyId == companyId &&
            other.companyName == companyName &&
            other.targetRole == targetRole &&
            other.mode == mode &&
            other.language == language &&
            other.responseStyle == responseStyle &&
            other.resumeSessionId == resumeSessionId;
  }

  @override
  int get hashCode => Object.hash(
    companyId,
    companyName,
    targetRole,
    mode,
    language,
    responseStyle,
    resumeSessionId,
  );
}
