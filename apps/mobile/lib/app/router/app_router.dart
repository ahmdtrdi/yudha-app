import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/app/router/app_tab_shell.dart';
import 'package:yudha_mobile/features/interview/presentation/pages/interview_page.dart';
import 'package:yudha_mobile/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:yudha_mobile/features/lobby/presentation/pages/lobby_page.dart';
import 'package:yudha_mobile/features/onboarding/presentation/pages/splash_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_page.dart';
import 'package:yudha_mobile/features/practice/presentation/pages/practice_quiz_page.dart';
import 'package:yudha_mobile/features/profile/presentation/pages/profile_onboarding_page.dart';
import 'package:yudha_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:yudha_mobile/features/pvp/presentation/pages/pvp_page.dart';
import 'package:yudha_mobile/features/store/presentation/pages/store_page.dart';
import 'package:yudha_mobile/features/auth/presentation/pages/login_page.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>(
  (Ref ref) => GoRouter(
    initialLocation: AppRoutes.splash,
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
            builder: (context, state) => const PracticePage(),
          ),
          GoRoute(
            path: AppRoutes.practiceQuiz,
            builder: (context, state) => const PracticeQuizPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.interview,
        builder: (context, state) => const InterviewPage(),
      ),
      GoRoute(
        path: AppRoutes.store,
        builder: (context, state) => const StorePage(),
      ),
    ],
  ),
);
