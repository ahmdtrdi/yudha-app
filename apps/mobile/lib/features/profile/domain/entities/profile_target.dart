enum ProfileTarget {
  cpns,
  bumn;

  String get label => switch (this) {
    ProfileTarget.cpns => 'CPNS',
    ProfileTarget.bumn => 'BUMN',
  };
}
