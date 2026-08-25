enum ReminderPermissionStatus { unavailable, notDetermined, denied, authorized }

class DailyReminderPreferences {
  const DailyReminderPreferences({
    required this.enabled,
    required this.morningEnabled,
    required this.morningTime,
    required this.rescueEnabled,
    required this.rescueTime,
  });

  factory DailyReminderPreferences.defaults() {
    return const DailyReminderPreferences(
      enabled: false,
      morningEnabled: true,
      morningTime: '09:00',
      rescueEnabled: true,
      rescueTime: '19:30',
    );
  }

  factory DailyReminderPreferences.fromJson(Map<String, dynamic> json) {
    return DailyReminderPreferences(
      enabled: json['enabled'] == true,
      morningEnabled: json['morningEnabled'] != false,
      morningTime: json['morningTime']?.toString() ?? '09:00',
      rescueEnabled: json['rescueEnabled'] != false,
      rescueTime: json['rescueTime']?.toString() ?? '19:30',
    );
  }

  final bool enabled;
  final bool morningEnabled;
  final String morningTime;
  final bool rescueEnabled;
  final String rescueTime;

  DailyReminderPreferences copyWith({
    bool? enabled,
    bool? morningEnabled,
    String? morningTime,
    bool? rescueEnabled,
    String? rescueTime,
  }) {
    return DailyReminderPreferences(
      enabled: enabled ?? this.enabled,
      morningEnabled: morningEnabled ?? this.morningEnabled,
      morningTime: morningTime ?? this.morningTime,
      rescueEnabled: rescueEnabled ?? this.rescueEnabled,
      rescueTime: rescueTime ?? this.rescueTime,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'morningEnabled': morningEnabled,
    'morningTime': morningTime,
    'rescueEnabled': rescueEnabled,
    'rescueTime': rescueTime,
  };
}

class ReminderNotificationTap {
  const ReminderNotificationTap({required this.route, this.deliveryId});

  final String route;
  final String? deliveryId;
}

class DailyReminderState {
  const DailyReminderState({
    required this.preferences,
    required this.permissionStatus,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.pendingTap,
  });

  factory DailyReminderState.initial() => DailyReminderState(
    preferences: DailyReminderPreferences.defaults(),
    permissionStatus: ReminderPermissionStatus.unavailable,
    isLoading: true,
  );

  final DailyReminderPreferences preferences;
  final ReminderPermissionStatus permissionStatus;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final ReminderNotificationTap? pendingTap;

  DailyReminderState copyWith({
    DailyReminderPreferences? preferences,
    ReminderPermissionStatus? permissionStatus,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    ReminderNotificationTap? pendingTap,
    bool clearPendingTap = false,
  }) {
    return DailyReminderState(
      preferences: preferences ?? this.preferences,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      pendingTap: clearPendingTap ? null : pendingTap ?? this.pendingTap,
    );
  }
}
