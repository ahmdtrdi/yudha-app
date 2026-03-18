enum LeaderboardScope {
  global,
  weekly;

  String get label => switch (this) {
    LeaderboardScope.global => 'Global',
    LeaderboardScope.weekly => 'Weekly',
  };
}
