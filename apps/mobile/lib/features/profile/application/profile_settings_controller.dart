import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_storage.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_target.dart';

class ProfileSettingsController extends StateNotifier<ProfileSettings> {
  ProfileSettingsController({ProfileSettingsStorage? storage})
    : _storage = storage,
      super(ProfileSettings.initial()) {
    unawaited(_loadSavedSettings());
  }

  final ProfileSettingsStorage? _storage;
  bool _hasLocalMutation = false;

  void setDisplayName(String name) {
    _setState(state.copyWith(displayName: name.trim()));
  }

  void syncDisplayName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == state.displayName) {
      return;
    }
    _setState(state.copyWith(displayName: trimmed));
  }

  void syncProfile({
    required String displayName,
    required ProfileTarget target,
  }) {
    _setState(state.copyWith(displayName: displayName.trim(), target: target));
  }

  void setTarget(ProfileTarget target) {
    _setState(state.copyWith(target: target));
  }

  void completeProfile({
    required String displayName,
    required ProfileTarget target,
  }) {
    _setState(state.copyWith(displayName: displayName.trim(), target: target));
  }

  void toggleSound(bool value) {
    _setState(state.copyWith(soundEnabled: value));
  }

  void toggleHaptics(bool value) {
    _setState(state.copyWith(hapticsEnabled: value));
  }

  Future<void> _loadSavedSettings() async {
    final ProfileSettings? savedSettings = await _storage?.load();
    if (savedSettings == null || _hasLocalMutation) {
      return;
    }
    state = savedSettings;
  }

  void _setState(ProfileSettings nextState) {
    _hasLocalMutation = true;
    state = nextState;
    final ProfileSettingsStorage? storage = _storage;
    if (storage != null) {
      unawaited(storage.save(nextState));
    }
  }
}
