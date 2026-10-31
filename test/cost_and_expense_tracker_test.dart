import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:karcis_parkir/models/parking_history_record.dart';
import 'package:karcis_parkir/models/parking_rate_rule.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:karcis_parkir/screens/expense_dashboard_screen.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/export_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:karcis_parkir/widgets/ticket_card.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.customDbPath = inMemoryDatabasePath;
  });

  setUp(() {
    ExportService().customDocsPath = Directory.systemTemp.path;
  });

  tearDown(() async {
    await DatabaseService.instance.clearAll();
    ExportService.mockShareHandler = null;
    ExportService().customDocsPath = null;
  });

  group('Kalkulator Estimasi Biaya Parkir: ParkingRateRule Unit Tests', () {
    const standardRule = ParkingRateRule(
      firstHourRate: 4000,
      hourlyRate: 3000,
      dailyMaxRate: 40000,
      gracePeriodMinutes: 0,
    );

    test('Zero or negative duration costs 0', () {
      expect(standardRule.calculateCost(Duration.zero), 0);
      expect(standardRule.calculateCost(const Duration(minutes: -10)), 0);
    });

    test('Exact User Example: 2 hours 15 minutes returns Rp 10.000', () {
      // 1st hour (4.000) + 2 extra hours (ceil of 1h 15m = 2 * 3.000) = 10.000
      final duration = const Duration(hours: 2, minutes: 15);
      final cost = standardRule.calculateCost(duration);
      expect(cost, 10000);
    });

    test('1 hour or less returns first hour rate (Rp 4.000)', () {
      expect(standardRule.calculateCost(const Duration(minutes: 10)), 4000);
      expect(standardRule.calculateCost(const Duration(minutes: 60)), 4000);
    });

    test('1 hour 1 minute rounds up to 2 hours total (Rp 7.000)', () {
      expect(standardRule.calculateCost(const Duration(minutes: 61)), 7000);
    });

    test('Daily max rate capping (e.g. 18 hours capped at Rp 40.000)', () {
      // 4.000 + 17 * 3.000 = 55.000 -> capped at 40.000
      final cost = standardRule.calculateCost(const Duration(hours: 18));
      expect(cost, 40000);
    });

    test('Multi-day parking calculation (e.g. 26 hours)', () {
      // 1 full day (40.000) + 2 hours (4.000 + 3.000 = 7.000) = 47.000
      final cost = standardRule.calculateCost(const Duration(hours: 26));
      expect(cost, 47000);
    });

    test('Grace period (15 minutes free window)', () {
      const graceRule = ParkingRateRule(
        firstHourRate: 4000,
        hourlyRate: 3000,
        dailyMaxRate: 40000,
        gracePeriodMinutes: 15,
      );

      // Within grace period -> 0
      expect(graceRule.calculateCost(const Duration(minutes: 10)), 0);
      expect(graceRule.calculateCost(const Duration(minutes: 15)), 0);

      // Exceeds grace period -> charged standard first hour
      expect(graceRule.calculateCost(const Duration(minutes: 16)), 4000);
    });

    test('Serialization to/from Map and JSON', () {
      final map = standardRule.toMap();
      final fromMap = ParkingRateRule.fromMap(map);
      expect(fromMap.firstHourRate, 4000);
      expect(fromMap.hourlyRate, 3000);
      expect(fromMap.dailyMaxRate, 40000);
      expect(fromMap.gracePeriodMinutes, 0);

      final jsonStr = standardRule.toJson();
      final fromJson = ParkingRateRule.fromJson(jsonStr);
      expect(fromJson.firstHourRate, 4000);
      expect(fromJson.hourlyRate, 3000);
      expect(fromJson.dailyMaxRate, 40000);
    });

    test('defaultFor returns expected rates per vehicle type', () {
      final motor = ParkingRateRule.defaultFor('Motor');
      expect(motor.firstHourRate, 2000);
      expect(motor.hourlyRate, 1000);
      expect(motor.dailyMaxRate, 20000);

      final mobil = ParkingRateRule.defaultFor('Mobil');
      expect(mobil.firstHourRate, 4000);
      expect(mobil.hourlyRate, 3000);
      expect(mobil.dailyMaxRate, 40000);

      final truk = ParkingRateRule.defaultFor('Truk');
      expect(truk.firstHourRate, 6000);
      expect(truk.hourlyRate, 5000);
      expect(truk.dailyMaxRate, 60000);
    });
  });

  group('Provider & Database Cost & Expense Flow Tests', () {
    test('estimateCostForTicket and completeTicket creates history record with accurate expense', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final now = DateTime.now();
      final entryTime = now.subtract(const Duration(hours: 2, minutes: 15));

      final ticket = await provider.addTicket(
        rawCode: 'EXPENSE-TICKET-01',
        plateNumber: 'B 2026 PRK',
        vehicleType: 'Mobil',
        locationName: 'Plaza Indonesia',
        entryTime: entryTime,
      );

      // Test real-time estimate at current time
      final estimatedCost = provider.estimateCostForTicket(ticket, now);
      expect(estimatedCost, 10000);

      // Complete ticket at `now`
      await provider.completeTicket(ticket.id, exitTime: now);

      // Verify ticket is moved to history
      expect(provider.tickets, isEmpty);
      expect(provider.historyTickets.length, 1);
      expect(provider.history.length, 1);

      final record = provider.history.first;
      expect(record.ticketId, ticket.id);
      expect(record.plateNumber, 'B 2026 PRK');
      expect(record.cost, 10000);
      expect(record.durationMinutes, 135);
      expect(record.durationFormatted, '2 jam 15 mnt');

      // Test monthly aggregation helpers
      final monthlyHistory = provider.getMonthlyHistory(now.year, now.month);
      expect(monthlyHistory.length, 1);

      final totalExpense = provider.getMonthlyTotalExpense(now.year, now.month);
      expect(totalExpense, 10000);

      final totalDuration = provider.getMonthlyTotalDuration(now.year, now.month);
      expect(totalDuration.inMinutes, 135);

      provider.dispose();
    });

    test('updateRateRule updates custom rates and triggers calculation with new rule', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final customRule = const ParkingRateRule(
        firstHourRate: 5000,
        hourlyRate: 4000,
        dailyMaxRate: 50000,
        gracePeriodMinutes: 10,
      );

      await provider.updateRateRule('Mobil', customRule);

      final ruleFromSettings = provider.settings.getRateRule('Mobil');
      expect(ruleFromSettings.firstHourRate, 5000);
      expect(ruleFromSettings.hourlyRate, 4000);
      expect(ruleFromSettings.dailyMaxRate, 50000);
      expect(ruleFromSettings.gracePeriodMinutes, 10);

      // Calculate 2 hours 15 mins with new rule: 5.000 + 2 * 4.000 = 13.000
      final calculated = provider.calculateCost('Mobil', const Duration(hours: 2, minutes: 15));
      expect(calculated, 13000);

      provider.dispose();
    });
  });

  group('ExportService Unit Tests: PDF and CSV Generation', () {
    final sampleRecord = ParkingHistoryRecord(
      id: 'rec-001',
      ticketId: 'tkt-001',
      rawCode: 'CODE-9988',
      format: 'QR_CODE',
      plateNumber: 'B 1234 ABC',
      vehicleType: 'Mobil',
      locationName: 'Grand Indonesia Mall',
      entryTime: DateTime(2026, 10, 15, 9, 0),
      exitTime: DateTime(2026, 10, 15, 11, 15),
      durationMinutes: 135,
      durationFormatted: '2 jam 15 mnt',
      cost: 10000,
      notes: 'Meeting vendor operasional',
    );

    test('generateCsv generates RFC-compliant CSV with header and escaped fields', () {
      final exportService = ExportService();
      final csv = exportService.generateCsv([sampleRecord], periodName: 'Oktober 2026');

      expect(csv, contains('No,ID Karcis,Plat Nomor,Jenis Kendaraan,Lokasi,Waktu Masuk,Waktu Keluar,Durasi Menit,Durasi Format,Biaya (Rp),Catatan'));
      expect(csv, contains('B 1234 ABC'));
      expect(csv, contains('Mobil'));
      expect(csv, contains('Grand Indonesia Mall'));
      expect(csv, contains('2 jam 15 mnt'));
      expect(csv, contains('10000'));
      expect(csv, contains('Meeting vendor operasional'));
    });

    test('generateMonthlyPdf generates valid non-empty PDF bytes', () async {
      final exportService = ExportService();
      final bytes = await exportService.generateMonthlyPdf(
        [sampleRecord],
        year: 2026,
        month: 10,
        driverName: 'Pak Budi',
        companyName: 'PT Operasional Sukses',
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // PDF documents start with %PDF
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });

    test('generateSingleTicketPdf generates valid individual receipt PDF voucher', () async {
      final exportService = ExportService();
      final bytes = await exportService.generateSingleTicketPdf(sampleRecord);

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });

    test('shareFile triggers mockShareHandler with expected file and text', () async {
      final exportService = ExportService();
      List<XFile>? receivedFiles;
      String? receivedText;

      ExportService.mockShareHandler = (files, {text}) async {
        receivedFiles = files;
        receivedText = text;
      };

      await exportService.shareFile('/tmp/klaim_parkir.pdf', text: 'Klaim Parkir Kantor');

      expect(receivedFiles, isNotNull);
      expect(receivedFiles!.length, 1);
      expect(receivedFiles!.first.path, '/tmp/klaim_parkir.pdf');
      expect(receivedText, 'Klaim Parkir Kantor');
    });
  });

  group('Widget Tests: Estimasi Real-Time & Rekap Pengeluaran', () {
    testWidgets('TicketCard displays exact real-time duration and estimate format: Durasi: 2 jam 15 mnt • Estimasi: Rp 10.000',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final now = DateTime.now();
      final ticket = ParkingTicket(
        id: 'widget-card-ticket',
        rawCode: 'SAMPLE-QR',
        plateNumber: 'B 7777 WIN',
        vehicleType: 'Mobil',
        locationName: 'PIM 2 South',
        entryTime: now.subtract(const Duration(hours: 2, minutes: 15)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ParkingProvider>.value(
            value: provider,
            child: Scaffold(
              body: TicketCard(
                ticket: ticket,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the required exact text format on the ticket card:
      // "Durasi: 2 jam 15 mnt • Estimasi: Rp 10.000"
      expect(
        find.textContaining('Durasi: 2 jam 15 mnt • Estimasi: Rp 10.000'),
        findsOneWidget,
      );

      provider.dispose();
    });

    testWidgets('ExpenseDashboardScreen displays month selector, total expense & duration KPI cards, and export actions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final now = DateTime.now();
      await tester.runAsync(() async {
        await provider.loadTickets();
        // Add and complete a ticket in current month
        final ticket = await provider.addTicket(
          rawCode: 'DASHBOARD-TEST-TKT',
          plateNumber: 'B 8888 BOS',
          vehicleType: 'Mobil',
          locationName: 'Menara Mandiri',
          entryTime: now.subtract(const Duration(hours: 2, minutes: 15)),
        );
        await provider.completeTicket(ticket.id, exitTime: now);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ParkingProvider>.value(
            value: provider,
            child: const ExpenseDashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      // 1. Verify Month Selector & Header
      expect(find.text('Rekap Pengeluaran Parkir'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // 2. Verify KPI Cards
      expect(find.text('Total Pengeluaran'), findsOneWidget);
      expect(find.text('Rp 10.000'), findsWidgets);
      expect(find.text('Total Durasi'), findsOneWidget);
      expect(find.text('2 jam 15 mnt'), findsWidgets);

      // 3. Verify Export Buttons
      expect(find.text('Ekspor PDF'), findsOneWidget);
      expect(find.text('Ekspor CSV'), findsOneWidget);

      // 4. Verify completed record row
      expect(find.text('B 8888 BOS'), findsOneWidget);
      expect(find.text('Mobil • Menara Mandiri'), findsOneWidget);

      // 5. Test opening Aturan Tarif dialog and verifying live calculation simulation
      final rateButton = find.byTooltip('Aturan Tarif Parkir');
      expect(rateButton, findsOneWidget);
      await tester.tap(rateButton);
      await tester.pumpAndSettle();

      expect(find.text('Aturan Tarif Parkir'), findsOneWidget);
      expect(find.textContaining('Simulasi: Durasi: 2 jam 15 mnt • Estimasi: Rp 10.000'), findsOneWidget);

      // Change rate to first hour 5000 and verify live recalculation: 5.000 + 2*3.000 = 11.000
      final firstHourField = find.widgetWithText(TextField, 'Tarif 1 Jam Pertama (Rp)');
      expect(firstHourField, findsOneWidget);
      await tester.enterText(firstHourField, '5000');
      await tester.pump();

      expect(find.textContaining('Simulasi: Durasi: 2 jam 15 mnt • Estimasi: Rp 11.000'), findsOneWidget);

      // Tap Simpan Aturan Tarif
      await tester.tap(find.text('Simpan Aturan Tarif'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      provider.dispose();
    });

    testWidgets('ExpenseDashboardScreen Ekspor CSV triggers success dialog with copy & share actions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final now = DateTime.now();
      await tester.runAsync(() async {
        await provider.loadTickets();
        final ticket = await provider.addTicket(
          rawCode: 'CSV-EXPORT-TKT',
          plateNumber: 'B 5555 CSV',
          vehicleType: 'Mobil',
          locationName: 'Sudirman Central',
          entryTime: now.subtract(const Duration(hours: 1)),
        );
        await provider.completeTicket(ticket.id, exitTime: now);
      });

      List<XFile>? sharedFiles;
      ExportService.mockShareHandler = (files, {text}) async {
        sharedFiles = files;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ParkingProvider>.value(
            value: provider,
            child: const ExpenseDashboardScreen(),
          ),
        ),
      );

      await tester.pump();

      // Tap Ekspor CSV button
      final csvButton = find.widgetWithText(ElevatedButton, 'Ekspor CSV');
      expect(csvButton, findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(csvButton);
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Verify Export Success Dialog appears
      expect(find.text('Ekspor CSV Berhasil'), findsOneWidget);
      expect(find.text('Salin Data CSV ke Clipboard'), findsOneWidget);
      expect(find.text('Bagikan File'), findsOneWidget);

      // Tap Bagikan File
      await tester.tap(find.text('Bagikan File'));
      await tester.pump();

      expect(sharedFiles, isNotNull);
      expect(sharedFiles!.first.path, contains('.csv'));

      // Close dialog
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      provider.dispose();
    });
  });
}
