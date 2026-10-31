import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/location_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:karcis_parkir/services/ticket_share_service.dart';
import 'package:karcis_parkir/screens/ticket_detail_screen.dart';
import 'package:karcis_parkir/widgets/ticket_card.dart';
import 'package:karcis_parkir/widgets/edit_parking_location_sheet.dart';
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
    LocationService.testMockResult = null;
    LocationService.mockLaunchUrlHandler = null;
    await DatabaseService.instance.clearAll();
  });

  group('Find My Vehicle: Model & Serialization Tests', () {
    test('ParkingTicket serialization and deserialization preserves parking location fields', () {
      final ticket = ParkingTicket(
        id: 'ticket-loc-1',
        rawCode: 'PARK-LOC-12345',
        format: 'QR_CODE',
        entryTime: DateTime(2026, 10, 29, 10, 30),
        vehicleType: 'Mobil',
        parkingFloor: 'B2',
        parkingBlock: 'Tiang F12',
        parkingPhotoPath: '/data/user/0/com.example.karcisparkir/cache/pillar_123.jpg',
        latitude: -6.2088,
        longitude: 106.8456,
      );

      final map = ticket.toMap();
      expect(map['parkingFloor'], 'B2');
      expect(map['parkingBlock'], 'Tiang F12');
      expect(map['parkingPhotoPath'], '/data/user/0/com.example.karcisparkir/cache/pillar_123.jpg');
      expect(map['latitude'], -6.2088);
      expect(map['longitude'], 106.8456);

      final reconstructed = ParkingTicket.fromMap(map);
      expect(reconstructed.id, 'ticket-loc-1');
      expect(reconstructed.parkingFloor, 'B2');
      expect(reconstructed.parkingBlock, 'Tiang F12');
      expect(reconstructed.parkingPhotoPath, '/data/user/0/com.example.karcisparkir/cache/pillar_123.jpg');
      expect(reconstructed.latitude, -6.2088);
      expect(reconstructed.longitude, 106.8456);
      expect(reconstructed.hasVehicleLocation, isTrue);
    });

    test('ParkingTicket hasVehicleLocation and parkingLocationSummary helpers work correctly', () {
      final emptyLocationTicket = ParkingTicket(
        id: 'ticket-none',
        rawCode: 'CODE-000',
        format: 'QR_CODE',
        entryTime: DateTime.now(),
        vehicleType: 'Motor',
      );
      expect(emptyLocationTicket.hasVehicleLocation, isFalse);
      expect(emptyLocationTicket.parkingLocationSummary, isNull);

      final floorOnlyTicket = emptyLocationTicket.copyWith(parkingFloor: 'P1');
      expect(floorOnlyTicket.hasVehicleLocation, isTrue);
      expect(floorOnlyTicket.parkingLocationSummary, 'Lantai P1');

      final blockOnlyTicket = emptyLocationTicket.copyWith(parkingBlock: 'Blok A3');
      expect(blockOnlyTicket.hasVehicleLocation, isTrue);
      expect(blockOnlyTicket.parkingLocationSummary, 'Blok A3');

      final fullLocationTicket = emptyLocationTicket.copyWith(
        parkingFloor: 'B2',
        parkingBlock: 'Tiang F12',
      );
      expect(fullLocationTicket.hasVehicleLocation, isTrue);
      expect(fullLocationTicket.parkingLocationSummary, 'Lantai B2 • Tiang F12');

      final gpsOnlyTicket = emptyLocationTicket.copyWith(
        latitude: -6.2000,
        longitude: 106.8000,
      );
      expect(gpsOnlyTicket.hasVehicleLocation, isTrue);
      expect(gpsOnlyTicket.parkingLocationSummary, 'Titik GPS');
      expect(emptyLocationTicket.googleMapsUrl, isNull);
      expect(gpsOnlyTicket.googleMapsUrl, 'https://www.google.com/maps/search/?api=1&query=-6.2,106.8');

      // Test TicketShareService includes Google Maps navigation link
      final shareMsg = TicketShareService.buildShareMessage(gpsOnlyTicket);
      expect(shareMsg, contains('🗺️ *Navigasi Google Maps:* https://www.google.com/maps/search/?api=1&query=-6.2,106.8'));
    });

    test('ParkingTicket copyWith supports updating and clearing location fields cleanly', () {
      final original = ParkingTicket(
        id: 'orig-1',
        rawCode: 'CODE-ORIG',
        format: 'QR_CODE',
        entryTime: DateTime.now(),
        vehicleType: 'Mobil',
        parkingFloor: 'Lt 3',
        parkingBlock: 'Tiang C09',
        parkingPhotoPath: '/path/to/photo.jpg',
        latitude: -6.1754,
        longitude: 106.8272,
      );

      // Partial update
      final updated = original.copyWith(
        parkingFloor: 'Lt 4',
      );
      expect(updated.parkingFloor, 'Lt 4');
      expect(updated.parkingBlock, 'Tiang C09');
      expect(updated.parkingPhotoPath, '/path/to/photo.jpg');
      expect(updated.latitude, -6.1754);

      // Clearing fields
      final cleared = updated.copyWith(
        clearParkingFloor: true,
        clearParkingBlock: true,
        clearParkingPhoto: true,
        clearCoordinates: true,
      );
      expect(cleared.parkingFloor, isNull);
      expect(cleared.parkingBlock, isNull);
      expect(cleared.parkingPhotoPath, isNull);
      expect(cleared.latitude, isNull);
      expect(cleared.longitude, isNull);
      expect(cleared.hasVehicleLocation, isFalse);
    });
  });

  group('Find My Vehicle: LocationService Tests', () {
    test('getCurrentCoordinates returns mock coordinates when set in tests', () async {
      LocationService.testMockResult = LocationResult.success(
        latitude: -6.12345,
        longitude: 106.98765,
      );

      final result = await LocationService.getCurrentCoordinates();
      expect(result.isSuccess, isTrue);
      expect(result.latitude, -6.12345);
      expect(result.longitude, 106.98765);
      expect(result.errorMessage, isNull);
    });

    test('getCurrentCoordinates returns error when mock fails', () async {
      LocationService.testMockResult = LocationResult.failure('GPS tidak aktif');

      final result = await LocationService.getCurrentCoordinates();
      expect(result.isSuccess, isFalse);
      expect(result.latitude, isNull);
      expect(result.longitude, isNull);
      expect(result.errorMessage, 'GPS tidak aktif');
    });

    test('openGoogleMaps triggers mockLaunchUrlHandler with correct geo URI and label', () async {
      Uri? launchedUri;
      LocationService.mockLaunchUrlHandler = (uri) async {
        launchedUri = uri;
        return true;
      };

      final success = await LocationService.openGoogleMaps(
        latitude: -6.2088,
        longitude: 106.8456,
        label: 'Mobil B 1234 XYZ',
      );

      expect(success, isTrue);
      expect(launchedUri, isNotNull);
      expect(launchedUri!.scheme, 'geo');
      expect(launchedUri.toString(), contains('-6.2088,106.8456'));
      expect(launchedUri.toString(), contains('Mobil%20B%201234%20XYZ'));
    });
  });

  group('Find My Vehicle: Database & Provider Integration Tests', () {
    test('ParkingProvider addTicket persists vehicle location parameters', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);
      await provider.loadTickets();

      await provider.addTicket(
        rawCode: 'FIND-MY-CAR-001',
        format: 'QR_CODE',
        vehicleType: 'Mobil',
        parkingFloor: 'B2',
        parkingBlock: 'Tiang F12',
        parkingPhotoPath: '/mock/path/pillar.jpg',
        latitude: -6.2088,
        longitude: 106.8456,
      );

      expect(provider.tickets.length, 1);
      final ticket = provider.tickets.first;
      expect(ticket.parkingFloor, 'B2');
      expect(ticket.parkingBlock, 'Tiang F12');
      expect(ticket.parkingPhotoPath, '/mock/path/pillar.jpg');
      expect(ticket.latitude, -6.2088);
      expect(ticket.longitude, 106.8456);
      expect(ticket.hasVehicleLocation, isTrue);

      // Verify directly from SQLite
      final allDbTickets = await DatabaseService.instance.getAllTickets();
      expect(allDbTickets.length, 1);
      expect(allDbTickets.first.parkingFloor, 'B2');
      expect(allDbTickets.first.parkingBlock, 'Tiang F12');
      expect(allDbTickets.first.latitude, -6.2088);
      expect(allDbTickets.first.longitude, 106.8456);
    });

    test('ParkingProvider updateParkingLocation updates and clears parking location in memory and SQLite', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);
      await provider.loadTickets();

      await provider.addTicket(
        rawCode: 'FIND-MY-CAR-002',
        format: 'QR_CODE',
        vehicleType: 'Mobil',
      );

      final ticketId = provider.tickets.first.id;
      expect(provider.tickets.first.hasVehicleLocation, isFalse);

      // Update location
      await provider.updateParkingLocation(
        ticketId,
        parkingFloor: 'P2',
        parkingBlock: 'Tiang C15',
        parkingPhotoPath: '/images/pillar.jpg',
        latitude: -6.3000,
        longitude: 106.7000,
      );

      var updated = provider.tickets.firstWhere((t) => t.id == ticketId);
      expect(updated.parkingFloor, 'P2');
      expect(updated.parkingBlock, 'Tiang C15');
      expect(updated.parkingPhotoPath, '/images/pillar.jpg');
      expect(updated.latitude, -6.3000);
      expect(updated.longitude, 106.7000);

      // Clear parking block and GPS coordinates
      await provider.updateParkingLocation(
        ticketId,
        clearParkingBlock: true,
        clearCoordinates: true,
      );

      updated = provider.tickets.firstWhere((t) => t.id == ticketId);
      expect(updated.parkingFloor, 'P2');
      expect(updated.parkingBlock, isNull);
      expect(updated.latitude, isNull);
      expect(updated.longitude, isNull);
      expect(updated.parkingLocationSummary, 'Lantai P2');
    });
  });

  group('Find My Vehicle: Widget Tests', () {
    testWidgets('TicketCard displays location tag pill when vehicle location exists', (tester) async {
      final ticketWithLocation = ParkingTicket(
        id: 't-loc-card',
        rawCode: 'CARD-LOC-999',
        format: 'QR_CODE',
        entryTime: DateTime.now().subtract(const Duration(minutes: 45)),
        vehicleType: 'Mobil',
        parkingFloor: 'B2',
        parkingBlock: 'Tiang F12',
        latitude: -6.2088,
        longitude: 106.8456,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCard(
              ticket: ticketWithLocation,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that location summary is displayed on card
      expect(find.text('Lantai B2 • Tiang F12'), findsOneWidget);
      expect(find.byIcon(Icons.pin_drop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.gps_fixed_rounded), findsWidgets);
    });

    testWidgets('TicketDetailScreen renders Find My Vehicle section with Lantai, Blok, GPS and Google Maps action', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      late ParkingTicket liveTicket;
      await tester.runAsync(() async {
        liveTicket = await provider.addTicket(
          rawCode: 'DETAIL-LOC-123',
          format: 'QR_CODE',
          vehicleType: 'Mobil',
          parkingFloor: 'B2',
          parkingBlock: 'Tiang F12',
          latitude: -6.2088,
          longitude: 106.8456,
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
            home: TicketDetailScreen(ticket: liveTicket),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Titik Parkir card header
      expect(find.text('Find My Vehicle'), findsOneWidget);
      expect(find.text('Titik Parkir & Letak Kendaraan'), findsOneWidget);

      // Verify Floor and Block summary
      expect(find.text('Lantai B2 • Tiang F12'), findsWidgets);

      // Verify GPS pin coordinates and Google Maps button
      expect(find.text('Buka di Google Maps'), findsOneWidget);

      // Verify Edit button exists
      expect(find.text('Ubah Lokasi'), findsOneWidget);
    });

    testWidgets('EditParkingLocationSheet opens, sets floor chip, and saves correctly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      late ParkingTicket activeTicket;
      await tester.runAsync(() async {
        activeTicket = await provider.addTicket(
          rawCode: 'TEST-EDIT-SHEET',
          format: 'QR_CODE',
          vehicleType: 'Mobil',
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
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => EditParkingLocationSheet.show(context, activeTicket),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet title and inputs
      expect(find.text('Titik Parkir Kendaraan'), findsOneWidget);
      expect(find.text('Lantai Parkir'), findsOneWidget);
      expect(find.text('No. Tiang / Blok'), findsOneWidget);

      // Tap quick chip 'B2'
      await tester.tap(find.text('B2'));
      await tester.pumpAndSettle();

      // Enter block text
      await tester.enterText(find.widgetWithText(TextField, 'Tiang F12, Blok C'), 'Tiang E05');
      await tester.pumpAndSettle();

      // Tap Simpan Lokasi Parkir
      await tester.ensureVisible(find.text('Simpan Lokasi Parkir'));
      await tester.tap(find.text('Simpan Lokasi Parkir'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Check provider has updated ticket
      final updated = provider.tickets.first;
      expect(updated.parkingFloor, 'B2');
      expect(updated.parkingBlock, 'Tiang E05');
      expect(updated.parkingLocationSummary, 'Lantai B2 • Tiang E05');
    });

    testWidgets('TicketCard displays + Catat Titik Parkir when location is missing and opens sheet', (tester) async {
      final ticketWithoutLocation = ParkingTicket(
        id: 't-no-loc',
        rawCode: 'CARD-NO-LOC-111',
        format: 'QR_CODE',
        entryTime: DateTime.now().subtract(const Duration(minutes: 20)),
        vehicleType: 'Motor',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCard(
              ticket: ticketWithoutLocation,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('+ Catat Titik Parkir (Lantai, Tiang, GPS)'), findsOneWidget);
      expect(find.byIcon(Icons.pin_drop_outlined), findsOneWidget);
    });

    testWidgets('TicketCard Buka Peta invokes LocationService.openGoogleMaps directly', (tester) async {
      final ticketWithGps = ParkingTicket(
        id: 't-gps-card',
        rawCode: 'CARD-GPS-222',
        format: 'QR_CODE',
        plateNumber: 'B 8888 GPS',
        entryTime: DateTime.now().subtract(const Duration(minutes: 10)),
        vehicleType: 'Mobil',
        latitude: -6.2100,
        longitude: 106.8500,
      );

      Uri? launchedUri;
      LocationService.mockLaunchUrlHandler = (uri) async {
        launchedUri = uri;
        return true;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCard(
              ticket: ticketWithGps,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Buka Peta'), findsOneWidget);
      await tester.tap(find.text('Buka Peta'));
      await tester.pumpAndSettle();

      expect(launchedUri, isNotNull);
      expect(launchedUri.toString(), contains('-6.21,106.85'));
    });

    testWidgets('EditParkingLocationSheet block prefix chips append to block input and copy link works', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      late ParkingTicket testTicket;
      await tester.runAsync(() async {
        testTicket = await provider.addTicket(
          rawCode: 'TEST-CHIPS-SHEET',
          latitude: -6.1750,
          longitude: 106.8280,
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
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => EditParkingLocationSheet.show(context, testTicket),
                  child: const Text('Open Location Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Location Sheet'));
      await tester.pumpAndSettle();

      // Check block suggestion chip '+ Tiang ' exists
      expect(find.text('+ Tiang '), findsOneWidget);
      await tester.tap(find.text('+ Tiang '));
      await tester.pumpAndSettle();

      // Check TextField now has 'Tiang '
      expect(find.text('Tiang '), findsOneWidget);

      // Check copy link icon button is present
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Tautan Google Maps disalin ke clipboard.'), findsOneWidget);
    });

    testWidgets('TicketDetailScreen allows clearing coordinates and photo cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      late ParkingTicket liveTicket;
      await tester.runAsync(() async {
        liveTicket = await provider.addTicket(
          rawCode: 'DETAIL-CLEAR-TEST',
          format: 'QR_CODE',
          parkingFloor: 'B1',
          parkingBlock: 'Tiang A01',
          parkingPhotoPath: '/mock/photo/pillar.jpg',
          latitude: -6.2088,
          longitude: 106.8456,
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
            home: TicketDetailScreen(ticket: liveTicket),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear coordinates
      final clearCoordinatesBtn = find.text('Hapus');
      expect(clearCoordinatesBtn, findsOneWidget);
      await tester.tap(clearCoordinatesBtn);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Verify coordinates cleared in provider
      var updated = provider.tickets.first;
      expect(updated.latitude, isNull);
      expect(updated.longitude, isNull);

      // Dismiss any open snackbars before interacting with photo controls
      ScaffoldMessenger.of(tester.element(find.byType(TicketDetailScreen))).clearSnackBars();
      await tester.pump();

      // Clear photo
      final clearPhotoBtn = find.text('Hapus Foto');
      await tester.ensureVisible(clearPhotoBtn);
      await tester.pumpAndSettle();
      await tester.tap(clearPhotoBtn);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Verify photo cleared in provider
      updated = provider.tickets.first;
      expect(updated.parkingPhotoPath, isNull);
    });
  });
}
