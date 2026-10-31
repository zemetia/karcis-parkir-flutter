import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:karcis_parkir/widgets/qr_display.dart';

void main() {
  group('1D Barcode and QR Rendering Tests', () {
    test('Barcode formats can be resolved correctly', () {
      final c128 = QrDisplayCard.resolveBarcode('CODE_128', 'PRK-123456');
      expect(c128.name, contains('128'));

      final c39 = QrDisplayCard.resolveBarcode('CODE_39', 'PRK123456');
      expect(c39.name, contains('39'));

      final ean13 = QrDisplayCard.resolveBarcode('EAN_13', '899275321011');
      expect(ean13.name, contains('13'));

      final fallback = QrDisplayCard.resolveBarcode('UNKNOWN_FORMAT', 'PRK-999');
      expect(fallback.name, contains('128'));
    });

    testWidgets('QrDisplayCard renders BarcodeWidget when ticket format is 1D barcode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrDisplayCard(
              data: 'PRK-12345-CODE128',
              format: 'CODE_128',
              subtitle: 'Format Asli: Barcode (Code 128)',
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify BarcodeWidget is rendered instead of QrImageView
      expect(find.byType(BarcodeWidget), findsOneWidget);
      expect(find.text('Format Asli: Barcode (Code 128)'), findsOneWidget);
      expect(find.text('PRK-12345-CODE128'), findsOneWidget);
      expect(find.text('Beralih ke QR Code'), findsOneWidget);

      // Tap toggle to switch to QR view
      await tester.tap(find.text('Beralih ke QR Code'));
      await tester.pump();
      expect(find.text('Beralih ke Barcode Garis 1D'), findsOneWidget);

      // Tap toggle again to return to Barcode view
      await tester.tap(find.text('Beralih ke Barcode Garis 1D'));
      await tester.pump();
      expect(find.text('Beralih ke QR Code'), findsOneWidget);
      expect(find.byType(BarcodeWidget), findsOneWidget);
    });

    testWidgets('QrDisplayCard fullscreen view displays barcode and scan guidance', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrDisplayCard(
              data: 'PRK-BARCODE-FULLSCREEN',
              format: 'CODE_128',
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap to open fullscreen
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Verify guidance text
      expect(find.text('Arahkan barcode garis ke pemindai loket keluar'), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('PRK-BARCODE-FULLSCREEN')), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);

      // Close fullscreen
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Arahkan barcode garis ke pemindai loket keluar'), findsNothing);
    });

    testWidgets('QrDisplayCard defaults to QR code when format is QR', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrDisplayCard(
              data: 'PRK-QR-DEFAULT',
              format: 'QR_CODE',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BarcodeWidget), findsNothing);
      expect(find.text('Beralih ke Barcode Garis 1D'), findsNothing);
      expect(find.text('PRK-QR-DEFAULT'), findsOneWidget);
    });
  });
}
