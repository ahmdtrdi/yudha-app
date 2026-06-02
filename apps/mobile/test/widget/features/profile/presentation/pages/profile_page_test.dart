import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_providers.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/presentation/pages/profile_page.dart';

void main() {
  testWidgets('renders profile sections', (WidgetTester tester) async {
    await _pumpProfilePage(tester);

    await tester.pumpAndSettle();

    expect(find.text('Profil Personal'), findsOneWidget);
    expect(find.text('Analisis Performa'), findsOneWidget);
    expect(find.text('Pengaturan Profil'), findsOneWidget);
    expect(find.text('Target aktif: -'), findsOneWidget);
  });

  testWidgets('can switch active target label', (WidgetTester tester) async {
    await _pumpProfilePage(tester);

    await tester.pumpAndSettle();

    await tester.tap(find.text('BUMN'));
    await tester.pumpAndSettle();

    expect(find.text('Target aktif: BUMN'), findsOneWidget);
  });
}

Future<void> _pumpProfilePage(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        profileSettingsStorageProvider.overrideWithValue(
          _ProfileSettingsMemoryStorage(),
        ),
      ],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );
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
