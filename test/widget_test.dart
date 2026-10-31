import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:karcis_parkir/screens/home_screen.dart';
import 'package:karcis_parkir/screens/scan_screen.dart';
import 'package:karcis_parkir/screens/settings_screen.dart';
import 'package:karcis_parkir/screens/ticket_detail_screen.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:karcis_parkir/widgets/qr_display.dart';
import 'package:karcis_parkir/widgets/ticket_card.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

    // Confirm done inside runAsync for DB update
    await tester.tap(find.text('Ya, Selesai (Done)'));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 600));
    });
    await tester.pumpAndSettle();

    // Ticket must now be removed from active provider tickets and marked as completed
    expect(provider.tickets, isEmpty);
    expect(provider.historyTickets.length, 1);
    ParkingTicket? inDb;
    await tester.runAsync(() async {
      inDb = await DatabaseService.instance.getTicketById(ticket.id);
    });
    expect(inDb, isNotNull);
    expect(inDb!.isCompleted, isTrue);

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

  test('Barcode and QR helper methods identify formats correctly', () {
    expect(ScanScreen.isBarcodeFormat('code128'), isTrue);
    expect(ScanScreen.isBarcodeFormat('CODE_128'), isTrue);
    expect(ScanScreen.isBarcodeFormat('code39'), isTrue);
    expect(ScanScreen.isBarcodeFormat('ean13'), isTrue);
    expect(ScanScreen.isBarcodeFormat('ean8'), isTrue);
    expect(ScanScreen.isBarcodeFormat('upca'), isTrue);
    expect(ScanScreen.isBarcodeFormat('upce'), isTrue);
    expect(ScanScreen.isBarcodeFormat('codabar'), isTrue);
    expect(ScanScreen.isBarcodeFormat('itf'), isTrue);
    expect(ScanScreen.isBarcodeFormat('itf14'), isTrue);
    expect(ScanScreen.isBarcodeFormat('itf2of5'), isTrue);
    expect(ScanScreen.isBarcodeFormat('pdf417'), isTrue);
    expect(ScanScreen.isBarcodeFormat('databar'), isTrue);
    expect(ScanScreen.isBarcodeFormat('databarExpanded'), isTrue);
    expect(ScanScreen.isBarcodeFormat('databarLimited'), isTrue);

    // 2D matrix formats and specials must not be classified as 1D barcode
    expect(ScanScreen.isBarcodeFormat('qrCode'), isFalse);
    expect(ScanScreen.isBarcodeFormat('microQrCode'), isFalse);
    expect(ScanScreen.isBarcodeFormat('dataMatrix'), isFalse);
    expect(ScanScreen.isBarcodeFormat('aztec'), isFalse);
    expect(ScanScreen.isBarcodeFormat('maxiCode'), isFalse);
    expect(ScanScreen.isBarcodeFormat('manual'), isFalse);
    expect(ScanScreen.isBarcodeFormat('unknown'), isFalse);

    expect(ScanScreen.formatDisplayName('code128'), 'Barcode (Code 128)');
    expect(ScanScreen.formatDisplayName('code39'), 'Barcode (Code 39)');
    expect(ScanScreen.formatDisplayName('ean13'), 'Barcode (EAN-13)');
    expect(ScanScreen.formatDisplayName('qrCode'), 'QR Code');
    expect(ScanScreen.formatDisplayName('microQrCode'), 'QR Code (Micro QR)');
    expect(ScanScreen.formatDisplayName('dataMatrix'), 'Data Matrix');
    expect(ScanScreen.formatDisplayName('aztec'), 'Aztec Code');
    expect(ScanScreen.formatDisplayName('maxiCode'), 'MaxiCode');
    expect(ScanScreen.formatDisplayName('databar'), 'Barcode (GS1 DataBar)');
    expect(ScanScreen.formatDisplayName('manual'), 'Input Manual');
  });

  testWidgets('TicketDetailScreen displays barcode format information when ticket format is barcode', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.init();
    final provider = ParkingProvider(settings, autoStartTicker: false);

    late ParkingTicket ticket;
    await tester.runAsync(() async {
      ticket = await provider.addTicket(
        rawCode: 'BARCODE-998877',
        format: 'code128',
        plateNumber: 'B 8888 XYZ',
        vehicleType: 'Mobil',
        locationName: 'Secure Parking Mall',
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

    expect(find.text('Format Karcis'), findsOneWidget);
    expect(find.text('Barcode (Code 128)'), findsOneWidget);
    expect(find.text('Format Asli: Barcode (Code 128)'), findsOneWidget);

    provider.dispose();
  });

  testWidgets('ScanScreen renders mode switcher, toggles barcode mode, and opens barcode manual input', (WidgetTester tester) async {
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
          home: ScanScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verify AppBar & Mode Switcher elements
    expect(find.text('Pindai Karcis Baru'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Barcode'), findsOneWidget);
    expect(find.text('QR Code'), findsOneWidget);
    expect(find.text('Arahkan kamera ke barcode atau QR code karcis'), findsOneWidget);

    // Tap Barcode mode
    await tester.tap(find.text('Barcode'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Posisikan garis barcode secara horizontal di dalam kotak'), findsOneWidget);

    // Tap QR Code mode
    await tester.tap(find.text('QR Code'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Posisikan QR code di dalam kotak pemindai'), findsOneWidget);

    // Test Zoom toggle
    expect(find.text('1x'), findsOneWidget);
    await tester.tap(find.text('1x'));
    await tester.pump();
    expect(find.text('2x'), findsOneWidget);

    // Tap Input Kode Manual
    await tester.tap(find.text('Input Kode Manual'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify manual input dialog supports barcodes
    expect(find.text('Input Kode Karcis Manual'), findsOneWidget);
    expect(find.text('Nomor / Barcode Karcis'), findsOneWidget);
    expect(find.text('Mendukung nomor karcis, QR code, atau barcode.'), findsOneWidget);

    provider.dispose();
  });

  testWidgets('ScanScreen onDetect filters formats according to selected mode and saves barcode ticket', (WidgetTester tester) async {
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
          home: ScanScreen(),
        ),
      ),
    );
    await tester.pump();

    // Switch to Barcode mode
    await tester.tap(find.text('Barcode'));
    await tester.pump(const Duration(milliseconds: 200));

    final scannerFinder = find.byType(MobileScanner);
    expect(scannerFinder, findsOneWidget);
    final mobileScanner = tester.widget<MobileScanner>(scannerFinder);

    // Simulate detection of a QR Code while in Barcode mode -> Must be ignored!
    mobileScanner.onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.qrCode,
            rawValue: 'https://ignored-qr.com',
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Karcis Berhasil Dipindai'), findsNothing);

    // Now simulate detection of a 1D Code128 Barcode while in Barcode mode -> Must open confirmation sheet!
    mobileScanner.onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.code128,
            rawValue: 'PRK-BARCODE-889900',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Verify confirmation bottom sheet is displayed with barcode format badge
    expect(find.text('Karcis Berhasil Dipindai'), findsOneWidget);
    expect(find.text('PRK-BARCODE-889900'), findsOneWidget);
    expect(find.text('Barcode (Code 128)'), findsOneWidget);
    expect(find.text('Simpan Karcis'), findsOneWidget);

    // Tap "Simpan Karcis"
    await tester.tap(find.text('Simpan Karcis'));
    await tester.runAsync(() async {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Verify ticket saved in provider with barcode format
    expect(provider.tickets.length, 1);
    expect(provider.tickets.first.rawCode, 'PRK-BARCODE-889900');
    expect(provider.tickets.first.format, 'code128');

    provider.dispose();
  });

  testWidgets('ScanScreen onDetect is blocked when manual input dialog is open', (WidgetTester tester) async {
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
          home: ScanScreen(),
        ),
      ),
    );
    await tester.pump();

    // Open manual input dialog
    await tester.tap(find.text('Input Kode Manual'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Input Kode Karcis Manual'), findsOneWidget);

    final scannerFinder = find.byType(MobileScanner);
    final mobileScanner = tester.widget<MobileScanner>(scannerFinder);

    // Fire detection while dialog is open -> Should be blocked!
    mobileScanner.onDetect!(
      const BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.code128,
            rawValue: 'BACKGROUND-DETECTION-BLOCKED',
          ),
        ],
      ),
    );
    await tester.pump();

    // Still on manual dialog, save ticket sheet did NOT pop
    expect(find.text('Input Kode Karcis Manual'), findsOneWidget);
    expect(find.text('Karcis Berhasil Dipindai'), findsNothing);

    provider.dispose();
  });
}
