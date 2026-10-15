import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/parking_ticket.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';

class ParkingProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final NotificationService _notifications = NotificationService();
  final SettingsService _settings;

  List<ParkingTicket> _tickets = [];
  bool _isLoading = true;
  Timer? _ticker;

  ParkingProvider(this._settings, {bool autoStartTicker = true}) {
    if (autoStartTicker) {
      _startTicker();
    }
    loadTickets();
  }

  List<ParkingTicket> get tickets => List.unmodifiable(_tickets);
  bool get isLoading => _isLoading;
  SettingsService get settings => _settings;

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      // Re-trigger UI rebuild for elapsed durations
      if (_tickets.isNotEmpty) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> loadTickets() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tickets = await _db.getActiveTickets();
      if (_settings.notificationsEnabled) {
        for (final ticket in _tickets) {
          await _notifications.scheduleTicketReminders(ticket);
        }
      }
    } catch (e) {
      debugPrint('Error loading tickets: $e');
      _tickets = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ParkingTicket> addTicket({
    required String rawCode,
    String format = 'QR_CODE',
    String? plateNumber,
    String vehicleType = 'Mobil',
    String? locationName,
    DateTime? entryTime,
    String? notes,
    List<double>? customReminderHours,
  }) async {
    final effectiveEntryTime = entryTime ?? DateTime.now();
    final configuredHours = customReminderHours ?? _settings.reminderHours;

    final newTicket = ParkingTicket(
      id: const Uuid().v4(),
      rawCode: rawCode.trim(),
      format: format,
      plateNumber: plateNumber?.trim().toUpperCase(),
      vehicleType: vehicleType,
      locationName: locationName?.trim(),
      entryTime: effectiveEntryTime,
      notes: notes?.trim(),
      reminderHours: configuredHours,
    );

    await _db.insertTicket(newTicket);

    if (_settings.notificationsEnabled) {
      await _notifications.scheduleTicketReminders(newTicket);
    }

    _tickets.insert(0, newTicket);
    notifyListeners();
    return newTicket;
  }

  /// Flow requirement: "kalau done di klik maka hapus aja dari database local"
  Future<void> completeTicket(String ticketId) async {
    // 1. Cancel any pending reminder notifications
    await _notifications.cancelTicketReminders(ticketId);

    // 2. Remove permanently from local SQLite database
    await _db.deleteTicket(ticketId);

    // 3. Update memory state
    _tickets.removeWhere((t) => t.id == ticketId);
    notifyListeners();
  }

  Future<void> updateSettings({
    double? firstHours,
    double? secondHours,
    List<double>? reminderHours,
    required bool notificationsEnabled,
    required bool vibrationEnabled,
  }) async {
    List<double> finalHours;
    if (reminderHours != null && reminderHours.isNotEmpty) {
      finalHours = reminderHours.toSet().toList()..sort();
      await _settings.setReminderHours(finalHours);
    } else if (firstHours != null && secondHours != null) {
      finalHours = {firstHours, secondHours}.toList()..sort();
      await _settings.setReminderHours(finalHours);
    } else {
      finalHours = _settings.reminderHours;
    }

    await _settings.setNotificationsEnabled(notificationsEnabled);
    await _settings.setVibrationEnabled(vibrationEnabled);

    // Synchronize active tickets with new reminder configurations
    final updatedTickets = <ParkingTicket>[];
    for (final ticket in _tickets) {
      await _notifications.cancelTicketReminders(ticket.id);
      final updated = ticket.copyWith(
        reminderHours: finalHours,
        firstReminderHours: finalHours.isNotEmpty ? finalHours.first : 11.0,
        secondReminderHours: finalHours.length > 1 ? finalHours[1] : 24.0,
      );
      await _db.updateTicket(updated);
      if (notificationsEnabled) {
        await _notifications.scheduleTicketReminders(updated);
      }
      updatedTickets.add(updated);
    }
    _tickets = updatedTickets;
    notifyListeners();
  }

  Future<void> addReminderHourToSettings(double hour) async {
    await _settings.addReminderHour(hour);
    await updateSettings(
      reminderHours: _settings.reminderHours,
      notificationsEnabled: _settings.notificationsEnabled,
      vibrationEnabled: _settings.vibrationEnabled,
    );
  }

  Future<void> removeReminderHourFromSettings(double hour) async {
    await _settings.removeReminderHour(hour);
    await updateSettings(
      reminderHours: _settings.reminderHours,
      notificationsEnabled: _settings.notificationsEnabled,
      vibrationEnabled: _settings.vibrationEnabled,
    );
  }

  Future<void> addReminderToTicket(String ticketId, double hour) async {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index == -1) return;

    final ticket = _tickets[index];
    final updatedHours = List<double>.from(ticket.reminderHours);
    if (!updatedHours.contains(hour)) {
      updatedHours.add(hour);
      updatedHours.sort();
    }

    await _notifications.cancelTicketReminders(ticket.id);
    final updatedTicket = ticket.copyWith(reminderHours: updatedHours);
    await _db.updateTicket(updatedTicket);

    if (_settings.notificationsEnabled) {
      await _notifications.scheduleTicketReminders(updatedTicket);
    }

    _tickets[index] = updatedTicket;
    notifyListeners();
  }

  /// Update the entry time of an existing ticket (e.g. adjust retroactively after scan)
  Future<void> updateTicketEntryTime(String ticketId, DateTime newEntryTime) async {
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index == -1) return;

    final oldTicket = _tickets[index];
    final updatedTicket = oldTicket.copyWith(entryTime: newEntryTime);

    // Cancel old scheduled notifications and re-schedule based on the new entry time
    await _notifications.cancelTicketReminders(oldTicket.id);
    await _db.updateTicket(updatedTicket);

    if (_settings.notificationsEnabled) {
      await _notifications.scheduleTicketReminders(updatedTicket);
    }

    _tickets[index] = updatedTicket;
    notifyListeners();
  }
}
