enum ProgressTier {
  rookie,
  warrior,
  elite,
  legend;

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
}
