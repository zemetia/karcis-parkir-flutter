import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/providers/parking_provider.dart';
import 'package:karcis_parkir/screens/ticket_detail_screen.dart';
import 'package:karcis_parkir/services/database_service.dart';
import 'package:karcis_parkir/services/photo_service.dart';
import 'package:karcis_parkir/services/settings_service.dart';
import 'package:karcis_parkir/services/ticket_share_service.dart';
import 'package:karcis_parkir/widgets/parking_photo_viewer.dart';
import 'package:karcis_parkir/widgets/ticket_card.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
    PhotoService.testMockImagePath = null;
    PhotoService.testMockTicketImagePath = null;
    TicketShareService.mockShareHandler = null;
    TicketShareService.mockLaunchUrlHandler = null;
    TicketShareService.testMockTempDirPath = null;
  });

  group('Pencegahan Denda: Model & Serialization Tests', () {
    test('ParkingTicket serializes and deserializes ticketPhotoPath', () {
      final ticket = ParkingTicket(
        id: 'ticket-photo-101',
        rawCode: 'CODE-STRUK-999',
        format: 'QR_CODE',
        plateNumber: 'B 1234 ABC',
        vehicleType: 'Mobil',
        locationName: 'Pondok Indah Mall',
        entryTime: DateTime(2026, 10, 29, 10, 0),
        ticketPhotoPath: '/data/user/0/com.karcisparkir/ticket_photos/ticket_123.jpg',
      );

      expect(ticket.ticketPhotoPath, '/data/user/0/com.karcisparkir/ticket_photos/ticket_123.jpg');
      expect(ticket.hasTicketPhoto, isTrue);

      final map = ticket.toMap();
      expect(map['ticketPhotoPath'], '/data/user/0/com.karcisparkir/ticket_photos/ticket_123.jpg');

      final fromMap = ParkingTicket.fromMap(map);
      expect(fromMap.id, ticket.id);
      expect(fromMap.ticketPhotoPath, ticket.ticketPhotoPath);
      expect(fromMap.hasTicketPhoto, isTrue);
    });

    test('copyWith updates or clears ticketPhotoPath cleanly', () {
      final ticket = ParkingTicket(
        id: 'ticket-copy-1',
        rawCode: 'RAW-1',
        entryTime: DateTime.now(),
        ticketPhotoPath: '/path/old_ticket.jpg',
      );
      expect(ticket.hasTicketPhoto, isTrue);

      final updated = ticket.copyWith(ticketPhotoPath: '/path/new_ticket.jpg');
      expect(updated.ticketPhotoPath, '/path/new_ticket.jpg');
      expect(updated.hasTicketPhoto, isTrue);

      final cleared = updated.copyWith(clearTicketPhoto: true);
      expect(cleared.ticketPhotoPath, isNull);
      expect(cleared.hasTicketPhoto, isFalse);
    });
  });

  group('Pencegahan Denda: Database & Provider Flow Tests', () {
    test('DatabaseService persists and updates ticketPhotoPath', () async {
      final ticket = ParkingTicket(
        id: 'db-test-photo-1',
        rawCode: 'DB-RAW-123',
        entryTime: DateTime.now(),
        ticketPhotoPath: '/dummy/photo/ticket.jpg',
      );

      await DatabaseService.instance.insertTicket(ticket);
      final retrieved = await DatabaseService.instance.getTicketById(ticket.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.ticketPhotoPath, '/dummy/photo/ticket.jpg');
      expect(retrieved.hasTicketPhoto, isTrue);
    });

    test('ParkingProvider updateTicketPhoto adds and clears physical ticket photo', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);
      await provider.loadTickets();

      final ticket = await provider.addTicket(
        rawCode: 'PRK-990011',
        plateNumber: 'D 9999 AA',
        vehicleType: 'Mobil',
      );
      expect(ticket.hasTicketPhoto, isFalse);

      // Add physical photo attachment
      await provider.updateTicketPhoto(
        ticket.id,
        ticketPhotoPath: '/storage/emulated/0/karcis/ticket_struk.jpg',
      );

      final updated = provider.tickets.firstWhere((t) => t.id == ticket.id);
      expect(updated.hasTicketPhoto, isTrue);
      expect(updated.ticketPhotoPath, '/storage/emulated/0/karcis/ticket_struk.jpg');

      // Clear physical photo
      await provider.updateTicketPhoto(
        ticket.id,
        clearTicketPhoto: true,
      );

      final cleared = provider.tickets.firstWhere((t) => t.id == ticket.id);
      expect(cleared.hasTicketPhoto, isFalse);
      expect(cleared.ticketPhotoPath, isNull);

      provider.dispose();
    });
  });

  group('Keamanan & Bagikan Karcis: TicketShareService Tests', () {
    test('buildShareMessage generates complete details with fine avoidance notice', () {
      final ticket = ParkingTicket(
        id: 'share-test-1',
        rawCode: 'KRC-888999',
        format: 'QR_CODE',
        plateNumber: 'B 2345 SSS',
        vehicleType: 'Mobil',
        locationName: 'Senayan City',
        entryTime: DateTime(2026, 10, 29, 14, 30),
        ticketPhotoPath: '/photos/struk.jpg',
      );

      final message = TicketShareService.buildShareMessage(ticket);

      expect(message, contains('KARCIS PARKIR'));
      expect(message, contains('Senayan City'));
      expect(message, contains('B 2345 SSS'));
      expect(message, contains('Mobil'));
      expect(message, contains('KRC-888999'));
      expect(message, contains('QR Code'));
      expect(message, contains('Foto struk fisik karcis dilampirkan'));
      expect(message, contains('denda karcis hilang'));
    });

    test('shareToWhatsApp launches deep link correctly', () async {
      final ticket = ParkingTicket(
        id: 'wa-share-1',
        rawCode: 'WA-CODE-777',
        entryTime: DateTime.now(),
      );

      Uri? launchedUri;
      TicketShareService.mockLaunchUrlHandler = (uri) async {
        launchedUri = uri;
        return true;
      };

      final result = await TicketShareService.shareToWhatsApp(ticket);
      expect(result, isTrue);
      expect(launchedUri, isNotNull);
      expect(launchedUri!.scheme, 'whatsapp');
      expect(launchedUri.toString(), contains('WA-CODE-777'));
    });

    test('shareToTelegram launches deep link correctly', () async {
      final ticket = ParkingTicket(
        id: 'tg-share-1',
        rawCode: 'TG-CODE-888',
        entryTime: DateTime.now(),
      );

      Uri? launchedUri;
      TicketShareService.mockLaunchUrlHandler = (uri) async {
        launchedUri = uri;
        return true;
      };

      final result = await TicketShareService.shareToTelegram(ticket);
      expect(result, isTrue);
      expect(launchedUri, isNotNull);
      expect(launchedUri!.scheme, 'tg');
      expect(launchedUri.toString(), contains('TG-CODE-888'));
    });

    test('shareTicketViaSystem bundles QR image and physical photo attachment', () async {
      // Create temporary files to simulate QR and physical photo
      final tempDir = await Directory.systemTemp.createTemp('share_test');
      final qrFile = File('${tempDir.path}/qr.png');
      await qrFile.writeAsString('dummy-qr-content');
      final physicalPhoto = File('${tempDir.path}/struk.jpg');
      await physicalPhoto.writeAsString('dummy-photo-content');

      final ticket = ParkingTicket(
        id: 'bundle-share-1',
        rawCode: 'BUNDLE-1234',
        entryTime: DateTime.now(),
        ticketPhotoPath: physicalPhoto.path,
      );

      List<XFile>? sharedFiles;
      String? sharedText;
      TicketShareService.mockShareHandler = (files, {text, subject}) async {
        sharedFiles = files;
        sharedText = text;
      };

      await TicketShareService.shareTicketViaSystem(
        ticket: ticket,
        qrImagePath: qrFile.path,
      );

      expect(sharedFiles, isNotNull);
      expect(sharedFiles!.length, 2);
      expect(sharedFiles!.any((f) => f.path.contains('qr.png')), isTrue);
      expect(sharedFiles!.any((f) => f.path.contains('struk.jpg')), isTrue);
      expect(sharedText, contains('BUNDLE-1234'));
    });

    test('generateBarcodeImageFile generates valid 1D barcode PNG file', () async {
      final barcode = Barcode.code128();
      final path = await TicketShareService.generateBarcodeImageFile(
        barcode: barcode,
        data: 'CODE128-TEST-1234',
        fileName: 'test_barcode_128_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      expect(path, isNotNull);
      final file = File(path!);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));
    });

    test('generateTicketCodeImageFile generates corresponding image format for Barcode vs QR', () async {
      final barcodeTicket = ParkingTicket(
        id: 'ticket-barcode-1',
        rawCode: 'BARCODE-9988',
        format: 'CODE_128',
        entryTime: DateTime.now(),
      );
      final qrTicket = ParkingTicket(
        id: 'ticket-qr-1',
        rawCode: 'QR-9988',
        format: 'QR_CODE',
        entryTime: DateTime.now(),
      );

      final barcodePath = await TicketShareService.generateTicketCodeImageFile(barcodeTicket);
      final qrPath = await TicketShareService.generateTicketCodeImageFile(qrTicket);

      expect(barcodePath, isNotNull);
      expect(qrPath, isNotNull);
      expect(await File(barcodePath!).exists(), isTrue);
      expect(await File(qrPath!).exists(), isTrue);
    });
  });

  group('Widget Tests: Bukti Fisik & Bagikan Karcis UI', () {
    testWidgets('TicketDetailScreen displays Bukti Fisik card, penalty warning banner, and share actions',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.init();
      final provider = ParkingProvider(settings, autoStartTicker: false);

      late ParkingTicket ticket;
      await tester.runAsync(() async {
        ticket = await provider.addTicket(
          rawCode: 'PRK-SECURE-999',
          plateNumber: 'B 4321 KRC',
          vehicleType: 'Mobil',
          locationName: 'Grand Indonesia West Mall',
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

      // 1. Verify Share Button in AppBar and under QR Card
      expect(find.byTooltip('Bagikan Karcis (WhatsApp / Telegram)'), findsOneWidget);
      expect(find.text('Bagikan Karcis (WhatsApp / Telegram)'), findsOneWidget);

      // 2. Verify Bukti Fisik Karcis Kertas Card & Fine Avoidance Banner
      expect(find.text('Bukti Fisik Karcis Kertas'), findsOneWidget);
      expect(find.textContaining('Pencegahan Denda'), findsOneWidget);
      expect(find.textContaining('Rp 25.000 - Rp 50.000'), findsOneWidget);
      expect(find.text('Foto Karcis Kertas (Cegah Denda)'), findsOneWidget);

      // 3. Test tapping "Foto Karcis Kertas" with mock
      PhotoService.testMockTicketImagePath = '/dummy/test_ticket_photo.jpg';
      await tester.ensureVisible(find.text('Foto Karcis Kertas (Cegah Denda)'));
      await tester.tap(find.text('Foto Karcis Kertas (Cegah Denda)'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Verify photo attachment updated in provider
      expect(provider.tickets.first.hasTicketPhoto, isTrue);
      expect(provider.tickets.first.ticketPhotoPath, '/dummy/test_ticket_photo.jpg');

      // Verify UI reflects "Tersimpan", "Foto Karcis Fisik Terlampir", "Lihat Full", "Ganti Foto", "Hapus"
      expect(find.text('Tersimpan'), findsOneWidget);
      expect(find.text('Foto Karcis Fisik Terlampir'), findsOneWidget);
      expect(find.text('Lihat Full'), findsOneWidget);
      expect(find.text('Ganti Foto'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);

      // 4. Test Opening Share Bottom Sheet via quick button
      await tester.ensureVisible(find.text('Bagikan Karcis (WhatsApp / Telegram)'));
      await tester.tap(find.text('Bagikan Karcis (WhatsApp / Telegram)'));
      await tester.pumpAndSettle();

      // Verify Share Bottom Sheet Content
      expect(find.text('Bagikan Karcis Parkir'), findsOneWidget);
      expect(find.text('Bagikan Lengkap (Gambar Barcode/QR + Rincian)'), findsOneWidget);
      expect(find.text('Kirim ke WhatsApp'), findsOneWidget);
      expect(find.text('Kirim ke Telegram'), findsOneWidget);
      expect(find.text('Salin Rincian & Kode Karcis'), findsOneWidget);

      // 5. Test Kirim ke WhatsApp trigger
      bool waLaunched = false;
      TicketShareService.mockLaunchUrlHandler = (uri) async {
        if (uri.scheme == 'whatsapp') {
          waLaunched = true;
        }
        return true;
      };

      await tester.tap(find.text('Kirim ke WhatsApp'));
      await tester.pumpAndSettle();
      expect(waLaunched, isTrue);

      provider.dispose();
    });

    testWidgets('ParkingPhotoViewer displays contextual title and hint for physical ticket photos without hardcoded tiang label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ParkingPhotoViewer(
              imagePath: '/non_existent/struk_viewer.jpg',
              title: 'Foto Struk Fisik Karcis',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Foto Struk Fisik Karcis'), findsOneWidget);
      expect(find.text('Cubit untuk zoom • Ketuk putar jika miring'), findsOneWidget);
      expect(find.textContaining('foto tiang'), findsNothing);
    });

    testWidgets('TicketCard allows tapping Bukti Fisik Karcis badge to view photo', (WidgetTester tester) async {
      final ticket = ParkingTicket(
        id: 'ticket-badge-card',
        rawCode: 'RAW-BADGE-1',
        entryTime: DateTime.now(),
        ticketPhotoPath: '/non_existent/ticket_badge.jpg',
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

      expect(find.text('Bukti Fisik Karcis'), findsOneWidget);
      await tester.tap(find.text('Bukti Fisik Karcis'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Foto Struk Fisik Karcis'), findsOneWidget);
    });
  });
}
