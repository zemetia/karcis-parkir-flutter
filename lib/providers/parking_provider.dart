import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/parking_ticket.dart';
import '../models/parking_rate_rule.dart';
import '../models/parking_history_record.dart';
import '../models/parking_location.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/photo_service.dart';
import '../services/settings_service.dart';
import '../services/parking_location_service.dart';

class ParkingProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final NotificationService _notifications = NotificationService();
  final SettingsService _settings;
  final ParkingLocationService locationService;

  List<ParkingTicket> _tickets = [];
  List<ParkingTicket> _historyTickets = [];
  List<ParkingHistoryRecord> _history = [];
  bool _isLoading = true;
  Timer? _ticker;
  bool _isDisposed = false;
  int _operationToken = 0;

  ParkingProvider(
    this._settings, {
    ParkingLocationService? locationService,
    bool autoStartTicker = true,
  }) : locationService = locationService ?? ParkingLocationService(_settings.prefs) {
    if (autoStartTicker) {
      _startTicker();
    }
    loadTickets();
  }

  List<ParkingTicket> get tickets => List.unmodifiable(_tickets);
  List<ParkingTicket> get historyTickets => List.unmodifiable(_historyTickets);
  List<ParkingHistoryRecord> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  SettingsService get settings => _settings;

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      // Re-trigger UI rebuild for elapsed durations
      if (_tickets.isNotEmpty && !_isDisposed) {
        notifyListeners();
      }
    });
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> loadTickets() async {
    final id = ++_operationToken;
    _isLoading = true;
    notifyListeners();

    try {
      final activeTickets = await _db.getActiveTickets();
      List<ParkingTicket> completedTickets = [];
      try {
        completedTickets = await _db.getCompletedTickets();
      } catch (_) {
        completedTickets = [];
      }
      List<ParkingHistoryRecord> historyRecords = [];
      try {
        historyRecords = await _db.getAllHistoryRecords();
      } catch (_) {
        historyRecords = [];
      }

      // If a mutation or newer loadTickets occurred, discard stale result
      if (id != _operationToken || _isDisposed) {
        return;
      }

      _tickets = activeTickets;
      _historyTickets = completedTickets;
      _history = historyRecords;

      if (_settings.notificationsEnabled) {
        for (final ticket in _tickets) {
          await _notifications.showLiveTicketNotification(ticket);
          await _notifications.scheduleTicketReminders(ticket);
        }
      }
    } catch (e) {
      debugPrint('Error loading tickets: $e');
      if (id == _operationToken && !_isDisposed) {
        _tickets = [];
        _historyTickets = [];
        _history = [];
      }
    } finally {
      if (id == _operationToken && !_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
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
    String? parkingFloor,
    String? parkingBlock,
    String? parkingPhotoPath,
    String? ticketPhotoPath,
    double? latitude,
    double? longitude,
  }) async {
    _operationToken++;
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
      parkingFloor: parkingFloor?.trim().isNotEmpty == true ? parkingFloor!.trim() : null,
      parkingBlock: parkingBlock?.trim().isNotEmpty == true ? parkingBlock!.trim() : null,
      parkingPhotoPath: parkingPhotoPath,
      ticketPhotoPath: ticketPhotoPath,
      latitude: latitude,
      longitude: longitude,
    );

    await _db.insertTicket(newTicket);

    if (_settings.notificationsEnabled) {
      await _notifications.requestPermissions();
      await _notifications.showLiveTicketNotification(newTicket);
      await _notifications.scheduleTicketReminders(newTicket);
    }

    _tickets.insert(0, newTicket);
    notifyListeners();
    return newTicket;
  }

  /// Rate calculation helpers
  ParkingRateRule getRateRuleForTicket(ParkingTicket ticket) {
    if (ticket.locationName != null && ticket.locationName!.trim().isNotEmpty) {
      final locRule = locationService.getRateRule(ticket.locationName, ticket.vehicleType);
      if (locRule != null) {
        return locRule;
      }
    }
    return _settings.getRateRule(ticket.vehicleType);
  }

  int estimateCostForTicket(ParkingTicket ticket, [DateTime? atTime]) {
    final now = atTime ?? DateTime.now();
    final dur = now.difference(ticket.entryTime);
    return getRateRuleForTicket(ticket).calculateCost(dur);
  }

  int calculateCost(String vehicleType, Duration duration, {String? locationName}) {
    if (locationName != null && locationName.trim().isNotEmpty) {
      final locRule = locationService.getRateRule(locationName, vehicleType);
      if (locRule != null) {
        return locRule.calculateCost(duration);
      }
    }
    return _settings.getRateRule(vehicleType).calculateCost(duration);
  }

  Future<void> updateRateRule(String vehicleType, ParkingRateRule rule) async {
    await _settings.setRateRule(vehicleType, rule);
    notifyListeners();
  }

  Future<void> saveParkingLocation(ParkingLocation location) async {
    await locationService.saveLocation(location);
    notifyListeners();
  }

  Future<void> deleteParkingLocation(String id) async {
    await locationService.deleteLocation(id);
    notifyListeners();
  }

  Future<void> resetParkingLocationsToDefault() async {
    await locationService.resetToDefaults();
    notifyListeners();
  }

  /// Archives completed ticket into history table and marks ticket as isCompleted = true
  Future<void> completeTicket(
    String ticketId, {
    int? customCost,
    DateTime? exitTime,
  }) async {
    _operationToken++;
    final effectiveExit = exitTime ?? DateTime.now();
    ParkingTicket? ticket;
    final memIndex = _tickets.indexWhere((t) => t.id == ticketId);
    if (memIndex != -1) {
      ticket = _tickets[memIndex];
      _tickets.removeAt(memIndex);
      final completedTicket = ticket.copyWith(isCompleted: true);
      _historyTickets.removeWhere((t) => t.id == ticketId);
      _historyTickets.insert(0, completedTicket);
    }

    // 1. Cancel any pending reminder notifications
    await _notifications.cancelTicketReminders(ticketId);

    // 2. Find ticket from DB if not in memory
    if (ticket == null) {
      ticket = await _db.getTicketById(ticketId);
      if (ticket != null) {
        final completedTicket = ticket.copyWith(isCompleted: true);
        _tickets.removeWhere((t) => t.id == ticketId);
        _historyTickets.removeWhere((t) => t.id == ticketId);
        _historyTickets.insert(0, completedTicket);
      }
    }

    if (ticket != null) {
      final dur = effectiveExit.difference(ticket.entryTime);
      final durMinutes = dur.isNegative ? 0 : dur.inMinutes;
      final durHours = durMinutes ~/ 60;
      final remMins = durMinutes % 60;
      final durFormatted = durHours > 0 ? '$durHours jam $remMins mnt' : '$remMins mnt';

      final rule = getRateRuleForTicket(ticket);
      final finalCost = customCost ?? rule.calculateCost(dur);

      final record = ParkingHistoryRecord(
        id: const Uuid().v4(),
        ticketId: ticket.id,
        rawCode: ticket.rawCode,
        format: ticket.format,
        plateNumber: ticket.plateNumber,
        vehicleType: ticket.vehicleType,
        locationName: ticket.locationName,
        entryTime: ticket.entryTime,
        exitTime: effectiveExit,
        durationMinutes: durMinutes,
        durationFormatted: durFormatted,
        cost: finalCost,
        notes: ticket.notes,
      );

      try {
        await _db.insertHistoryRecord(record);
        _history.insert(0, record);
      } catch (e) {
        debugPrint('Error inserting history record: $e');
      }

      final completedTicket = ticket.copyWith(isCompleted: true);
      _tickets.removeWhere((t) => t.id == ticketId);
      _historyTickets.removeWhere((t) => t.id == ticketId);
      _historyTickets.insert(0, completedTicket);

      try {
        await _db.updateTicket(completedTicket);
      } catch (e) {
        debugPrint('Error updating ticket in DB: $e');
      }
    } else {
      _tickets.removeWhere((t) => t.id == ticketId);
    }

    notifyListeners();
  }

  /// Restore an archived/completed ticket back to active tickets
  Future<void> restoreTicket(String ticketId) async {
    _operationToken++;
    ParkingTicket? ticket;
    final memIndex = _historyTickets.indexWhere((t) => t.id == ticketId);
    if (memIndex != -1) {
      ticket = _historyTickets[memIndex];
      _historyTickets.removeAt(memIndex);
    } else {
      ticket = await _db.getTicketById(ticketId);
    }
    _historyTickets.removeWhere((t) => t.id == ticketId);

    if (ticket != null) {
      final restoredTicket = ticket.copyWith(isCompleted: false);
      _tickets.removeWhere((t) => t.id == ticketId);
      _tickets.insert(0, restoredTicket);
      _historyTickets.removeWhere((t) => t.id == ticketId);

      try {
        await _db.updateTicket(restoredTicket);
      } catch (e) {
        debugPrint('Error updating ticket in DB: $e');
      }

      if (_settings.notificationsEnabled) {
        await _notifications.showLiveTicketNotification(restoredTicket);
        await _notifications.scheduleTicketReminders(restoredTicket);
      }
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  /// Permanently delete a ticket from SQLite database and history
  Future<void> deleteTicketPermanently(String ticketId) async {
    _operationToken++;
    await _notifications.cancelTicketReminders(ticketId);

    final ticket = _historyTickets.firstWhere(
      (t) => t.id == ticketId,
      orElse: () => _tickets.firstWhere(
        (t) => t.id == ticketId,
        orElse: () => ParkingTicket(id: ticketId, rawCode: '', entryTime: DateTime.now()),
      ),
    );

    if (ticket.parkingPhotoPath != null) {
      // ignore: unawaited_futures
      PhotoService.deletePhotoFile(ticket.parkingPhotoPath);
    }
    if (ticket.ticketPhotoPath != null) {
      // ignore: unawaited_futures
      PhotoService.deletePhotoFile(ticket.ticketPhotoPath);
    }

    _tickets.removeWhere((t) => t.id == ticketId);
    _historyTickets.removeWhere((t) => t.id == ticketId);
    notifyListeners();

    try {
      await _db.deleteTicket(ticketId);
    } catch (e) {
      debugPrint('Error deleting ticket from DB: $e');
    }
  }

  /// Monthly expense recap helpers
  List<ParkingHistoryRecord> getMonthlyHistory(int year, int month) {
    return _history.where((r) => r.exitTime.year == year && r.exitTime.month == month).toList();
  }

  int getMonthlyTotalExpense(int year, int month) {
    final list = getMonthlyHistory(year, month);
    return list.fold<int>(0, (sum, r) => sum + r.cost);
  }

  Duration getMonthlyTotalDuration(int year, int month) {
    final list = getMonthlyHistory(year, month);
    final totalMinutes = list.fold<int>(0, (sum, r) => sum + r.durationMinutes);
    return Duration(minutes: totalMinutes);
  }

  Future<void> deleteHistoryRecord(String id) async {
    await _db.deleteHistoryRecord(id);
    _history.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _operationToken++;
    for (final ticket in _historyTickets) {
      await _db.deleteTicket(ticket.id);
      if (ticket.parkingPhotoPath != null) {
        // ignore: unawaited_futures
        PhotoService.deletePhotoFile(ticket.parkingPhotoPath);
      }
      if (ticket.ticketPhotoPath != null) {
        // ignore: unawaited_futures
        PhotoService.deletePhotoFile(ticket.ticketPhotoPath);
      }
    }
    _historyTickets.clear();

    for (final r in _history) {
      await _db.deleteHistoryRecord(r.id);
    }
    _history.clear();
    notifyListeners();
  }

  /// Update vehicle parking location details (floor, block/pillar, photo, GPS coordinates, location name)
  Future<void> updateParkingLocation(
    String ticketId, {
    String? locationName,
    bool clearLocationName = false,
    String? parkingFloor,
    bool clearParkingFloor = false,
    String? parkingBlock,
    bool clearParkingBlock = false,
    String? parkingPhotoPath,
    bool clearParkingPhoto = false,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
  }) async {
    _operationToken++;
    final activeIndex = _tickets.indexWhere((t) => t.id == ticketId);
    final historyIndex = _historyTickets.indexWhere((t) => t.id == ticketId);
    if (activeIndex == -1 && historyIndex == -1) return;

    final oldTicket = activeIndex != -1 ? _tickets[activeIndex] : _historyTickets[historyIndex];

    // Clean up replaced or removed photo files
    if (clearParkingPhoto && oldTicket.parkingPhotoPath != null) {
      // ignore: unawaited_futures
      PhotoService.deletePhotoFile(oldTicket.parkingPhotoPath);
    } else if (parkingPhotoPath != null &&
        oldTicket.parkingPhotoPath != null &&
        oldTicket.parkingPhotoPath != parkingPhotoPath) {
      // ignore: unawaited_futures
      PhotoService.deletePhotoFile(oldTicket.parkingPhotoPath);
    }

    final updatedTicket = oldTicket.copyWith(
      locationName: locationName,
      clearLocationName: clearLocationName,
      parkingFloor: parkingFloor,
      clearParkingFloor: clearParkingFloor,
      parkingBlock: parkingBlock,
      clearParkingBlock: clearParkingBlock,
      parkingPhotoPath: parkingPhotoPath,
      clearParkingPhoto: clearParkingPhoto,
      latitude: latitude,
      longitude: longitude,
      clearCoordinates: clearCoordinates,
    );

    await _db.updateTicket(updatedTicket);
    if (activeIndex != -1) {
      _tickets[activeIndex] = updatedTicket;
      if (_settings.notificationsEnabled) {
        await _notifications.showLiveTicketNotification(updatedTicket);
      }
    }
    if (historyIndex != -1) {
      _historyTickets[historyIndex] = updatedTicket;
    }
    notifyListeners();
  }

  /// Update physical ticket photo attachment (struk bukti fisik karcis kertas)
  Future<void> updateTicketPhoto(
    String ticketId, {
    String? ticketPhotoPath,
    bool clearTicketPhoto = false,
  }) async {
    _operationToken++;
    final activeIndex = _tickets.indexWhere((t) => t.id == ticketId);
    final historyIndex = _historyTickets.indexWhere((t) => t.id == ticketId);
    if (activeIndex == -1 && historyIndex == -1) return;

    final oldTicket = activeIndex != -1 ? _tickets[activeIndex] : _historyTickets[historyIndex];

    // Clean up replaced or removed photo files
    if (clearTicketPhoto && oldTicket.ticketPhotoPath != null) {
      // ignore: unawaited_futures
      PhotoService.deletePhotoFile(oldTicket.ticketPhotoPath);
    } else if (ticketPhotoPath != null &&
        oldTicket.ticketPhotoPath != null &&
        oldTicket.ticketPhotoPath != ticketPhotoPath) {
      // ignore: unawaited_futures
      PhotoService.deletePhotoFile(oldTicket.ticketPhotoPath);
    }

    final updatedTicket = oldTicket.copyWith(
      ticketPhotoPath: ticketPhotoPath,
      clearTicketPhoto: clearTicketPhoto,
    );

    await _db.updateTicket(updatedTicket);
    if (activeIndex != -1) {
      _tickets[activeIndex] = updatedTicket;
      if (_settings.notificationsEnabled) {
        await _notifications.showLiveTicketNotification(updatedTicket);
      }
    }
    if (historyIndex != -1) {
      _historyTickets[historyIndex] = updatedTicket;
    }
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
        await _notifications.showLiveTicketNotification(updated);
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
      await _notifications.showLiveTicketNotification(updatedTicket);
      await _notifications.scheduleTicketReminders(updatedTicket);
    }

    _tickets[index] = updatedTicket;
    notifyListeners();
  }

  /// Update the entry time of an existing ticket (e.g. adjust retroactively after scan)
  Future<void> updateTicketEntryTime(String ticketId, DateTime newEntryTime) async {
    _operationToken++;
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index == -1) return;

    final oldTicket = _tickets[index];
    final updatedTicket = oldTicket.copyWith(entryTime: newEntryTime);

    // Cancel old scheduled notifications and re-schedule based on the new entry time
    await _notifications.cancelTicketReminders(oldTicket.id);
    await _db.updateTicket(updatedTicket);

    if (_settings.notificationsEnabled) {
      await _notifications.showLiveTicketNotification(updatedTicket);
      await _notifications.scheduleTicketReminders(updatedTicket);
    }

    _tickets[index] = updatedTicket;
    notifyListeners();
  }
}
