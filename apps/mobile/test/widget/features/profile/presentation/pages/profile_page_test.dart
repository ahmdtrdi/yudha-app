import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/learning/application/learning_providers.dart';
import 'package:yudha_mobile/features/learning/data/repositories/learning_repository.dart';
import 'package:yudha_mobile/features/learning/domain/entities/learning_dashboard.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_controller.dart';
import 'package:yudha_mobile/features/profile/application/user_profile_providers.dart';
import 'package:yudha_mobile/features/profile/data/repositories/user_profile_repository.dart';
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
    expect(find.text('Learning'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile-learning-link')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Pengaturan Profil'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pengaturan Profil'), findsOneWidget);
  });

  testWidgets('replaces legacy weak-topic analytics with a Learning summary', (
    WidgetTester tester,
  ) async {
    await _pumpProfilePage(tester);

    await tester.pumpAndSettle();

    expect(find.text('Perkuat TIU Numerik'), findsOneWidget);
    expect(find.textContaining('68% akurasi mandiri'), findsOneWidget);
    expect(find.text('Fokus latihan berikutnya'), findsNothing);
    expect(find.text('Pelayanan Publik'), findsNothing);
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

  testWidgets('shows a red danger zone and confirms both delete actions', (
    WidgetTester tester,
  ) async {
    await _pumpProfilePage(tester, surfaceSize: const Size(430, 700));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('danger-zone')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Zona Bahaya'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-account-data-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-account-data-dialog')), findsOneWidget);
    expect(find.text('Hapus semua data akun?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-destructive-action')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('delete-account-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-account-dialog')), findsOneWidget);
    expect(find.text('Hapus akun permanen?'), findsOneWidget);
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        profileSettingsStorageProvider.overrideWithValue(
          _ProfileSettingsMemoryStorage(),
        ),
        userProfileProvider.overrideWith((ref) => profileController),
        learningRepositoryProvider.overrideWithValue(
          const _FakeLearningRepository(),
        ),
      ],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );
}

class _FakeLearningRepository implements LearningRepository {
  const _FakeLearningRepository();

  @override
  Future<LearningDashboard> fetchDashboard() async {
    return LearningDashboard.fromJson(<String, dynamic>{
      'asOf': '2026-09-01T02:00:00.000Z',
      'calculationVersion': 'learning-v1',
      'target': 'cpns',
      'nextAction': <String, dynamic>{
        'recommendationId': 'recommendation-1',
        'target': 'cpns',
        'objective': 'repair_accuracy',
        'skill': <String, dynamic>{
          'id': 'cpns.tiu.numerik',
          'label': 'TIU Numerik',
          'category': 'tiu',
          'subcategory': 'numerik',
        },
        'mechanicMode': 'focus',
        'reason': <String, dynamic>{
          'headline': 'Perkuat TIU Numerik',
          'description': 'Akurasi masih perlu ditingkatkan.',
        },
        'confidence': 'medium',
        'availability': <String, dynamic>{
          'runnable': true,
          'compatibilityAdapter': 'practice_fixed_five',
          'label': 'Practice 5 soal (kompatibilitas)',
        },
      },
      'summary': <String, dynamic>{
        'curriculumCoverage': <String, dynamic>{
          'value': 50,
          'coveredSkillCount': 2,
          'requiredSkillCount': 4,
          'confidence': 'medium',
        },
        'unseenIndependentAccuracy': <String, dynamic>{
          'value': 68,
          'correctCount': 17,
          'attemptCount': 25,
          'uniqueQuestionCount': 20,
          'confidence': 'medium',
          'asOf': '2026-09-01T02:00:00.000Z',
        },
        'pace': <String, dynamic>{
          'value': null,
          'baselineType': null,
          'attemptCount': 0,
          'confidence': 'low',
        },
      },
      'skillStates': <dynamic>[],
      'trends': <dynamic>[],
      'retention': <dynamic>[],
      'assessment': <String, dynamic>{'status': 'not_available'},
      'activity': <String, dynamic>{},
      'competition': <String, dynamic>{'accuracy': <String, dynamic>{}},
    });
  }

  @override
  Future<void> recordRecommendationEvent({
    required String recommendationId,
    required String eventType,
    String? dismissalReason,
  }) async {}
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
  Future<void> deleteAccount() async {}

  @override
  Future<UserProfile> deleteAccountData() => fetchProfile();

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
