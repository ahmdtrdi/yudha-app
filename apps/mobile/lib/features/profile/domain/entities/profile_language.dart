enum ProfileLanguage {
  id('id', 'Bahasa Indonesia'),
  en('en', 'English');

  const ProfileLanguage(this.code, this.label);

  final String code;
  final String label;
}
