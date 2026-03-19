import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yudha_mobile/features/profile/application/profile_settings_controller.dart';
import 'package:yudha_mobile/features/profile/domain/entities/profile_settings.dart';

final StateNotifierProvider<ProfileSettingsController, ProfileSettings>
profileSettingsProvider =
    StateNotifierProvider<ProfileSettingsController, ProfileSettings>(
      (Ref ref) => ProfileSettingsController(),
    );

