import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parking_history_record.dart';
import '../models/parking_rate_rule.dart';
import '../providers/parking_provider.dart';
import '../services/export_service.dart';
import 'location_templates_screen.dart';

class ExpenseDashboardScreen extends StatefulWidget {
  const ExpenseDashboardScreen({super.key});

  @override
  State<ExpenseDashboardScreen> createState() => _ExpenseDashboardScreenState();
}

class _ExpenseDashboardScreenState extends State<ExpenseDashboardScreen> {
  late DateTime _selectedMonth;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  String _formatMonthYear(DateTime dt) {
    try {
      return DateFormat('MMMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return DateFormat('MMMM yyyy').format(dt);
    }
  }

  Future<void> _exportPdf(List<ParkingHistoryRecord> records) async {
    try {
      final exportService = ExportService();
      final monthName = _formatMonthYear(_selectedMonth);
      final pdfBytes = await exportService.generateMonthlyPdf(
        records,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      );

      final fileName = 'Klaim_Parkir_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}.pdf';
      final filePath = await exportService.savePdfToFile(pdfBytes, fileName);

      if (!mounted) return;
      _showExportSuccessDialog(
        title: 'Ekspor PDF Berhasil',
        message: 'Laporan reimbursement $monthName telah berhasil dibuat dan disimpan.',
        filePath: filePath,
        isPdf: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportCsv(List<ParkingHistoryRecord> records) async {
    try {
      final exportService = ExportService();
      final monthName = _formatMonthYear(_selectedMonth);
      final csvString = exportService.generateCsv(records, periodName: monthName);

      final fileName = 'Rekap_Parkir_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}.csv';
      final filePath = await exportService.saveCsvToFile(csvString, fileName);

      if (!mounted) return;
      _showExportSuccessDialog(
        title: 'Ekspor CSV Berhasil',
        message: 'File CSV riwayat parkir $monthName berhasil disimpan.',
        filePath: filePath,
        csvContent: csvString,
        isPdf: false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportSingleTicketPdf(ParkingHistoryRecord record) async {
    try {
      final exportService = ExportService();
      final pdfBytes = await exportService.generateSingleTicketPdf(record);
      final fileName = 'Bukti_Parkir_${record.id.substring(0, record.id.length.clamp(0, 6))}.pdf';
      final filePath = await exportService.savePdfToFile(pdfBytes, fileName);

      if (!mounted) return;
      _showExportSuccessDialog(
        title: 'Bukti Karcis Disimpan',
        message: 'Voucher bukti parkir individual berhasil digenerate.',
        filePath: filePath,
        isPdf: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat bukti PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showExportSuccessDialog({
    required String title,
    required String message,
    required String filePath,
    String? csvContent,
    required bool isPdf,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPdf ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
                color: isPdf ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filePath,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0F172A),
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                    tooltip: 'Salin Lokasi File',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: filePath));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Lokasi file disalin ke clipboard.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (csvContent != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csvContent));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Isi CSV disalin ke clipboard! Siap dipaste ke Excel / WA.'),
                      backgroundColor: Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.content_copy_rounded, size: 16, color: Color(0xFF2563EB)),
                label: const Text(
                  'Salin Data CSV ke Clipboard',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              try {
                await ExportService().shareFile(
                  filePath,
                  text: 'Klaim Reimbursement Operasional Parkir - $title',
                );
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Gagal membagikan file: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Bagikan File', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showEditRateDialog(BuildContext context, ParkingProvider provider) {
    String selectedVehicle = 'Mobil';
    final currentRule = provider.settings.getRateRule(selectedVehicle);

    final firstHourController =
        TextEditingController(text: currentRule.firstHourRate.toString());
    final hourlyController =
        TextEditingController(text: currentRule.hourlyRate.toString());
    final dailyMaxController =
        TextEditingController(text: currentRule.dailyMaxRate.toString());
    final graceController =
        TextEditingController(text: currentRule.gracePeriodMinutes.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calculate_rounded, color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Aturan Tarif Parkir',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sesuaikan tarif parkir untuk estimasi biaya real-time & rekap pengeluaran.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                // Vehicle Type Segmented
                Row(
                  children: ['Mobil', 'Motor', 'Truk', 'Lainnya'].map((v) {
                    final isSel = selectedVehicle == v;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedVehicle = v;
                              final rule = provider.settings.getRateRule(v);
                              firstHourController.text = rule.firstHourRate.toString();
                              hourlyController.text = rule.hourlyRate.toString();
                              dailyMaxController.text = rule.dailyMaxRate.toString();
                              graceController.text = rule.gracePeriodMinutes.toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              v,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildRateField(
                  controller: firstHourController,
                  label: 'Tarif 1 Jam Pertama (Rp)',
                  hint: 'Contoh: 4000',
                  icon: Icons.looks_one_rounded,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 12),
                _buildRateField(
                  controller: hourlyController,
                  label: 'Tarif Tiap Jam Berikutnya (Rp)',
                  hint: 'Contoh: 3000',
                  icon: Icons.update_rounded,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 12),
                _buildRateField(
                  controller: dailyMaxController,
                  label: 'Maksimal Harian / 24 Jam (Rp, 0 jika bebas)',
                  hint: 'Contoh: 40000',
                  icon: Icons.vertical_align_top_rounded,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 12),
                _buildRateField(
                  controller: graceController,
                  label: 'Masa Tenggang Bebas Biaya (Menit)',
                  hint: 'Contoh: 0 atau 15',
                  icon: Icons.hourglass_empty_rounded,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 14),
                // Live preview calculation card
                Builder(
                  builder: (_) {
                    final f = int.tryParse(firstHourController.text.trim()) ?? 4000;
                    final h = int.tryParse(hourlyController.text.trim()) ?? 3000;
                    final d = int.tryParse(dailyMaxController.text.trim()) ?? 40000;
                    final g = int.tryParse(graceController.text.trim()) ?? 0;
                    final previewRule = ParkingRateRule(
                      firstHourRate: f,
                      hourlyRate: h,
                      dailyMaxRate: d,
                      gracePeriodMinutes: g,
                    );
                    final simCost = previewRule.calculateCost(const Duration(hours: 2, minutes: 15));
                    final simCostStr = _currencyFormat.format(simCost);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_rounded, size: 18, color: Color(0xFF15803D)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Simulasi: Durasi: 2 jam 15 mnt • Estimasi: $simCostStr',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final first = int.tryParse(firstHourController.text.trim()) ?? 4000;
                    final hourly = int.tryParse(hourlyController.text.trim()) ?? 3000;
                    final daily = int.tryParse(dailyMaxController.text.trim()) ?? 40000;
                    final grace = int.tryParse(graceController.text.trim()) ?? 0;

                    final updatedRule = ParkingRateRule(
                      firstHourRate: first,
                      hourlyRate: hourly,
                      dailyMaxRate: daily,
                      gracePeriodMinutes: grace,
                    );

                    await provider.updateRateRule(selectedVehicle, updatedRule);
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Aturan tarif $selectedVehicle berhasil disimpan.'),
                          backgroundColor: const Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan Aturan Tarif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.location_on_outlined, size: 16),
                  label: const Text('Atur Tarif Khusus per Lokasi (Mall PTC, dll)'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LocationTemplatesScreen()),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _deleteRecord(ParkingProvider provider, ParkingHistoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Riwayat?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('Hapus pencatatan parkir ${record.plateNumber ?? "ini"} dari riwayat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteHistoryRecord(record.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Rekap Pengeluaran Parkir',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Aturan Tarif Parkir',
            onPressed: () {
              final provider = Provider.of<ParkingProvider>(context, listen: false);
              _showEditRateDialog(context, provider);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<ParkingProvider>(
        builder: (context, provider, child) {
          final records = provider.getMonthlyHistory(_selectedMonth.year, _selectedMonth.month);
          final totalExpense = provider.getMonthlyTotalExpense(_selectedMonth.year, _selectedMonth.month);
          final totalDuration = provider.getMonthlyTotalDuration(_selectedMonth.year, _selectedMonth.month);

          final totalHours = totalDuration.inHours;
          final remMinutes = totalDuration.inMinutes % 60;
          final durationFormatted = totalHours > 0 ? '$totalHours jam $remMinutes mnt' : '$remMinutes mnt';

          return RefreshIndicator(
            onRefresh: () => provider.loadTickets(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // Month Selector Bar
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 28),
                          onPressed: _previousMonth,
                          tooltip: 'Bulan Sebelumnya',
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              _formatMonthYear(_selectedMonth),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 28),
                          onPressed: _nextMonth,
                          tooltip: 'Bulan Berikutnya',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Dashboard KPI Cards (Total Biaya & Total Durasi)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669).withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Total Pengeluaran',
                                  style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _currencyFormat.format(totalExpense),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bulan ini • ${records.length} karcis',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.timer_rounded, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Total Durasi',
                                  style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              durationFormatted,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Akumulasi waktu parkir',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Export Buttons Section
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: records.isNotEmpty ? () => _exportPdf(records) : null,
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text(
                          'Ekspor PDF',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: records.isNotEmpty ? () => _exportCsv(records) : null,
                        icon: const Icon(Icons.table_chart_rounded, size: 18),
                        label: const Text(
                          'Ekspor CSV',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Transactions Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Riwayat Karcis Selesai (${records.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    InkWell(
                      onTap: () => _showEditRateDialog(context, provider),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 14, color: Color(0xFF2563EB)),
                            SizedBox(width: 4),
                            Text(
                              'Aturan Tarif',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // List of Records
                if (records.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum Ada Pengeluaran di Bulan Ini',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Karcis yang diselesaikan (Done) akan otomatis tercatat di sini untuk keperluan reimbursement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                else
                  ...records.map((r) {
                    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(r.entryTime);
                    final exitStr = DateFormat('HH:mm').format(r.exitTime);

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    r.vehicleType.toLowerCase() == 'motor'
                                        ? Icons.two_wheeler_rounded
                                        : Icons.directions_car_rounded,
                                    size: 20,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.plateNumber?.isNotEmpty == true
                                            ? r.plateNumber!
                                            : 'Karcis #${r.ticketId.substring(0, r.ticketId.length.clamp(0, 8))}',
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${r.vehicleType} • ${r.locationName ?? "Lokasi Umum"}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(r.cost),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$dateStr - $exitStr (${r.durationFormatted})',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.receipt_rounded, size: 18, color: Color(0xFF2563EB)),
                                      tooltip: 'Ekspor Voucher PDF',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _exportSingleTicketPdf(r),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                                      tooltip: 'Hapus Catatan',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteRecord(provider, r),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
