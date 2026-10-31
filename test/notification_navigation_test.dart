import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/screens/ticket_detail_screen.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/notification_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.customDbPath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await DatabaseService.instance.clearAll();
  });

  group('Live Chronometer Notification and Deep Navigation Tests', () {
    testWidgets('Tapping notification navigates directly to TicketDetailScreen with QR/barcode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final db = DatabaseService.instance;

      final ticket = ParkingTicket(
        id: 'ticket-notif-nav-1',
        rawCode: 'TEST-CODE-12345',
        format: 'QR_CODE',
        plateNumber: 'B 9999 XYZ',
        vehicleType: 'Mobil',
        locationName: 'Grand Indonesia Mall',
        entryTime: DateTime.now().subtract(const Duration(minutes: 45)),
        parkingFloor: 'B2',
        parkingBlock: 'D14',
      );

      late ParkingProvider provider;
      await tester.runAsync(() async {
        await db.insertTicket(ticket);
        provider = ParkingProvider(settings, autoStartTicker: false);
        await provider.loadTickets();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ParkingProvider>.value(value: provider),
          ],
          child: MaterialApp(
            navigatorKey: NotificationService.navigatorKey,
            home: const Scaffold(
              body: Center(child: Text('Home Screen Test')),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Home Screen Test'), findsOneWidget);
      expect(find.byType(TicketDetailScreen), findsNothing);

      // Simulate tapping notification with payload = ticket.id
      await tester.runAsync(() async {
        await NotificationService.navigateToTicket(ticket.id);
      });
      await tester.pumpAndSettle();

      // Should now be on TicketDetailScreen showing the plate and barcode
      expect(find.byType(TicketDetailScreen), findsOneWidget);
      expect(find.text('B 9999 XYZ'), findsAtLeastNWidgets(1));
      expect(find.text('TEST-CODE-12345'), findsOneWidget);
      expect(NotificationService.currentViewingTicketId, equals(ticket.id));

      // Attempting to navigate again while already viewing the same ticket does not create duplicate screens
      await tester.runAsync(() async {
        await NotificationService.navigateToTicket(ticket.id);
      });
      await tester.pumpAndSettle();
      expect(find.byType(TicketDetailScreen), findsOneWidget);

      // Pop the screen back
      Navigator.of(NotificationService.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();
      expect(find.byType(TicketDetailScreen), findsNothing);
      expect(NotificationService.currentViewingTicketId, isNull);

      provider.dispose();
    });

    test('Live notification ID generation and cancel range', () {
      final service = NotificationService();
      const ticketId = 'unique-ticket-id-abc';
      final liveId = service.generateLiveNotificationId(ticketId);

      // Verify that live notification ID is index 0
      expect(liveId % 100, equals(0));

      // Reminders 1..30 have distinct non-zero last two digits
      for (int i = 1; i <= 30; i++) {
        final reminderId = liveId + i;
        expect(reminderId % 100, equals(i));
        expect(reminderId, isNot(equals(liveId)));
      }
    });

    test('Cold start pending ticket id handling', () {
      final service = NotificationService();
      service.setPendingTicketId('cold-start-ticket-id');
      expect(service.pendingTicketId, equals('cold-start-ticket-id'));

      final consumed = service.consumePendingTicketId();
      expect(consumed, equals('cold-start-ticket-id'));
      expect(service.pendingTicketId, isNull);
    });
  });
}
