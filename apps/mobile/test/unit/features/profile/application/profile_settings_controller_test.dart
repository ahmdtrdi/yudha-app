import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_controller.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

void main() {
  test('toggle device feedback flags update settings state', () {
    final ProfileSettingsController controller = ProfileSettingsController();

    controller.toggleSound(false);
    controller.toggleHaptics(false);

    expect(controller.state.soundEnabled, isFalse);
    expect(controller.state.hapticsEnabled, isFalse);
  });

  test('completeProfile saves name and target', () {
    final ProfileSettingsController controller = ProfileSettingsController();

    controller.completeProfile(displayName: 'Raka', target: ProfileTarget.cpns);

    expect(controller.state.displayName, 'Raka');
    expect(controller.state.target, ProfileTarget.cpns);
    expect(controller.state.isProfileComplete, isTrue);
  });

  test('syncProfile aligns local projection with backend identity', () {
    final ProfileSettingsController controller = ProfileSettingsController();

    controller.syncProfile(
      displayName: 'Raka Saputra',
      target: ProfileTarget.bumn,
    );

    expect(controller.state.displayName, 'Raka Saputra');
    expect(controller.state.target, ProfileTarget.bumn);
  });

  test('loads saved settings from storage', () async {
    final ProfileSettings savedSettings = ProfileSettings.initial().copyWith(
      displayName: 'Raka',
      target: ProfileTarget.bumn,
      soundEnabled: false,
    );
    final _ProfileSettingsMemoryStorage storage = _ProfileSettingsMemoryStorage(
      savedSettings,
    );

    final ProfileSettingsController controller = ProfileSettingsController(
      storage: storage,
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.displayName, 'Raka');
    expect(controller.state.target, ProfileTarget.bumn);
    expect(controller.state.soundEnabled, isFalse);
  });

  test('persists changed settings to storage', () async {
    final _ProfileSettingsMemoryStorage storage =
        _ProfileSettingsMemoryStorage();
    final ProfileSettingsController controller = ProfileSettingsController(
      storage: storage,
    );

    controller.setTarget(ProfileTarget.cpns);
    controller.toggleSound(false);
    await Future<void>.delayed(Duration.zero);

    expect(storage.settings?.target, ProfileTarget.cpns);
    expect(storage.settings?.soundEnabled, isFalse);
  });
}

class _ProfileSettingsMemoryStorage implements ProfileSettingsStorage {
  _ProfileSettingsMemoryStorage([this.settings]);

  ProfileSettings? settings;

  @override
  Future<ProfileSettings?> load() async => settings;

  @override
  Future<void> save(ProfileSettings settings) async {
    this.settings = settings;
  }
}
