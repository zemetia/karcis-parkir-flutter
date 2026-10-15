import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService Tests', () {
    test('Default reminder values are 11 hours and 24 hours', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await SettingsService.init();

      expect(service.firstReminderHours, 11.0);
      expect(service.secondReminderHours, 24.0);
      expect(service.notificationsEnabled, isTrue);
      expect(service.vibrationEnabled, isTrue);
    });

    test('Can update and persist custom reminder thresholds', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await SettingsService.init();

      await service.setFirstReminderHours(10.0);
      await service.setSecondReminderHours(20.0);
      await service.setNotificationsEnabled(false);
      await service.setVibrationEnabled(false);

      expect(service.firstReminderHours, 10.0);
      expect(service.secondReminderHours, 20.0);
      expect(service.notificationsEnabled, isFalse);
      expect(service.vibrationEnabled, isFalse);
    });

    test('Can add, remove, and persist dynamic list of reminder hours', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await SettingsService.init();

      // Initial defaults
      expect(service.reminderHours, [11.0, 24.0]);

      // Add 2 hours reminder
      await service.addReminderHour(2.0);
      expect(service.reminderHours, [2.0, 11.0, 24.0]);

      // Add 6 hours reminder
      await service.addReminderHour(6.0);
      expect(service.reminderHours, [2.0, 6.0, 11.0, 24.0]);

      // Remove 11 hours reminder
      await service.removeReminderHour(11.0);
      expect(service.reminderHours, [2.0, 6.0, 24.0]);

      // Persist test
      final reloaded = await SettingsService.init();
      expect(reloaded.reminderHours, [2.0, 6.0, 24.0]);
    });
  });
}
