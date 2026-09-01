import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yudha_mobile/app/router/app_routes.dart';
import 'package:yudha_mobile/features/interview/application/interview_providers.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_company_option.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_launch_config.dart';
import 'package:yudha_mobile/features/interview/domain/entities/interview_session_record.dart';
import 'package:yudha_mobile/features/interview/presentation/pages/interview_setup_page.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

void main() {
  testWidgets('renders redesigned setup and preserves launch configuration', (
    WidgetTester tester,
  ) async {
    InterviewLaunchConfig? launchedConfig;
    await _pumpSetup(
      tester,
      onLaunch: (InterviewLaunchConfig config) => launchedConfig = config,
    );

    expect(find.byKey(const Key('interview-setup-hero')), findsOneWidget);
    expect(find.text('PERSIAPAN BUMN'), findsOneWidget);
    expect(find.text('Bangun sesi interviewmu'), findsOneWidget);
    expect(find.text('Target interview'), findsOneWidget);
    expect(find.text('Pilih mode'), findsOneWidget);
    expect(find.text('Cara menjawab'), findsOneWidget);
    expect(find.byKey(const Key('interview-mode-coaching')), findsOneWidget);
    expect(find.byKey(const Key('interview-mode-realistic')), findsOneWidget);
    expect(find.byKey(const Key('interview-response-text')), findsOneWidget);
    expect(find.byKey(const Key('interview-response-voice')), findsOneWidget);

    await tester.tap(find.byKey(const Key('interview-company-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank Indonesia').last);
    await tester.pumpAndSettle();
    expect(find.text('Asisten Manajer'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('interview-role-field')),
      'Product Manager',
    );
    await tester.ensureVisible(
      find.byKey(const Key('interview-mode-realistic')),
    );
    await tester.tap(find.byKey(const Key('interview-mode-realistic')));
    await tester.ensureVisible(
      find.byKey(const Key('interview-response-voice')),
    );
    await tester.tap(find.byKey(const Key('interview-response-voice')));
    await tester.ensureVisible(find.byKey(const Key('start-interview-button')));
    await tester.tap(find.byKey(const Key('start-interview-button')));
    await tester.pumpAndSettle();

    expect(launchedConfig?.companyId, 'bank-indonesia');
    expect(launchedConfig?.targetRole, 'Product Manager');
    expect(launchedConfig?.mode, 'realistic');
    expect(launchedConfig?.responseStyle, 'voice');
    expect(find.text('Interview launched'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders and resumes an unfinished session', (
    WidgetTester tester,
  ) async {
    InterviewLaunchConfig? launchedConfig;
    final DateTime timestamp = DateTime(2026, 8, 25);
    await _pumpSetup(
      tester,
      sessions: <InterviewSessionSummaryRecord>[
        InterviewSessionSummaryRecord(
          sessionId: 'session-active',
          status: 'active',
          companyId: 'bank-indonesia',
          targetRole: 'Asisten Manajer',
          mode: 'coaching',
          language: 'id',
          responseStyle: 'text',
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ],
      onLaunch: (InterviewLaunchConfig config) => launchedConfig = config,
    );

    expect(find.text('LANJUTKAN SESI'), findsOneWidget);
    expect(find.text('Bank Indonesia'), findsOneWidget);
    expect(
      find.byKey(const Key('resume-interview-session-active')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('resume-interview-session-active')));
    await tester.pumpAndSettle();

    expect(launchedConfig?.resumeSessionId, 'session-active');
    expect(launchedConfig?.companyId, 'bank-indonesia');
    expect(launchedConfig?.targetRole, 'Asisten Manajer');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows every backend company to a CPNS user', (
    WidgetTester tester,
  ) async {
    await _pumpSetup(tester, target: ProfileTarget.cpns, onLaunch: (_) {});

    expect(find.text('PERSIAPAN CPNS'), findsOneWidget);
    await tester.tap(find.byKey(const Key('interview-company-field')));
    await tester.pumpAndSettle();

    expect(find.text('Bank Indonesia'), findsWidgets);
    expect(find.text('Kementerian Keuangan Republik Indonesia'), findsWidgets);
    expect(find.text('PT Aviasi Pariwisata Indonesia (Persero)'), findsWidgets);
  });

  testWidgets('requires a role when the company has no suggestion', (
    WidgetTester tester,
  ) async {
    InterviewLaunchConfig? launchedConfig;
    await _pumpSetup(
      tester,
      companies: const <InterviewCompanyOption>[
        InterviewCompanyOption(
          id: 'injourney',
          name: 'PT Aviasi Pariwisata Indonesia (Persero)',
        ),
      ],
      onLaunch: (InterviewLaunchConfig config) => launchedConfig = config,
    );

    await tester.ensureVisible(find.byKey(const Key('start-interview-button')));
    await tester.tap(find.byKey(const Key('start-interview-button')));
    await tester.pump();
    expect(find.text('Masukkan posisi yang dilamar.'), findsOneWidget);
    expect(launchedConfig, isNull);

    await tester.enterText(
      find.byKey(const Key('interview-role-field')),
      'Management Trainee',
    );
    await tester.tap(find.byKey(const Key('start-interview-button')));
    await tester.pumpAndSettle();
    expect(launchedConfig?.companyId, 'injourney');
    expect(launchedConfig?.targetRole, 'Management Trainee');
  });

  testWidgets('disables launch while the company catalog is loading', (
    WidgetTester tester,
  ) async {
    final Completer<List<InterviewCompanyOption>> completer =
        Completer<List<InterviewCompanyOption>>();
    await _pumpSetup(
      tester,
      loadCompanies: () => completer.future,
      settle: false,
      onLaunch: (_) {},
    );
    await tester.pump();

    expect(find.byKey(const Key('interview-company-loading')), findsOneWidget);
    final InkWell startButton = tester.widget<InkWell>(
      find.byKey(const Key('start-interview-button')),
    );
    expect(startButton.onTap, isNull);

    completer.complete(kTestCompanies);
    await tester.pumpAndSettle();
  });

  testWidgets('shows an empty catalog state with retry', (
    WidgetTester tester,
  ) async {
    await _pumpSetup(
      tester,
      companies: const <InterviewCompanyOption>[],
      onLaunch: (_) {},
    );

    expect(find.byKey(const Key('interview-company-empty')), findsOneWidget);
    expect(find.byKey(const Key('interview-company-retry')), findsOneWidget);
  });

  testWidgets('retries after the company catalog fails', (
    WidgetTester tester,
  ) async {
    int attempts = 0;
    await _pumpSetup(
      tester,
      loadCompanies: () async {
        attempts += 1;
        if (attempts == 1) {
          throw Exception('offline');
        }
        return kTestCompanies;
      },
      onLaunch: (_) {},
    );

    expect(find.byKey(const Key('interview-company-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('interview-company-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('interview-company-field')), findsOneWidget);
  });
}

const List<InterviewCompanyOption> kTestCompanies = <InterviewCompanyOption>[
  InterviewCompanyOption(
    id: 'adhi-karya',
    name: 'PT Adhi Karya (Persero) Tbk',
    defaultRole: 'Management Trainee',
  ),
  InterviewCompanyOption(
    id: 'bank-indonesia',
    name: 'Bank Indonesia',
    defaultRole: 'Asisten Manajer',
  ),
  InterviewCompanyOption(
    id: 'kementerian-keuangan',
    name: 'Kementerian Keuangan Republik Indonesia',
    defaultRole: 'Staf Pengelola Keuangan Negara',
  ),
  InterviewCompanyOption(
    id: 'injourney',
    name: 'PT Aviasi Pariwisata Indonesia (Persero)',
  ),
];

Future<void> _pumpSetup(
  WidgetTester tester, {
  List<InterviewSessionSummaryRecord> sessions =
      const <InterviewSessionSummaryRecord>[],
  List<InterviewCompanyOption> companies = kTestCompanies,
  Future<List<InterviewCompanyOption>> Function()? loadCompanies,
  ProfileTarget target = ProfileTarget.bumn,
  bool settle = true,
  required ValueChanged<InterviewLaunchConfig> onLaunch,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.interview,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.interview,
        builder: (_, _) => const InterviewSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.interviewSession,
        builder: (_, GoRouterState state) {
          onLaunch(state.extra! as InterviewLaunchConfig);
          return const Scaffold(body: Text('Interview launched'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        profileSettingsStorageProvider.overrideWithValue(
          _ProfileStorage(target),
        ),
        interviewCompaniesProvider.overrideWith(
          (_) => loadCompanies?.call() ?? Future.value(companies),
        ),
        interviewSessionsProvider.overrideWith((_) async => sessions),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

class _ProfileStorage implements ProfileSettingsStorage {
  const _ProfileStorage(this.target);

  final ProfileTarget target;

  @override
  Future<ProfileSettings> load() async {
    return ProfileSettings(
      displayName: 'Yudha',
      target: target,
      soundEnabled: true,
      hapticsEnabled: true,
    );
  }

  @override
  Future<void> save(ProfileSettings settings) async {}
}
