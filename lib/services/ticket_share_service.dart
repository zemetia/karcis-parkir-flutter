import 'dart:io';
import 'dart:ui' as ui;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/parking_ticket.dart';
import '../screens/scan_screen.dart';
import '../widgets/qr_display.dart';

class TicketShareService {
  /// Test hooks for mock testing without real device / OS plugins
  static Future<void> Function(List<XFile> files, {String? text, String? subject})? mockShareHandler;
  static Future<bool> Function(Uri uri)? mockLaunchUrlHandler;
  static String? testMockTempDirPath;

  static Future<Directory> _resolveTempDir() async {
    if (testMockTempDirPath != null) {
      final dir = Directory(testMockTempDirPath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Build a clean, structured Indonesian message for WhatsApp, Telegram, or any chat app
  static String buildShareMessage(ParkingTicket ticket) {
    final buffer = StringBuffer();
    buffer.writeln('🎟️ *KARCIS PARKIR*');

    if (ticket.locationName != null && ticket.locationName!.trim().isNotEmpty) {
      buffer.writeln('📍 *Lokasi:* ${ticket.locationName!.trim()}');
    }

    if (ticket.plateNumber != null && ticket.plateNumber!.trim().isNotEmpty) {
      buffer.writeln('🚗 *Kendaraan:* ${ticket.vehicleType} (${ticket.plateNumber!.trim()})');
    } else {
      buffer.writeln('🚗 *Kendaraan:* ${ticket.vehicleType}');
    }

    if (ticket.parkingLocationSummary != null) {
      buffer.writeln('🅿️ *Posisi Parkir:* ${ticket.parkingLocationSummary}');
    }

    if (ticket.googleMapsUrl != null) {
      buffer.writeln('🗺️ *Navigasi Google Maps:* ${ticket.googleMapsUrl}');
    }

    String formattedDate;
    try {
      formattedDate = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(ticket.entryTime);
    } catch (_) {
      formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(ticket.entryTime);
    }
    buffer.writeln('🕒 *Waktu Masuk:* $formattedDate');
    buffer.writeln('⏱️ *Durasi:* ${ticket.durationFormatted}');
    buffer.writeln('🔢 *Nomor/Kode Tiket:* ${ticket.rawCode}');

    final formatName = ScanScreen.formatDisplayName(ticket.format);
    buffer.writeln('🏷️ *Format:* $formatName');

    if (ticket.notes != null && ticket.notes!.trim().isNotEmpty) {
      buffer.writeln('📝 *Catatan:* ${ticket.notes!.trim()}');
    }

    if (ticket.hasTicketPhoto) {
      buffer.writeln('📸 *Bukti Fisik:* Foto struk fisik karcis dilampirkan (aman dari denda karcis hilang)');
    }

    buffer.writeln('');
    buffer.writeln('ℹ️ *Tunjukkan kode barcode/QR ini ke loket atau pos keluar parkir.*');

    return buffer.toString();
  }

  /// Capture a RepaintBoundary widget (e.g. QrDisplayCard) into a high-res PNG file
  static Future<String?> captureRepaintBoundary(GlobalKey boundaryKey, {String? fileName}) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await _resolveTempDir();
      final targetName = fileName ?? 'qr_ticket_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(tempDir.path, targetName));
      await file.writeAsBytes(pngBytes, flush: true);

      return file.path;
    } catch (e) {
      debugPrint('Error capturing repaint boundary: $e');
      return null;
    }
  }

  /// Standalone 1D Barcode PNG generator using Canvas and Barcode drawing operations
  static Future<String?> generateBarcodeImageFile({
    required Barcode barcode,
    required String data,
    String? fileName,
    double width = 600,
    double height = 240,
  }) async {
    try {
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      // Solid white background with padding
      final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

      const double horizontalMargin = 30.0;
      const double verticalMargin = 20.0;
      final barcodeWidth = width - (horizontalMargin * 2);
      final barcodeHeight = height - (verticalMargin * 2);

      final barPaint = Paint()..color = const Color(0xFF000000);

      // Render barcode bars
      for (final element in barcode.make(
        data,
        width: barcodeWidth,
        height: barcodeHeight,
        drawText: false,
      )) {
        if (element is BarcodeBar && element.black) {
          canvas.drawRect(
            Rect.fromLTWH(
              horizontalMargin + element.left,
              verticalMargin + element.top,
              element.width,
              element.height,
            ),
            barPaint,
          );
        }
      }

      final picture = pictureRecorder.endRecording();
      final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await _resolveTempDir();
      final targetName = fileName ?? 'ticket_barcode_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(tempDir.path, targetName));
      await file.writeAsBytes(pngBytes, flush: true);

      return file.path;
    } catch (e) {
      debugPrint('Error generating barcode image file: $e');
      return null;
    }
  }

  /// Automatically generates either a 1D Barcode or 2D QR image depending on ticket format
  static Future<String?> generateTicketCodeImageFile(ParkingTicket ticket, {String? fileName}) async {
    try {
      if (ScanScreen.isBarcodeFormat(ticket.format)) {
        final barcode = QrDisplayCard.resolveBarcode(ticket.format, ticket.rawCode);
        return await generateBarcodeImageFile(
          barcode: barcode,
          data: ticket.rawCode,
          fileName: fileName ?? 'ticket_barcode_${ticket.id}.png',
        );
      } else {
        return await generateQrImageFile(
          ticket.rawCode,
          fileName: fileName ?? 'ticket_qr_${ticket.id}.png',
        );
      }
    } catch (e) {
      debugPrint('Error generating ticket code image file: $e');
      return await generateQrImageFile(ticket.rawCode, fileName: fileName);
    }
  }

  /// Standalone QR code PNG generator using QrPainter
  static Future<String?> generateQrImageFile(String data, {String? fileName}) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        gapless: true,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF000000),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF000000),
        ),
      );

      final ui.Image image = await painter.toImage(600);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await _resolveTempDir();
      final targetName = fileName ?? 'ticket_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(tempDir.path, targetName));
      await file.writeAsBytes(pngBytes, flush: true);

      return file.path;
    } catch (e) {
      debugPrint('Error generating QR image file: $e');
      return null;
    }
  }

  /// Share ticket code, barcode/QR image, and physical receipt photo via native system share sheet
  static Future<void> shareTicketViaSystem({
    required ParkingTicket ticket,
    String? qrImagePath,
    Rect? sharePositionOrigin,
  }) async {
    final message = buildShareMessage(ticket);
    final subject = 'Karcis Parkir - ${ticket.plateNumber ?? ticket.vehicleType}';
    final List<XFile> filesToShare = [];

    // Attach barcode / QR image if available
    if (qrImagePath != null && await File(qrImagePath).exists()) {
      filesToShare.add(XFile(qrImagePath, name: 'karcis_${ticket.id}.png', mimeType: 'image/png'));
    }

    // Attach physical ticket photo if user stored one
    if (ticket.hasTicketPhoto && await File(ticket.ticketPhotoPath!).exists()) {
      filesToShare.add(XFile(
        ticket.ticketPhotoPath!,
        name: 'bukti_fisik_${ticket.id}.jpg',
        mimeType: 'image/jpeg',
      ));
    }

    // Attach parking pillar / block photo if user stored one
    if (ticket.parkingPhotoPath != null && await File(ticket.parkingPhotoPath!).exists()) {
      filesToShare.add(XFile(
        ticket.parkingPhotoPath!,
        name: 'tiang_parkir_${ticket.id}.jpg',
        mimeType: 'image/jpeg',
      ));
    }

    if (mockShareHandler != null) {
      await mockShareHandler!(filesToShare, text: message, subject: subject);
      return;
    }

    try {
      if (filesToShare.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: filesToShare,
            text: message,
            subject: subject,
            sharePositionOrigin: sharePositionOrigin,
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: message,
            subject: subject,
            sharePositionOrigin: sharePositionOrigin,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during system share with SharePlus: $e');
      // Fallback to legacy share
      try {
        // ignore: deprecated_member_use
        await Share.share(message, subject: subject, sharePositionOrigin: sharePositionOrigin);
      } catch (_) {}
    }
  }

  /// Launch WhatsApp with pre-filled ticket details
  static Future<bool> shareToWhatsApp(ParkingTicket ticket, {String? qrImagePath}) async {
    final message = buildShareMessage(ticket);
    final deepLink = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
    final webFallback = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}');

    if (mockLaunchUrlHandler != null) {
      return await mockLaunchUrlHandler!(deepLink);
    }

    try {
      if (await canLaunchUrl(deepLink)) {
        return await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webFallback)) {
        return await launchUrl(webFallback, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
    return false;
  }

  /// Launch Telegram with pre-filled ticket details
  static Future<bool> shareToTelegram(ParkingTicket ticket, {String? qrImagePath}) async {
    final message = buildShareMessage(ticket);
    final deepLink = Uri.parse('tg://msg?text=${Uri.encodeComponent(message)}');
    final webFallback = Uri.parse('https://t.me/share/url?url=&text=${Uri.encodeComponent(message)}');

    if (mockLaunchUrlHandler != null) {
      return await mockLaunchUrlHandler!(deepLink);
    }

    try {
      if (await canLaunchUrl(deepLink)) {
        return await launchUrl(deepLink, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webFallback)) {
        return await launchUrl(webFallback, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Telegram: $e');
    }
    return false;
  }

  /// Copy structured ticket details to clipboard
  static Future<void> copyTicketDetails(BuildContext context, ParkingTicket ticket) async {
    final message = buildShareMessage(ticket);
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rincian & kode karcis disalin ke clipboard.'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
