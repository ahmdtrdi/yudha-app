abstract final class AppRoutes {
  static const String returnToQueryParameter = 'returnTo';

  static const String splash = '/splash';
  static const String login = '/login';
  static const String profileSetup = '/profile-setup';
  static const String confirmEmail = '/confirm-email';
  static const String lobby = '/';
  static const String pvp = '/pvp';
  static const String leaderboard = '/leaderboard';
  static const String practice = '/practice';
  static const String practiceQuiz = '/practice/quiz';
  static const String profile = '/profile';
  static const String interviewSetup = '/interview/setup';
  static const String interview = '/interview';
  static const String store = '/store';
  static const String hiredPass = '/hired-pass';

  static const Set<String> publicPaths = <String>{
    splash,
    login,
    profileSetup,
    confirmEmail,
  };

  static const Set<String> privatePaths = <String>{
    lobby,
    pvp,
    leaderboard,
    practice,
    practiceQuiz,
    profile,
    interviewSetup,
    interview,
    store,
    hiredPass,
  };

  static bool isPrivate(Uri uri) => privatePaths.contains(uri.path);

  static String loginFor(Uri intendedDestination) {
    return Uri(
      path: login,
      queryParameters: <String, String>{
        returnToQueryParameter: intendedDestination.toString(),
      },
    ).toString();
  }

  static String postLoginDestination(Uri loginUri) {
    final String? rawDestination =
        loginUri.queryParameters[returnToQueryParameter];
    if (rawDestination == null || rawDestination.trim().isEmpty) {
      return lobby;
    }
    final Uri? destination = Uri.tryParse(rawDestination);
    if (destination == null ||
        destination.hasScheme ||
        destination.hasAuthority ||
        !destination.path.startsWith('/') ||
        destination.path.startsWith('//') ||
        !isPrivate(destination)) {
      return lobby;
    }
    return destination.toString();
  }
}
