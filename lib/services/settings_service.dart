import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyFirstReminderHours = 'first_reminder_hours';
  static const String keySecondReminderHours = 'second_reminder_hours';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyVibrationEnabled = 'vibration_enabled';

  static const String keyReminderHoursList = 'reminder_hours_list';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  // List of dynamic reminder hours (default: [11.0, 24.0])
  List<double> get reminderHours {
    final stringList = _prefs.getStringList(keyReminderHoursList);
    if (stringList != null && stringList.isNotEmpty) {
      final parsed = stringList
          .map((s) => double.tryParse(s.trim()))
          .whereType<double>()
          .toSet()
          .toList();
      if (parsed.isNotEmpty) {
        parsed.sort();
        return parsed;
      }
    }
    final first = firstReminderHours;
    final second = secondReminderHours;
    final list = {first, second}.toList()..sort();
    return list;
  }

  Future<bool> setReminderHours(List<double> hours) async {
    final clean = hours.toSet().toList()..sort();
    final stringList = clean.map((h) => h.toString()).toList();
    final ok = await _prefs.setStringList(keyReminderHoursList, stringList);
    if (clean.isNotEmpty) {
      await setFirstReminderHours(clean.first);
      if (clean.length > 1) {
        await setSecondReminderHours(clean[1]);
      }
    }
    return ok;
  }

  Future<bool> addReminderHour(double hour) async {
    final current = List<double>.from(reminderHours);
    if (!current.contains(hour)) {
      current.add(hour);
      current.sort();
      return await setReminderHours(current);
    }
    return true;
  }

  Future<bool> removeReminderHour(double hour) async {
    final current = List<double>.from(reminderHours);
    current.remove(hour);
    if (current.isEmpty) {
      current.add(11.0); // Keep at least one default
    }
    return await setReminderHours(current);
  }

  // Default: 11 hours (1 jam sebelum 12 jam)
  double get firstReminderHours =>
      _prefs.getDouble(keyFirstReminderHours) ?? 11.0;

  Future<bool> setFirstReminderHours(double hours) =>
      _prefs.setDouble(keyFirstReminderHours, hours);

  // Default: 24 hours
  double get secondReminderHours =>
      _prefs.getDouble(keySecondReminderHours) ?? 24.0;

  Future<bool> setSecondReminderHours(double hours) =>
      _prefs.setDouble(keySecondReminderHours, hours);

  bool get notificationsEnabled =>
      _prefs.getBool(keyNotificationsEnabled) ?? true;

  Future<bool> setNotificationsEnabled(bool enabled) =>
      _prefs.setBool(keyNotificationsEnabled, enabled);

  bool get vibrationEnabled =>
      _prefs.getBool(keyVibrationEnabled) ?? true;

  Future<bool> setVibrationEnabled(bool enabled) =>
      _prefs.setBool(keyVibrationEnabled, enabled);
}
