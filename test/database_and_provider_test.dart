import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.customDbPath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await DatabaseService.instance.clearAll();
  });

  group('Database and Provider Flow Tests', () {
    test('addTicket inserts ticket into local db with configured defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      // Wait initial load
      await provider.loadTickets();
      expect(provider.tickets, isEmpty);

      final ticket = await provider.addTicket(
        rawCode: 'TEST-CODE-12345',
        format: 'QR_CODE',
        plateNumber: 'B 1988 KRC',
        vehicleType: 'Mobil',
        locationName: 'PIM 2 Basement',
      );

      expect(ticket.rawCode, 'TEST-CODE-12345');
      expect(ticket.plateNumber, 'B 1988 KRC');
      expect(ticket.firstReminderHours, 11.0);
      expect(ticket.secondReminderHours, 24.0);
      expect(provider.tickets.length, 1);

      // Verify persisted in DB
      final savedInDb = await DatabaseService.instance.getTicketById(ticket.id);
      expect(savedInDb, isNotNull);
      expect(savedInDb!.rawCode, 'TEST-CODE-12345');

      provider.dispose();
    });

    test('completeTicket deletes ticket permanently from local db', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final ticket = await provider.addTicket(
        rawCode: 'TEMP-EXIT-QR',
        plateNumber: 'B 9999 XYZ',
      );

      expect(provider.tickets.length, 1);

      // Flow requirement: "kalau done di klik maka hapus aja dari database local"
      await provider.completeTicket(ticket.id);

      // Verify removed from memory
      expect(provider.tickets, isEmpty);

      // Verify removed from SQLite database
      final deletedTicket = await DatabaseService.instance.getTicketById(ticket.id);
      expect(deletedTicket, isNull);

      provider.dispose();
    });

    test('updateSettings updates and synchronizes active tickets in memory and database', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final ticket = await provider.addTicket(
        rawCode: 'SETTINGS-TEST-CODE',
        plateNumber: 'D 1234 ABC',
      );

      expect(ticket.firstReminderHours, 11.0);
      expect(ticket.secondReminderHours, 24.0);

      // Now user changes settings: first reminder = 6h, second reminder = 18h
      await provider.updateSettings(
        firstHours: 6.0,
        secondHours: 18.0,
        notificationsEnabled: true,
        vibrationEnabled: true,
      );

      // Memory state must be updated
      expect(provider.tickets.first.firstReminderHours, 6.0);
      expect(provider.tickets.first.secondReminderHours, 18.0);

      // SQLite database state must also be updated
      final updatedFromDb = await DatabaseService.instance.getTicketById(ticket.id);
      expect(updatedFromDb!.firstReminderHours, 6.0);
      expect(updatedFromDb.secondReminderHours, 18.0);

      // Now add a 3rd reminder hour (e.g. 2 hours)
      await provider.addReminderHourToSettings(2.0);
      expect(provider.tickets.first.reminderHours, [2.0, 6.0, 18.0]);

      final updatedDbWith3Reminders = await DatabaseService.instance.getTicketById(ticket.id);
      expect(updatedDbWith3Reminders!.reminderHours, [2.0, 6.0, 18.0]);

      // Add single ticket reminder
      await provider.addReminderToTicket(ticket.id, 10.0);
      expect(provider.tickets.first.reminderHours, [2.0, 6.0, 10.0, 18.0]);

      provider.dispose();
    });

    test('updateTicketEntryTime updates entryTime in memory and SQLite db', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final initialScanTime = DateTime(2026, 10, 15, 11, 3);
      final ticket = await provider.addTicket(
        rawCode: 'EDIT-TIME-QR-999',
        plateNumber: 'B 1103 SC',
        entryTime: initialScanTime,
      );

      expect(provider.tickets.first.entryTime, initialScanTime);

      // User modifies entry time from 11:03 back to 10:58 (e.g. 5 minutes earlier)
      final actualEntryTime = DateTime(2026, 10, 15, 10, 58);
      await provider.updateTicketEntryTime(ticket.id, actualEntryTime);

      // Verify memory state updated
      expect(provider.tickets.first.entryTime, actualEntryTime);

      // Verify SQLite database updated
      final fromDb = await DatabaseService.instance.getTicketById(ticket.id);
      expect(fromDb, isNotNull);
      expect(fromDb!.entryTime, actualEntryTime);

      provider.dispose();
    });
  });
}
