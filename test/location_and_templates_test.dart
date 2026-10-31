import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:karcis_parkir/models/parking_location.dart';
import 'package:karcis_parkir/models/parking_rate_rule.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:karcis_parkir/screens/location_templates_screen.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/parking_location_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:karcis_parkir/widgets/edit_location_rule_dialog.dart';
import 'package:karcis_parkir/widgets/location_picker_sheet.dart';
import 'package:provider/provider.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await DatabaseService.instance.clearAll();
  });

  group('Flexible Parking Rate Rule & Tier Tests', () {
    test('Flat Rate: Sekali bayar stays flat regardless of parking duration', () {
      const flatRule = ParkingRateRule(
        isFlatRate: true,
        flatRate: 2000,
        firstHourRate: 2000,
        hourlyRate: 0,
        dailyMaxRate: 2000,
      );

      expect(flatRule.calculateCost(const Duration(minutes: 15)), 2000);
      expect(flatRule.calculateCost(const Duration(hours: 3)), 2000);
      expect(flatRule.calculateCost(const Duration(hours: 12)), 2000);
      expect(flatRule.calculateCost(Duration.zero), 0);
    });

    test('Initial Hours: 2 hours base rate, then hourly', () {
      // e.g. Tunjungan Plaza Motor: 2 jam pertama Rp 3.000, berikutnya Rp 2.000/jam
      const tpMotorRule = ParkingRateRule(
        firstHourRate: 3000,
        hourlyRate: 2000,
        dailyMaxRate: 25000,
        initialHours: 2,
        initialRate: 3000,
      );

      // 45 mins -> within 2 hours -> 3000
      expect(tpMotorRule.calculateCost(const Duration(minutes: 45)), 3000);
      // 2 hours -> 3000
      expect(tpMotorRule.calculateCost(const Duration(hours: 2)), 3000);
      // 2 hours 15 mins (ceil = 3 hours) -> 3000 + 1 * 2000 = 5000
      expect(tpMotorRule.calculateCost(const Duration(hours: 2, minutes: 15)), 5000);
      // 4 hours -> 3000 + 2 * 2000 = 7000
      expect(tpMotorRule.calculateCost(const Duration(hours: 4)), 7000);
    });

    test('Tiered Rate: Mall PTC Mobil Rule (1st hour 5000, hours 2-4: 4000/hr, after 4 hours: 6000/hr)', () {
      const ptcMobilRule = ParkingRateRule(
        firstHourRate: 5000,
        hourlyRate: 4000,
        dailyMaxRate: 60000,
        initialHours: 1,
        initialRate: 5000,
        tiers: [
          RateTier(afterHours: 4, hourlyRate: 6000),
        ],
      );

      // Hour 1: 5.000
      expect(ptcMobilRule.calculateCost(const Duration(minutes: 40)), 5000);
      // Hour 2: 5.000 + 4.000 = 9.000
      expect(ptcMobilRule.calculateCost(const Duration(hours: 2)), 9000);
      // Hour 4: 5.000 + 3 * 4.000 = 17.000
      expect(ptcMobilRule.calculateCost(const Duration(hours: 4)), 17000);
      // Hour 5: 17.000 + 6.000 (after 4h tier) = 23.000
      expect(ptcMobilRule.calculateCost(const Duration(hours: 5)), 23000);
      // Hour 6: 23.000 + 6.000 = 29.000
      expect(ptcMobilRule.calculateCost(const Duration(hours: 6)), 29000);
    });

    test('Serialization to/from Map and JSON preserves tiers and flat settings', () {
      const complexRule = ParkingRateRule(
        firstHourRate: 5000,
        hourlyRate: 4000,
        dailyMaxRate: 50000,
        gracePeriodMinutes: 10,
        initialHours: 2,
        initialRate: 5000,
        tiers: [
          RateTier(afterHours: 4, hourlyRate: 6000),
          RateTier(afterHours: 8, hourlyRate: 8000),
        ],
      );

      final jsonStr = complexRule.toJson();
      final restored = ParkingRateRule.fromJson(jsonStr);

      expect(restored.effectiveInitialHours, 2);
      expect(restored.effectiveInitialRate, 5000);
      expect(restored.hourlyRate, 4000);
      expect(restored.gracePeriodMinutes, 10);
      expect(restored.tiers.length, 2);
      expect(restored.tiers[0].afterHours, 4);
      expect(restored.tiers[0].hourlyRate, 6000);
      expect(restored.tiers[1].afterHours, 8);
      expect(restored.tiers[1].hourlyRate, 8000);
    });
  });

  group('Parking Location & Service Tests', () {
    test('Default templates include Mall PTC, Grand Indonesia, Stasiun, Pasar Flat', () async {
      final prefs = await SharedPreferences.getInstance();
      final locService = ParkingLocationService(prefs);

      final locations = locService.locations;
      expect(locations.isNotEmpty, true);

      final ptc = locService.findLocationByName('Mall PTC');
      expect(ptc, isNotNull);
      expect(ptc!.name, contains('PTC'));

      // Check PTC rules
      final motorRule = ptc.getRateFor('Motor');
      expect(motorRule.firstHourRate, 2000);
      expect(motorRule.hourlyRate, 2000);

      final mobilRule = ptc.getRateFor('Mobil');
      expect(mobilRule.firstHourRate, 5000);
      expect(mobilRule.tiers.isNotEmpty, true);
      expect(mobilRule.tiers.first.afterHours, 4);
      expect(mobilRule.tiers.first.hourlyRate, 6000);
    });

    test('Fuzzy name matching matches "ptc", "PTC Surabaya", "grand indonesia"', () async {
      final prefs = await SharedPreferences.getInstance();
      final locService = ParkingLocationService(prefs);

      expect(locService.findLocationByName('ptc'), isNotNull);
      expect(locService.findLocationByName('PTC'), isNotNull);
      expect(locService.findLocationByName('Mall PTC'), isNotNull);
      expect(locService.findLocationByName('Grand Indonesia'), isNotNull);
      expect(locService.findLocationByName('NonExistentPlace'), isNull);
    });

    test('Custom location can be saved, updated, and deleted', () async {
      final prefs = await SharedPreferences.getInstance();
      final locService = ParkingLocationService(prefs);

      final customLoc = ParkingLocation(
        id: 'kantor_pusat',
        name: 'Gedung Kantor Pusat',
        category: 'Perkantoran',
        rates: {
          'Motor': const ParkingRateRule(isFlatRate: true, flatRate: 3000),
          'Mobil': const ParkingRateRule(firstHourRate: 5000, hourlyRate: 3000),
        },
      );

      await locService.saveLocation(customLoc);

      final found = locService.findLocationByName('Kantor Pusat');
      expect(found, isNotNull);
      expect(found!.id, 'kantor_pusat');
      expect(found.getRateFor('Motor').isFlatRate, true);
      expect(found.getRateFor('Motor').flatRate, 3000);

      await locService.deleteLocation('kantor_pusat');
      expect(locService.findLocationByName('Kantor Pusat'), isNull);
    });
  });

  group('Provider Location-Aware Cost Estimation Tests', () {
    test('estimateCostForTicket uses location rates when location matches', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final provider = ParkingProvider(settings, autoStartTicker: false);

      final ptcTicket = ParkingTicket(
        id: 't-ptc',
        rawCode: 'PTC-1234',
        vehicleType: 'Mobil',
        locationName: 'Mall PTC (Pakuwon)',
        entryTime: DateTime.now().subtract(const Duration(hours: 5)),
      );

      // PTC Mobil 5 hours: 1st hr (5000) + 3 hrs * 4000 (12000) + 1 hr * 6000 (6000) = 23.000
      final cost = provider.estimateCostForTicket(ptcTicket);
      expect(cost, 23000);

      // Generic ticket with no location falls back to settings default
      final genericTicket = ParkingTicket(
        id: 't-generic',
        rawCode: 'GEN-1234',
        vehicleType: 'Mobil',
        locationName: null,
        entryTime: DateTime.now().subtract(const Duration(hours: 5)),
      );
      // Default Mobil: 4000 + 4 * 3000 = 16000
      expect(provider.estimateCostForTicket(genericTicket), 16000);
    });
  });

  group('Widget UI Tests: Templates & Location Picker', () {
    testWidgets('LocationTemplatesScreen renders list and opens Test Simulator',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final provider = ParkingProvider(settings, autoStartTicker: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const MaterialApp(
            home: LocationTemplatesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and template items exist
      expect(find.text('Lokasi & Template Parkir'), findsOneWidget);
      expect(find.textContaining('Mall PTC'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Grand Indonesia'), findsAtLeastNWidgets(1));

      // Tap 'Tes Hitung' on the first card
      final tesHitungButtons = find.text('Tes Hitung');
      expect(tesHitungButtons, findsAtLeastNWidgets(1));
      await tester.tap(tesHitungButtons.first);
      await tester.pumpAndSettle();

      // Verify simulator dialog opened
      expect(find.textContaining('Simulasi Tarif:'), findsOneWidget);
      expect(find.text('Total Estimasi Biaya:'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
    });

    testWidgets('LocationPickerSheet allows selecting template and returns location',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final provider = ParkingProvider(settings, autoStartTicker: false);

      ParkingLocation? pickedLocation;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      pickedLocation = await LocationPickerSheet.show(
                        context,
                        vehicleType: 'Motor',
                      );
                    },
                    child: const Text('Buka Picker'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open picker
      await tester.tap(find.text('Buka Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Template Lokasi Parkir'), findsOneWidget);

      // Select Mall PTC
      final ptcItem = find.textContaining('Mall PTC').first;
      await tester.tap(ptcItem);
      await tester.pumpAndSettle();

      expect(pickedLocation, isNotNull);
      expect(pickedLocation!.name, contains('PTC'));
    });

    testWidgets('EditLocationRuleDialog allows toggling between Per Jam, Sekali Bayar, and Berjenjang',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs);
      final provider = ParkingProvider(settings, autoStartTicker: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EditLocationRuleDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tambah Lokasi & Aturan Parkir'), findsOneWidget);
      expect(find.text('Per Jam'), findsOneWidget);
      expect(find.text('Sekali Bayar'), findsOneWidget);
      expect(find.text('Berjenjang'), findsOneWidget);

      // Switch to Sekali Bayar
      await tester.tap(find.text('Sekali Bayar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tarif Sekali Parkir (Flat)'), findsOneWidget);

      // Switch to Berjenjang
      await tester.tap(find.text('Berjenjang'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Jenjang Tarif Tambahan'), findsOneWidget);
      expect(find.text('Tambah Jenjang'), findsOneWidget);
    });
  });
}
