import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_language.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';

class ProfileSettingsController extends StateNotifier<ProfileSettings> {
  ProfileSettingsController() : super(ProfileSettings.initial());

  void setLanguage(ProfileLanguage language) {
    state = state.copyWith(language: language);
  }

  void toggleNotifications(bool value) {
    state = state.copyWith(notificationsEnabled: value);
  }

  void toggleSound(bool value) {
    state = state.copyWith(soundEnabled: value);
  }

  void toggleHaptics(bool value) {
    state = state.copyWith(hapticsEnabled: value);
  }
}

