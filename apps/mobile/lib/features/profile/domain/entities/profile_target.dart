enum ProfileTarget {
  cpns,
  bumn;

  String get label => switch (this) {
    ProfileTarget.cpns => 'CPNS',
    ProfileTarget.bumn => 'BUMN',
  };

  String get arenaId => 'arena-$name';

  bool allowsArena(String arenaId) => arenaId == this.arenaId;
}
