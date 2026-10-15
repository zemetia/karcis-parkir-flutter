import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:karcis_parkir/screens/home_screen.dart';
import 'package:karcis_parkir/screens/settings_screen.dart';
import 'package:karcis_parkir/screens/ticket_detail_screen.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:karcis_parkir/widgets/qr_display.dart';
import 'package:karcis_parkir/widgets/ticket_card.dart';
import 'package:provider/provider.dart';
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

  testWidgets('HomeScreen renders empty state when no tickets', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.init();
    final provider = ParkingProvider(settings, autoStartTicker: false);
    await tester.runAsync(() async {
      await provider.loadTickets();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Belum Ada Karcis Parkir Aktif'), findsOneWidget);
    expect(find.text('Pindai Karcis Sekarang'), findsOneWidget);

    provider.dispose();
  });

  testWidgets('TicketDetailScreen displays QR and handles Done (deletion) flow', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.init();
    final provider = ParkingProvider(settings, autoStartTicker: false);

    late ParkingTicket ticket;
    await tester.runAsync(() async {
      ticket = await provider.addTicket(
        rawCode: 'PARKIR-12345678',
        plateNumber: 'B 7777 ABC',
        vehicleType: 'Mobil',
        locationName: 'Lotte Shopping Avenue',
      );
    });

    expect(provider.tickets.length, 1);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: TicketDetailScreen(ticket: ticket),
        ),
      ),
    );
    await tester.pump();

    // Verify UI components are displayed
    expect(find.text('Pindai Karcis Keluar'), findsOneWidget);
    expect(find.text('B 7777 ABC'), findsOneWidget);
    expect(find.text('Lotte Shopping Avenue'), findsOneWidget);
    expect(find.text('Done (Keluar)'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);

    // Ensure visible and Tap "Done (Keluar)"
    await tester.ensureVisible(find.text('Done (Keluar)'));
    await tester.tap(find.text('Done (Keluar)'));
    await tester.pump();

    // Verify confirmation dialog
    expect(find.text('Selesaikan Parkir?'), findsOneWidget);
    expect(find.text('Ya, Selesai (Done)'), findsOneWidget);

    // Confirm done inside runAsync for DB deletion
    await tester.tap(find.text('Ya, Selesai (Done)'));
    await tester.runAsync(() async {
      await tester.pump();
      // give microtasks time to complete provider.completeTicket & DB delete
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Ticket must now be removed from provider and local DB
    expect(provider.tickets, isEmpty);
    ParkingTicket? inDb;
    await tester.runAsync(() async {
      inDb = await DatabaseService.instance.getTicketById(ticket.id);
    });
    expect(inDb, isNull);

    provider.dispose();
  });

  testWidgets('QrDisplayCard opens fullscreen view on tap with scan guidance', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDisplayCard(
            data: 'FULLSCREEN-QR-DATA',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FULLSCREEN-QR-DATA'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);

    // Tap to expand fullscreen
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Tutup'), findsOneWidget);
    // Verifies tutorial clutter is completely removed
    expect(find.text('Pastikan kecerahan layar maksimal saat scan di gerbang keluar.'), findsNothing);

    // Close fullscreen dialog
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    expect(find.text('Tutup'), findsNothing);
  });

  testWidgets('TicketCard displays dynamic reminder threshold warning', (WidgetTester tester) async {
    // Ticket that entered 7 hours ago with custom first reminder at 6 hours
    final pastTime = DateTime.now().subtract(const Duration(hours: 7));
    final ticket = ParkingTicket(
      id: 'threshold-ticket',
      rawCode: 'THRESHOLD-QR-123',
      plateNumber: 'B 1234 WARN',
      entryTime: pastTime,
      firstReminderHours: 6.0,
      secondReminderHours: 24.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketCard(
            ticket: ticket,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('B 1234 WARN'), findsOneWidget);
    // Warning banner for passing custom first limit (6 jam)
    expect(find.text('Melebihi batas waktu (>6 jam)'), findsOneWidget);
  });

  testWidgets('SettingsScreen displays dynamic reminder hours list and supports adding new hour', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.init();
    final provider = ParkingProvider(settings, autoStartTicker: false);
    await tester.runAsync(() async {
      await provider.loadTickets();
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial reminder hours are rendered
    expect(find.text('Jam Pengingat Parkir'), findsOneWidget);
    expect(find.text('Tambah Jam'), findsOneWidget);
    expect(find.text('11 Jam'), findsOneWidget);
    expect(find.text('24 Jam'), findsOneWidget);

    // Tap "Tambah Jam" to open bottom sheet
    await tester.tap(find.text('Tambah Jam'));
    await tester.pumpAndSettle();

    // Verify modal options
    expect(find.text('Tambah Jam Pengingat'), findsOneWidget);
    expect(find.text('Simpan Pengingat'), findsOneWidget);

    // Tap preset '2 Jam' choice chip
    expect(find.text('2 Jam'), findsOneWidget);
    await tester.tap(find.text('2 Jam'));
    await tester.pumpAndSettle();

    // Tap "Simpan Pengingat"
    await tester.tap(find.text('Simpan Pengingat'));
    await tester.pumpAndSettle();

    // Verify new 2 hours reminder is now in the list
    expect(find.text('2 Jam'), findsOneWidget);

    provider.dispose();
  });

  testWidgets('EditEntryTimeSheet allows adjusting entry time backwards and saving', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.init();
    final provider = ParkingProvider(settings, autoStartTicker: false);

    final initialTime = DateTime(2026, 10, 15, 11, 3);
    late ParkingTicket ticket;
    await tester.runAsync(() async {
      ticket = await provider.addTicket(
        rawCode: 'TEST-EDIT-ENTRY-TIME',
        plateNumber: 'B 1103 MOD',
        entryTime: initialTime,
      );
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: TicketDetailScreen(ticket: ticket),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "Ubah" button exists
    expect(find.text('Ubah'), findsOneWidget);

    // Tap "Ubah" to open EditEntryTimeSheet
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();

    // Verify bottom sheet appeared
    expect(find.text('Ubah Jam Masuk'), findsOneWidget);
    expect(find.text('11:03'), findsOneWidget);
    expect(find.text('-5 mnt'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);

    // Tap "-5 mnt" quick adjust button
    await tester.tap(find.text('-5 mnt'));
    await tester.pumpAndSettle();

    // Verify time adjusted from 11:03 to 10:58
    expect(find.text('10:58'), findsOneWidget);

    // Tap "Simpan Perubahan"
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.runAsync(() async {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Verify updated entry time in provider
    expect(provider.tickets.first.entryTime.hour, 10);
    expect(provider.tickets.first.entryTime.minute, 58);

    provider.dispose();
  });
}
