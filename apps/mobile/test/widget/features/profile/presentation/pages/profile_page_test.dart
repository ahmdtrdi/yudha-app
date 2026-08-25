import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_controller.dart';
import 'package:yudha_mobile/features/profile/application/performance_analytics_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_controller.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_providers.dart';
import 'package:yudha_mobile/features/profile/data/repositories/performance_analytics_repository.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';
import 'package:yudha_mobile/features/profile/domain/entities/performance_analytics.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';
import 'package:yudha_mobile/features/profile/domain/entities/user_profile.dart';
import 'package:yudha_mobile/features/profile/presentation/pages/profile_page.dart';

void main() {
  testWidgets('renders profile sections', (WidgetTester tester) async {
    await _pumpProfilePage(tester);

    await tester.pumpAndSettle();

    expect(find.text('Profil Personal'), findsOneWidget);
    expect(find.text('Raka Saputra'), findsOneWidget);
    expect(find.text('Performa PvP'), findsOneWidget);
    expect(find.text('Analisis Latihan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pengaturan Profil'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pengaturan Profil'), findsOneWidget);
  });

  testWidgets('renders backend performance analytics with readable labels', (
    WidgetTester tester,
  ) async {
    await _pumpProfilePage(tester);

    await tester.pumpAndSettle();

    expect(find.text('Akurasi latihan'), findsOneWidget);
    expect(find.text('73%'), findsOneWidget);
    expect(find.text('2,5 dtk'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('4 pertandingan'), findsOneWidget);
    expect(find.text('Akurasi per kategori'), findsOneWidget);
    expect(find.text('TIU'), findsOneWidget);
    expect(find.text('Fokus latihan berikutnya'), findsOneWidget);
    expect(find.text('Pelayanan Publik'), findsOneWidget);
  });

  testWidgets('edits and explicitly saves backend profile fields', (
    WidgetTester tester,
  ) async {
    final _FakeUserProfileRepository repository = _FakeUserProfileRepository();
    await _pumpProfilePage(
      tester,
      repository: repository,
      surfaceSize: const Size(411, 700),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('edit-profile-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('profile-edit-sheet')), findsOneWidget);
    expect(find.text('Atur profilmu'), findsOneWidget);
    expect(find.text('IDENTITAS'), findsOneWidget);
    expect(find.text('TARGET BELAJAR'), findsOneWidget);
    expect(find.byKey(const Key('profile-target-cpns')), findsOneWidget);
    expect(find.byKey(const Key('profile-target-bumn')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('profile-full-name-field')),
      'Raka Baru',
    );
    await tester.tap(find.byKey(const Key('profile-target-bumn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-profile-button')));
    await tester.pumpAndSettle();

    expect(repository.lastUpdate?.fullName, 'Raka Baru');
    expect(repository.lastUpdate?.target, ProfileTarget.bumn);
    expect(find.text('Raka Baru'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirms before discarding edited profile fields', (
    WidgetTester tester,
  ) async {
    final _FakeUserProfileRepository repository = _FakeUserProfileRepository();
    await _pumpProfilePage(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-profile-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-full-name-field')),
      'Perubahan sementara',
    );

    await tester.tap(find.byKey(const Key('close-profile-editor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discard-profile-dialog')), findsOneWidget);
    expect(find.text('Buang perubahan?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-profile-editing')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-edit-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-profile-editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discard-profile-changes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-edit-sheet')), findsNothing);
    expect(repository.lastUpdate, isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpProfilePage(
  WidgetTester tester, {
  _FakeUserProfileRepository? repository,
  Size surfaceSize = const Size(430, 1200),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surfaceSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final _FakeUserProfileRepository profileRepository =
      repository ?? _FakeUserProfileRepository();
  final UserProfileController profileController = UserProfileController(
    repository: profileRepository,
  );
  await profileController.load();
  final PerformanceAnalyticsController performanceController =
      PerformanceAnalyticsController(
        repository: const _FakePerformanceAnalyticsRepository(),
      );
  await performanceController.load();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        profileSettingsStorageProvider.overrideWithValue(
          _ProfileSettingsMemoryStorage(),
        ),
        userProfileProvider.overrideWith((ref) => profileController),
        performanceAnalyticsProvider.overrideWith(
          (ref) => performanceController,
        ),
      ],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );
}

class _FakePerformanceAnalyticsRepository
    implements PerformanceAnalyticsRepository {
  const _FakePerformanceAnalyticsRepository();

  @override
  Future<PerformanceAnalytics> fetchPerformance() async {
    return const PerformanceAnalytics(
      practice: PracticePerformance(
        overallAccuracy: 72.5,
        totalAnswered: 40,
        averageResponseTimeMs: 2450,
        categoryBreakdown: <CategoryPerformance>[
          CategoryPerformance(category: 'TIU', accuracy: 80, totalAnswered: 20),
        ],
        weakSubcategories: <SubcategoryPerformance>[
          SubcategoryPerformance(
            subcategory: 'pelayanan_publik',
            accuracy: 45,
            totalAnswered: 10,
          ),
        ],
      ),
      battle: BattlePerformance(
        winRate: 0.6,
        wins: 6,
        losses: 4,
        totalMatches: 10,
      ),
    );
  }
}

class _ProfileSettingsMemoryStorage implements ProfileSettingsStorage {
  ProfileSettings? settings;

  @override
  Future<ProfileSettings?> load() async => settings;

  @override
  Future<void> save(ProfileSettings settings) async {
    this.settings = settings;
  }
}

class _FakeUserProfileRepository implements UserProfileRepository {
  UserProfileUpdate? lastUpdate;

  @override
  Future<UserProfile> fetchProfile() async {
    return const UserProfile(
      id: 'user-1',
      username: 'raka',
      fullName: 'Raka Saputra',
      target: ProfileTarget.cpns,
      rankPoints: 1178,
      tier: 'elite',
      rankedStats: ProfileRankedStats(
        wins: 3,
        losses: 1,
        draws: 0,
        winRate: 0.75,
      ),
      yCoins: 783,
      characterId: 'character-legend-drakor',
      towerId: 'tower-garda-biru',
      streak: ProfileStreak(current: 2, best: 2),
    );
  }

  @override
  Future<UserProfile> updateProfile(UserProfileUpdate update) async {
    lastUpdate = update;
    return UserProfile(
      id: 'user-1',
      username: update.username,
      fullName: update.fullName,
      target: update.target,
      rankPoints: 1178,
      tier: 'elite',
      rankedStats: const ProfileRankedStats(
        wins: 3,
        losses: 1,
        draws: 0,
        winRate: 0.75,
      ),
      yCoins: 783,
      characterId: 'character-legend-drakor',
      towerId: 'tower-garda-biru',
      streak: const ProfileStreak(current: 2, best: 2),
    );
  }
}
