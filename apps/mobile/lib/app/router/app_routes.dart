abstract final class AppRoutes {
  static const String returnToQueryParameter = 'returnTo';

  static const String splash = '/splash';
  static const String login = '/login';
  static const String profileSetup = '/profile-setup';
  static const String confirmEmail = '/confirm-email';
  static const String lobby = '/';
  static const String pvp = '/pvp';
  static const String leaderboard = '/leaderboard';
  static const String analytics = '/analytics';
  static const String solo = '/solo';
  static const String soloHistory = '/solo/history';
  static const String soloSession = '/solo/session';
  static const String profile = '/profile';
  static const String interview = '/interview';
  static const String interviewSession = '/interview/session';
  static const String store = '/store';
  static const String hiredPass = '/hired-pass';

  static const String legacyPractice = '/practice';
  static const String legacyPracticeHistory = '/practice/history';
  static const String legacyPracticeQuiz = '/practice/quiz';
  static const String legacyInterviewSetup = '/interview/setup';

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
    analytics,
    solo,
    soloHistory,
    soloSession,
    profile,
    interview,
    interviewSession,
    store,
    hiredPass,
    legacyPractice,
    legacyPracticeHistory,
    legacyPracticeQuiz,
    legacyInterviewSetup,
  };

  static bool isPrivate(Uri uri) => privatePaths.contains(uri.path);

  static String? canonicalLocation(Uri uri) {
    final String? canonicalPath = switch (uri.path) {
      legacyPractice => solo,
      legacyPracticeHistory => soloHistory,
      legacyPracticeQuiz => soloSession,
      legacyInterviewSetup => interview,
      _ => null,
    };
    return canonicalPath == null
        ? null
        : uri.replace(path: canonicalPath).toString();
  }

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
