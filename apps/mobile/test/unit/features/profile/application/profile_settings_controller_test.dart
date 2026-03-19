import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_controller.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_language.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

void main() {
  test('setLanguage updates selected language', () {
    final ProfileSettingsController controller = ProfileSettingsController();

    controller.setLanguage(ProfileLanguage.en);

    expect(controller.state.language, ProfileLanguage.en);
  });

  test('toggle flags update settings state', () {
    final ProfileSettingsController controller = ProfileSettingsController();

    controller.toggleNotifications(false);
    controller.toggleSound(false);
    controller.toggleHaptics(false);

    expect(controller.state.notificationsEnabled, isFalse);
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
}
