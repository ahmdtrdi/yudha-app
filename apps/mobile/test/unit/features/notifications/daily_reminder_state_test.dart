import 'package:flutter_test/flutter_test.dart';
import 'package:yudha_mobile/features/notifications/domain/daily_reminder_state.dart';

void main() {
  test('default reminder preferences are disabled with planned times', () {
    final preferences = DailyReminderPreferences.defaults();

    expect(preferences.enabled, isFalse);
    expect(preferences.morningEnabled, isTrue);
    expect(preferences.morningTime, '09:00');
    expect(preferences.rescueEnabled, isTrue);
    expect(preferences.rescueTime, '19:30');
  });

  test('server preference payload maps editable controls', () {
    final preferences =
        DailyReminderPreferences.fromJson(const <String, dynamic>{
          'enabled': true,
          'morningEnabled': false,
          'morningTime': '08:15',
          'rescueEnabled': true,
          'rescueTime': '20:45',
        });

    expect(preferences.enabled, isTrue);
    expect(preferences.morningEnabled, isFalse);
    expect(preferences.morningTime, '08:15');
    expect(preferences.rescueTime, '20:45');
  });
}
