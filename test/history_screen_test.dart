import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:karcis_parkir/screens/history_screen.dart';
import 'package:karcis_parkir/screens/home_screen.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
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

  group('HistoryScreen and Arsip Flow Tests', () {
    testWidgets('HistoryScreen renders empty state when no history tickets exist', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);
      await tester.runAsync(() async {
        await provider.loadTickets();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Riwayat Parkir'), findsOneWidget);
      expect(find.text('Belum Ada Riwayat Parkir'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // Total frekuensi 0

      provider.dispose();
    });

    testWidgets('HistoryScreen displays statistics, filter, restore and delete options', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      late ParkingTicket ticket1;
      late ParkingTicket ticket2;
      final now = DateTime.now();

      await tester.runAsync(() async {
        await provider.loadTickets();

        ticket1 = await provider.addTicket(
          rawCode: 'CODE128-HISTORY-1',
          format: 'CODE_128',
          plateNumber: 'B 1111 MOB',
          vehicleType: 'Mobil',
          locationName: 'Mall Grand Indonesia',
          entryTime: now,
        );

        ticket2 = await provider.addTicket(
          rawCode: 'QR-HISTORY-2',
          format: 'QR_CODE',
          plateNumber: 'B 2222 MOT',
          vehicleType: 'Motor',
          locationName: 'PIM 2',
          entryTime: now,
        );

        await provider.completeTicket(ticket1.id);
        await provider.completeTicket(ticket2.id);
      });

      expect(provider.tickets, isEmpty);
      expect(provider.historyTickets.length, 2);

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
            home: HistoryScreen(),
          ),
        ),
      );
      await tester.pump();

      // Check statistics
      expect(find.text('Statistik Frekuensi Parkir'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // Total 2 karcis
      expect(find.text('Mobil: '), findsOneWidget);
      expect(find.text('Motor: '), findsOneWidget);

      // Check ticket cards
      expect(find.text('B 1111 MOB'), findsOneWidget);
      expect(find.text('B 2222 MOT'), findsOneWidget);
      expect(find.text('Pulihkan'), findsNWidgets(2));
      expect(find.text('Hapus'), findsNWidgets(2));

      // Test "Pulihkan" (Restore) flow
      await tester.ensureVisible(find.text('Pulihkan').first);
      await tester.tap(find.text('Pulihkan').first);
      await tester.pumpAndSettle();

      expect(find.text('Pulihkan Karcis?'), findsOneWidget);
      await tester.tap(find.text('Ya, Pulihkan'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // ticket2 was restored to active tickets
      expect(provider.tickets.length, 1);
      expect(provider.historyTickets.length, 1);

      // Test "Hapus" (Permanent delete) flow
      await tester.ensureVisible(find.text('Hapus').first);
      await tester.tap(find.text('Hapus').first);
      await tester.pumpAndSettle();

      expect(find.text('Hapus Permanen?'), findsOneWidget);
      await tester.tap(find.text('Hapus Permanen'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // History is now empty
      expect(provider.historyTickets, isEmpty);
      expect(find.text('Belum Ada Riwayat Parkir'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('HomeScreen navigation bar toggles between Karcis Aktif and Riwayat tabs', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);
      await tester.runAsync(() async {
        await provider.loadTickets();
      });

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      // Default tab: Karcis Aktif
      expect(find.text('Belum Ada Karcis Parkir Aktif'), findsOneWidget);
      expect(find.text('Karcis Aktif'), findsWidgets);
      expect(find.text('Riwayat'), findsOneWidget);

      // Switch to Riwayat tab
      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();

      // Riwayat Parkir should be visible
      expect(find.text('Riwayat Parkir'), findsOneWidget);
      expect(find.text('Statistik Frekuensi Parkir'), findsOneWidget);

      // Switch back to Karcis Aktif tab
      await tester.tap(find.text('Karcis Aktif').first);
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Karcis Parkir Aktif'), findsOneWidget);

      provider.dispose();
    });
  });
}
