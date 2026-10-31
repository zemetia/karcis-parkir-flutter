import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/parking_history_record.dart';

class ExportService {
  static final ExportService _instance = ExportService._();
  factory ExportService() => _instance;
  ExportService._();

  static Future<void> Function(List<XFile> files, {String? text})? mockShareHandler;
  String? customDocsPath;

  /// Share file via system share sheet (WhatsApp, Email, Telegram, etc.)
  Future<void> shareFile(String filePath, {String? text}) async {
    if (mockShareHandler != null) {
      await mockShareHandler!([XFile(filePath)], text: text);
      return;
    }
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(filePath)], text: text);
  }

  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  /// Generates RFC-compliant CSV string for parking history reimbursement.
  String generateCsv(List<ParkingHistoryRecord> records, {String? periodName}) {
    final buffer = StringBuffer();

    // Headers
    buffer.writeln(
      'No,ID Karcis,Plat Nomor,Jenis Kendaraan,Lokasi,Waktu Masuk,Waktu Keluar,Durasi Menit,Durasi Format,Biaya (Rp),Catatan',
    );

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final no = i + 1;
      final id = _escapeCsv(r.id.substring(0, r.id.length.clamp(0, 8)));
      final plate = _escapeCsv(r.plateNumber ?? '-');
      final vehicle = _escapeCsv(r.vehicleType);
      final location = _escapeCsv(r.locationName ?? '-');
      final entry = _escapeCsv(dateFormat.format(r.entryTime));
      final exit = _escapeCsv(dateFormat.format(r.exitTime));
      final durMinutes = r.durationMinutes;
      final durFormatted = _escapeCsv(r.durationFormatted);
      final cost = r.cost;
      final notes = _escapeCsv(r.notes ?? '');

      buffer.writeln(
        '$no,$id,$plate,$vehicle,$location,$entry,$exit,$durMinutes,$durFormatted,$cost,$notes',
      );
    }

    return buffer.toString();
  }

  /// Escapes CSV field if it contains commas, double quotes, or newlines.
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  /// Saves CSV string to file and returns absolute path.
  Future<String> saveCsvToFile(String csvData, String fileName) async {
    final String dirPath;
    if (customDocsPath != null) {
      dirPath = customDocsPath!;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dirPath = dir.path;
    }
    final file = File(p.join(dirPath, fileName));
    await file.writeAsString(csvData);
    return file.path;
  }

  /// Generates a publication-grade PDF report for monthly parking reimbursement.
  Future<Uint8List> generateMonthlyPdf(
    List<ParkingHistoryRecord> records, {
    required int year,
    required int month,
    String? driverName,
    String? companyName,
  }) async {
    final pdf = pw.Document();

    String monthName;
    try {
      monthName = DateFormat('MMMM yyyy', 'id_ID').format(DateTime(year, month));
    } catch (_) {
      monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));
    }

    String printDate;
    try {
      printDate = DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(DateTime.now());
    } catch (_) {
      printDate = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());
    }

    final totalCost = records.fold<int>(0, (sum, r) => sum + r.cost);
    final totalMinutes = records.fold<int>(0, (sum, r) => sum + r.durationMinutes);
    final totalHours = totalMinutes ~/ 60;
    final remMins = totalMinutes % 60;
    final totalDurationStr = totalHours > 0 ? '$totalHours jam $remMins mnt' : '$remMins mnt';
    final avgCost = records.isNotEmpty ? (totalCost / records.length).round() : 0;

    final entryDateFormat = DateFormat('dd/MM HH:mm');
    final exitDateFormat = DateFormat('dd/MM HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LAPORAN KLAIM REIMBURSEMENT PARKIR',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Aplikasi Karcis Parkir • Rekapitulasi Operasional Driver & Kantor',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (companyName != null && companyName.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Perusahaan / Divisi: $companyName',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.blue200),
                      ),
                      child: pw.Text(
                        'Periode: $monthName',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Dicetak: $printDate',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1.2, color: PdfColors.grey300),
            pw.SizedBox(height: 12),

            // Summary KPI Cards
            pw.Row(
              children: [
                _buildPdfKpiCard(
                  title: 'TOTAL PENGELUARAN',
                  value: _currencyFormat.format(totalCost),
                  bgColor: PdfColors.green50,
                  borderColor: PdfColors.green200,
                  textColor: PdfColors.green900,
                ),
                pw.SizedBox(width: 10),
                _buildPdfKpiCard(
                  title: 'TOTAL DURASI',
                  value: totalDurationStr,
                  bgColor: PdfColors.blue50,
                  borderColor: PdfColors.blue200,
                  textColor: PdfColors.blue900,
                ),
                pw.SizedBox(width: 10),
                _buildPdfKpiCard(
                  title: 'TOTAL TRANSAKSI',
                  value: '${records.length} Karcis',
                  bgColor: PdfColors.grey100,
                  borderColor: PdfColors.grey300,
                  textColor: PdfColors.grey900,
                ),
                pw.SizedBox(width: 10),
                _buildPdfKpiCard(
                  title: 'RATA-RATA / PARKIR',
                  value: _currencyFormat.format(avgCost),
                  bgColor: PdfColors.purple50,
                  borderColor: PdfColors.purple200,
                  textColor: PdfColors.purple900,
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Table Header Title
            pw.Text(
              'Rincian Bukti & Transaksi Parkir',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.SizedBox(height: 8),

            // Table
            records.isEmpty
                ? pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'Tidak ada riwayat parkir untuk periode ini.',
                      style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
                    ),
                  )
                : pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey300,
                      width: 0.6,
                    ),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(22), // No
                      1: const pw.FlexColumnWidth(2.0), // Waktu Masuk
                      2: const pw.FlexColumnWidth(2.0), // Waktu Keluar
                      3: const pw.FlexColumnWidth(2.0), // Plat
                      4: const pw.FlexColumnWidth(1.6), // Jenis
                      5: const pw.FlexColumnWidth(2.8), // Lokasi
                      6: const pw.FlexColumnWidth(2.0), // Durasi
                      7: const pw.FlexColumnWidth(2.2), // Biaya
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildPdfTableCell('No', isHeader: true, align: pw.TextAlign.center),
                          _buildPdfTableCell('Masuk', isHeader: true),
                          _buildPdfTableCell('Keluar', isHeader: true),
                          _buildPdfTableCell('Plat No', isHeader: true),
                          _buildPdfTableCell('Kendaraan', isHeader: true),
                          _buildPdfTableCell('Lokasi', isHeader: true),
                          _buildPdfTableCell('Durasi', isHeader: true),
                          _buildPdfTableCell('Biaya (Rp)', isHeader: true, align: pw.TextAlign.right),
                        ],
                      ),
                      // Data Rows
                      ...records.asMap().entries.map((entry) {
                        final index = entry.key;
                        final r = entry.value;
                        final isEven = index % 2 == 0;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: isEven ? PdfColors.white : PdfColors.grey50,
                          ),
                          children: [
                            _buildPdfTableCell('${index + 1}', align: pw.TextAlign.center),
                            _buildPdfTableCell(entryDateFormat.format(r.entryTime)),
                            _buildPdfTableCell(exitDateFormat.format(r.exitTime)),
                            _buildPdfTableCell(r.plateNumber ?? '-'),
                            _buildPdfTableCell(r.vehicleType),
                            _buildPdfTableCell(r.locationName ?? '-'),
                            _buildPdfTableCell(r.durationFormatted),
                            _buildPdfTableCell(
                              _currencyFormat.format(r.cost),
                              align: pw.TextAlign.right,
                              isBold: true,
                            ),
                          ],
                        );
                      }),
                      // Total Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          _buildPdfTableCell('', align: pw.TextAlign.center),
                          _buildPdfTableCell('TOTAL', isBold: true),
                          _buildPdfTableCell(''),
                          _buildPdfTableCell(''),
                          _buildPdfTableCell(''),
                          _buildPdfTableCell(''),
                          _buildPdfTableCell(totalDurationStr, isBold: true),
                          _buildPdfTableCell(
                            _currencyFormat.format(totalCost),
                            align: pw.TextAlign.right,
                            isBold: true,
                          ),
                        ],
                      ),
                    ],
                  ),

            pw.SizedBox(height: 28),

            // Approval Signatures Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Diajukan Oleh (Driver / Karyawan):',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 38),
                      pw.Text(
                        '( ${driverName != null && driverName.isNotEmpty ? driverName : "........................................"} )',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Tanggal: ........................................',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Disetujui Oleh (Finance / Supervisor):',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 38),
                      pw.Text(
                        '( ........................................ )',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Tanggal: ........................................',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Dokumen ini dicetak otomatis oleh Aplikasi Karcis Parkir sebagai bukti sah reimbursement operasional.',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  /// Generates a single ticket receipt PDF voucher.
  Future<Uint8List> generateSingleTicketPdf(ParkingHistoryRecord record) async {
    final pdf = pw.Document();
    String formattedEntry;
    String formattedExit;
    try {
      final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'id_ID');
      formattedEntry = dateFormat.format(record.entryTime);
      formattedExit = dateFormat.format(record.exitTime);
    } catch (_) {
      final dateFormat = DateFormat('dd MMMM yyyy HH:mm');
      formattedEntry = dateFormat.format(record.entryTime);
      formattedExit = dateFormat.format(record.exitTime);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'BUKTI PARKIR ELEKTRONIK (RECEIPT)',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Klaim Reimbursement Operasional Parkir',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              _buildReceiptRow('Nomor Karcis / ID', record.id.substring(0, record.id.length.clamp(0, 8)).toUpperCase()),
              _buildReceiptRow('Plat Nomor', record.plateNumber ?? '-'),
              _buildReceiptRow('Jenis Kendaraan', record.vehicleType),
              _buildReceiptRow('Lokasi Parkir', record.locationName ?? '-'),
              _buildReceiptRow('Waktu Masuk', formattedEntry),
              _buildReceiptRow('Waktu Keluar', formattedExit),
              _buildReceiptRow('Total Durasi', record.durationFormatted),
              if (record.notes != null && record.notes!.isNotEmpty)
                _buildReceiptRow('Catatan', record.notes!),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.green300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL BIAYA PARKIR:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                    ),
                    pw.Text(
                      _currencyFormat.format(record.cost),
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Diajukan Oleh:', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 30),
                      pw.Text('( ........................ )', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Disetujui Oleh:', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 30),
                      pw.Text('( ........................ )', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
        ],
      ),
    );
  }

  /// Saves PDF byte array to file and returns absolute path.
  Future<String> savePdfToFile(Uint8List pdfBytes, String fileName) async {
    final String dirPath;
    if (customDocsPath != null) {
      dirPath = customDocsPath!;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      dirPath = dir.path;
    }
    final file = File(p.join(dirPath, fileName));
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  static pw.Widget _buildPdfKpiCard({
    required String title,
    required String value,
    required PdfColor bgColor,
    required PdfColor borderColor,
    required PdfColor textColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: borderColor, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 6.5,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7.5,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey900 : PdfColors.grey800,
        ),
      ),
    );
  }
}
