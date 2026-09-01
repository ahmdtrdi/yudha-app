import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/app/router/app_tab_shell.dart';
import 'package:yudha_mobile/features/auth/application/auth_providers.dart';
import 'package:yudha_mobile/features/auth/presentation/pages/email_confirmation_pending_page.dart';
import 'package:yudha_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/presentation/pages/interview_page.dart';
import 'package:yudha_mobile/features/interview/presentation/pages/interview_setup_page.dart';
import 'package:yudha_mobile/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:yudha_mobile/features/learning/presentation/pages/learning_page.dart';
import 'package:yudha_mobile/features/lobby/presentation/pages/lobby_page.dart';
import 'package:yudha_mobile/features/onboarding/presentation/pages/splash_page.dart';
import 'package:yudha_mobile/features/pass/presentation/pages/hired_pass_page.dart';
import 'package:yudha_mobile/features/practice/domain/entities/practice_launch_request.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_history_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_quiz_page.dart';
import 'package:yudha_mobile/features/profile/presentation/pages/profile_onboarding_page.dart';
import 'package:yudha_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:yudha_mobile/features/pvp/presentation/pages/pvp_page.dart';
import 'package:yudha_mobile/features/store/presentation/pages/store_page.dart';

String? appRedirect({required bool isAuthenticated, required Uri uri}) {
  final String location = uri.path;
  if (!isAuthenticated && AppRoutes.isPrivate(uri)) {
    return AppRoutes.loginFor(uri);
  }
  if (isAuthenticated && location == AppRoutes.login) {
    return AppRoutes.postLoginDestination(uri);
  }
  if (isAuthenticated &&
      (location == AppRoutes.profileSetup ||
          location == AppRoutes.confirmEmail)) {
    return AppRoutes.lobby;
  }
  return null;
}

String appInitialLocation() {
  if (kIsWeb &&
      Uri.base.queryParameters.containsKey('notificationDeliveryId') &&
      AppRoutes.isPrivate(Uri.base)) {
    return Uri.base.toString();
  }
  return AppRoutes.splash;
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<AppAuthState> authRefresh = ValueNotifier<AppAuthState>(
    ref.read(authProvider),
  );
  ref.listen<AppAuthState>(authProvider, (_, AppAuthState next) {
    authRefresh.value = next;
  });
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: appInitialLocation(),
    refreshListenable: authRefresh,
    redirect: (context, state) {
      return appRedirect(
        isAuthenticated: authRefresh.value.isAuthenticated,
        uri: state.uri,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileOnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.confirmEmail,
        builder: (context, state) => EmailConfirmationPendingPage(
          email: state.extra is String ? state.extra as String : null,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppTabShell(location: state.uri.path, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.lobby,
            builder: (context, state) => const LobbyPage(),
          ),
          GoRoute(
            path: AppRoutes.pvp,
            builder: (context, state) => const PvpPage(),
          ),
          GoRoute(
            path: AppRoutes.leaderboard,
            builder: (context, state) => const LeaderboardPage(),
          ),
          GoRoute(
            path: AppRoutes.practice,
            builder: (context, state) => PracticePage(
              launchRequest: state.extra is PracticeLaunchRequest
                  ? state.extra as PracticeLaunchRequest
                  : null,
              focusCategory: state.extra is String
                  ? state.extra as String
                  : null,
            ),
          ),
          GoRoute(
            path: AppRoutes.practiceQuiz,
            builder: (context, state) => const PracticeQuizPage(),
          ),
          GoRoute(
            path: AppRoutes.practiceHistory,
            builder: (context, state) => const PracticeHistoryPage(),
          ),
          GoRoute(
            path: AppRoutes.learning,
            builder: (context, state) => const LearningPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.interviewSetup,
        builder: (context, state) => const InterviewSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.interview,
        builder: (context, state) {
          final Object? extra = state.extra;
          return InterviewPage(
            config: extra is InterviewLaunchConfig
                ? extra
                : InterviewLaunchConfig.bumnDefault(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.store,
        builder: (context, state) => const StorePage(),
      ),
      GoRoute(
        path: AppRoutes.hiredPass,
        builder: (context, state) => const HiredPassPage(),
      ),
    ],
  );
});
