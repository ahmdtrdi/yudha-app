enum ProgressTier {
  rookie(0),
  warrior(400),
  elite(800),
  legend(1200);

  const ProgressTier(this.minPoints);

  final int minPoints;

  String get label => switch (this) {
    ProgressTier.rookie => 'Rookie',
    ProgressTier.warrior => 'Warrior',
    ProgressTier.elite => 'Elite',
    ProgressTier.legend => 'Legend',
  };

  static ProgressTier fromPoints(int points) {
    if (points >= 1200) {
      return ProgressTier.legend;
    }
    if (points >= 800) {
      return ProgressTier.elite;
    }
    if (points >= 400) {
      return ProgressTier.warrior;
    }
    return ProgressTier.rookie;
  }

  ProgressTier? get nextTier => switch (this) {
    ProgressTier.rookie => ProgressTier.warrior,
    ProgressTier.warrior => ProgressTier.elite,
    ProgressTier.elite => ProgressTier.legend,
    ProgressTier.legend => null,
  };
}
