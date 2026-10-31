import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../screens/scan_screen.dart';

class QrDisplayCard extends StatefulWidget {
  final String data;
  final String format;
  final double size;
  final String? subtitle;

  const QrDisplayCard({
    super.key,
    required this.data,
    this.format = 'QR_CODE',
    this.size = 240,
    this.subtitle,
  });

  static Barcode resolveBarcode(String format, String data) {
    final f = format.toLowerCase().replaceAll('_', '');
    try {
      if (f.contains('code128')) {
        final b = Barcode.code128();
        if (b.isValid(data)) return b;
      } else if (f.contains('code39')) {
        final b = Barcode.code39();
        if (b.isValid(data)) return b;
      } else if (f.contains('code93')) {
        final b = Barcode.code93();
        if (b.isValid(data)) return b;
      } else if (f.contains('ean13')) {
        final b = Barcode.ean13();
        if (b.isValid(data)) return b;
      } else if (f.contains('ean8')) {
        final b = Barcode.ean8();
        if (b.isValid(data)) return b;
      } else if (f.contains('upca')) {
        final b = Barcode.upcA();
        if (b.isValid(data)) return b;
      } else if (f.contains('upce')) {
        final b = Barcode.upcE();
        if (b.isValid(data)) return b;
      } else if (f.contains('codabar')) {
        final b = Barcode.codabar();
        if (b.isValid(data)) return b;
      } else if (f.contains('itf')) {
        final b = Barcode.itf();
        if (b.isValid(data)) return b;
      } else if (f.contains('pdf417')) {
        final b = Barcode.pdf417();
        if (b.isValid(data)) return b;
      }
    } catch (_) {}

    final c128 = Barcode.code128();
    if (c128.isValid(data)) return c128;
    return Barcode.code128();
  }

  @override
  State<QrDisplayCard> createState() => _QrDisplayCardState();
}

class _QrDisplayCardState extends State<QrDisplayCard> {
  late bool _showBarcode;

  @override
  void initState() {
    super.initState();
    _showBarcode = ScanScreen.isBarcodeFormat(widget.format);
  }

  @override
  void didUpdateWidget(covariant QrDisplayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.format != widget.format) {
      _showBarcode = ScanScreen.isBarcodeFormat(widget.format);
    }
  }

  void _openFullScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final qrSize = (screenWidth * 0.72).clamp(240.0, 320.0);
        final barcodeWidth = (screenWidth * 0.88).clamp(260.0, 340.0);

        return Dialog.fullscreen(
          backgroundColor: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 12),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 24, color: Color(0xFF0F172A)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _showBarcode
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      BarcodeWidget(
                                        barcode: QrDisplayCard.resolveBarcode(widget.format, widget.data),
                                        data: widget.data,
                                        width: barcodeWidth,
                                        height: 140,
                                        drawText: false,
                                        errorBuilder: (context, error) => Center(
                                          child: Text(
                                            'Format Barcode Tidak Sesuai Data: $error',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.red, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : QrImageView(
                                    data: widget.data,
                                    version: QrVersions.auto,
                                    size: qrSize,
                                    gapless: true,
                                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                Text(
                                  widget.data,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _showBarcode
                                      ? 'Arahkan barcode garis ke pemindai loket keluar'
                                      : 'Arahkan QR code ke pemindai loket keluar',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Tutup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBarcode = ScanScreen.isBarcodeFormat(widget.format);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // White background padding ensures highest scanner readability
          InkWell(
            onTap: () => _openFullScreen(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_showBarcode)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: BarcodeWidget(
                        barcode: QrDisplayCard.resolveBarcode(widget.format, widget.data),
                        data: widget.data,
                        width: (widget.size * 1.25).clamp(240.0, 300.0),
                        height: 105,
                        drawText: false,
                        errorBuilder: (context, error) => Center(
                          child: Text(
                            'Gagal merender barcode: $error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),
                    )
                  else
                    QrImageView(
                      data: widget.data,
                      version: QrVersions.auto,
                      size: widget.size,
                      gapless: true,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Optional toggle between Barcode Garis 1D and QR
          if (isBarcode) ...[
            InkWell(
              onTap: () {
                setState(() {
                  _showBarcode = !_showBarcode;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showBarcode ? Icons.qr_code_2_rounded : Icons.view_week_rounded,
                      size: 14,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showBarcode ? 'Beralih ke QR Code' : 'Beralih ke Barcode Garis 1D',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.data));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kode karcis disalin ke clipboard.'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.data,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.copy_rounded, size: 16, color: theme.primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
