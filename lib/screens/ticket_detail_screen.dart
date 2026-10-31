import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parking_ticket.dart';
import '../providers/parking_provider.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import '../services/ticket_share_service.dart';
import '../widgets/edit_entry_time_sheet.dart';
import '../widgets/edit_parking_location_sheet.dart';
import '../widgets/parking_photo_viewer.dart';
import '../services/notification_service.dart';
import '../widgets/qr_display.dart';
import 'scan_screen.dart';

class TicketDetailScreen extends StatefulWidget {
  final ParkingTicket ticket;

  const TicketDetailScreen({
    super.key,
    required this.ticket,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final GlobalKey _qrRepaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    NotificationService.currentViewingTicketId = widget.ticket.id;
  }

  @override
  void dispose() {
    if (NotificationService.currentViewingTicketId == widget.ticket.id) {
      NotificationService.currentViewingTicketId = null;
    }
    super.dispose();
  }

  Future<void> _handleDone(BuildContext context) async {
    final provider = Provider.of<ParkingProvider>(context, listen: false);
    final currentTicket = provider.tickets.firstWhere(
      (t) => t.id == widget.ticket.id,
      orElse: () => widget.ticket,
    );
    final estimatedCost = provider.estimateCostForTicket(currentTicket);
    final costFormatted =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(estimatedCost);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 24),
            SizedBox(width: 10),
            Text('Selesaikan Parkir?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(
          'Karcis ini akan diselesaikan (Estimasi Tarif: $costFormatted) dan dipindahkan ke arsip riwayat.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Selesai (Done)', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<ParkingProvider>(context, listen: false);
      await provider.completeTicket(widget.ticket.id, customCost: estimatedCost);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karcis berhasil diselesaikan.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, ParkingTicket currentTicket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.restore_rounded, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 10),
            Text('Pulihkan Karcis?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Karcis ini akan dipulihkan kembali ke daftar karcis aktif.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Pulihkan', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<ParkingProvider>(context, listen: false);
      await provider.restoreTicket(currentTicket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karcis berhasil dipulihkan ke daftar aktif.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handlePermanentDelete(BuildContext context, ParkingTicket currentTicket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text('Hapus Permanen?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Karcis ini akan dihapus selamanya dari penyimpanan. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus Permanen', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<ParkingProvider>(context, listen: false);
      await provider.deleteTicketPermanently(currentTicket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karcis telah dihapus secara permanen.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _showAddReminderToTicketDialog(BuildContext context, ParkingTicket currentTicket) {
    final customController = TextEditingController();
    final presets = [1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 10.0, 12.0, 18.0, 24.0];
    double? selectedPreset;

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
                    const Icon(Icons.add_alarm_rounded, color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Tambah Jam Pengingat',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilihan Cepat (Jam)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((hours) {
                    final label = hours == hours.roundToDouble()
                        ? '${hours.toInt()} Jam'
                        : '${hours.toStringAsFixed(1)} Jam';
                    final isAlreadyAdded = currentTicket.reminderHours.contains(hours);
                    final isSelected = selectedPreset == hours;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: isAlreadyAdded ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : (isAlreadyAdded ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                      ),
                      onSelected: isAlreadyAdded ? null : (selected) {
                        setModalState(() {
                          selectedPreset = selected ? hours : null;
                          customController.clear();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: customController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Atau masukkan jam khusus (misal: 5)',
                    suffixText: 'Jam',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    double? hourToAdd = selectedPreset ?? double.tryParse(customController.text.trim());
                    if (hourToAdd == null || hourToAdd <= 0) return;
                    final provider = Provider.of<ParkingProvider>(context, listen: false);
                    await provider.addReminderToTicket(currentTicket.id, hourToAdd);
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pengingat ${hourToAdd.toStringAsFixed(0)} jam berhasil ditambahkan.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan Pengingat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParkingProvider>(
      builder: (context, provider, child) {
        final currentTicket = provider.tickets.firstWhere(
          (t) => t.id == widget.ticket.id,
          orElse: () => provider.historyTickets.firstWhere(
            (t) => t.id == widget.ticket.id,
            orElse: () => widget.ticket,
          ),
        );
        final theme = Theme.of(context);
        final duration = currentTicket.durationParked;
        final passedLimits = currentTicket.reminderHours
            .where((h) => duration.inMinutes >= (h * 60).round())
            .toList();
        final isFirstLimitPassed = passedLimits.isNotEmpty;
        final double highestPassed = isFirstLimitPassed ? passedLimits.last : 0.0;
        final isSecondLimitPassed = isFirstLimitPassed && highestPassed >= 24;

        String formattedDate;
        try {
          formattedDate = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(currentTicket.entryTime);
        } catch (_) {
          formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(currentTicket.entryTime);
        }

        final estimatedCost = provider.estimateCostForTicket(currentTicket);
        final costFormatted =
            NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(estimatedCost);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Pindai Karcis Keluar'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Bagikan Karcis (WhatsApp / Telegram)',
                onPressed: () => _showShareBottomSheet(context, currentTicket),
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar_outlined),
                tooltip: 'Ubah Jam Masuk',
                onPressed: () => EditEntryTimeSheet.show(context, currentTicket),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (currentTicket.isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Karcis ini telah diselesaikan (Arsip Riwayat)',
                              style: TextStyle(
                                color: Color(0xFF065F46),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Recreated QR / Barcode card with tap to expand & RepaintBoundary for high-res sharing
                  Center(
                    child: RepaintBoundary(
                      key: _qrRepaintBoundaryKey,
                      child: QrDisplayCard(
                        data: currentTicket.rawCode,
                        format: currentTicket.format,
                        size: 230,
                        subtitle: ScanScreen.isBarcodeFormat(currentTicket.format)
                            ? 'Format Asli: ${ScanScreen.formatDisplayName(currentTicket.format)}'
                            : null,
                      ),
                    ),
                  ),

                  // Quick share forward button below QR code
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.2),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () => _showShareBottomSheet(context, currentTicket),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text(
                          'Bagikan Karcis (WhatsApp / Telegram)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Ticket Details Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFirstLimitPassed ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                        width: isFirstLimitPassed ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: _getVehicleIcon(currentTicket.vehicleType),
                          label: 'Jenis Kendaraan',
                          value: currentTicket.vehicleType,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        ),
                        _buildInfoRow(
                          icon: ScanScreen.isBarcodeFormat(currentTicket.format)
                              ? Icons.view_week_rounded
                              : (currentTicket.format.toLowerCase().contains('manual')
                                  ? Icons.keyboard_outlined
                                  : Icons.qr_code_2_rounded),
                          label: 'Format Karcis',
                          value: ScanScreen.formatDisplayName(currentTicket.format),
                        ),
                        if (currentTicket.plateNumber != null && currentTicket.plateNumber!.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Nomor Plat',
                            value: currentTicket.plateNumber!,
                            isBold: true,
                          ),
                        ],
                        if (currentTicket.locationName != null && currentTicket.locationName!.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Lokasi Parkir',
                            value: currentTicket.locationName!,
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            const Text(
                              'Waktu Masuk',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                formattedDate,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => EditEntryTimeSheet.show(context, currentTicket),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFDBEAFE)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_outlined, size: 12, color: Color(0xFF2563EB)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Ubah',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        ),
                        _buildInfoRow(
                          icon: Icons.timer_outlined,
                          label: 'Durasi Parkir Saat Ini',
                          value: currentTicket.durationFormatted,
                          highlightColor: isFirstLimitPassed
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A),
                          isBold: true,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        ),
                        _buildInfoRow(
                          icon: Icons.payments_outlined,
                          label: 'Estimasi Biaya Parkir',
                          value: costFormatted,
                          highlightColor: const Color(0xFF15803D),
                          isBold: true,
                        ),
                        // Rate rule breakdown info
                        Builder(
                          builder: (_) {
                            final activeRule = provider.getRateRuleForTicket(currentTicket);
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF15803D)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      currentTicket.locationName != null && currentTicket.locationName!.isNotEmpty
                                          ? 'Aturan ${currentTicket.locationName}: ${activeRule.summaryDescription}'
                                          : 'Aturan Umum ${currentTicket.vehicleType}: ${activeRule.summaryDescription}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (isFirstLimitPassed) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isSecondLimitPassed
                                        ? 'Tarif menginap berlaku (>${highestPassed.toStringAsFixed(0)} jam)'
                                        : 'Melebihi batas waktu (>${highestPassed.toStringAsFixed(0)} jam)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.alarm_rounded, size: 20, color: Color(0xFF64748B)),
                                SizedBox(width: 10),
                                Text(
                                  'Jadwal Pengingat',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => _showAddReminderToTicketDialog(context, currentTicket),
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
                                    SizedBox(width: 2),
                                    Text(
                                      'Tambah Jam',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: currentTicket.reminderHours.map((h) {
                            final isPassed = duration.inMinutes >= (h * 60).round();
                            final hourText = h == h.roundToDouble()
                                ? '${h.toInt()}j'
                                : '${h.toStringAsFixed(1)}j';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPassed ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isPassed ? const Color(0xFFFECACA) : const Color(0xFFDBEAFE),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPassed ? Icons.check_circle_rounded : Icons.alarm,
                                    size: 12,
                                    color: isPassed ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hourText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isPassed ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        if (currentTicket.notes != null && currentTicket.notes!.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          _buildInfoRow(
                            icon: Icons.note_outlined,
                            label: 'Catatan',
                            value: currentTicket.notes!,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Find My Vehicle Card
                  _buildFindMyVehicleCard(context, currentTicket),

                  const SizedBox(height: 16),

                  // Bukti Fisik Karcis Kertas Card (Pencegahan Denda Tiket Hilang)
                  _buildPhysicalTicketPhotoCard(context, currentTicket),

                  const SizedBox(height: 24),

                  // Action buttons: Done/Kembali for active, or Pulihkan/Hapus for completed
                  if (currentTicket.isCompleted)
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                            ),
                            onPressed: () => _handlePermanentDelete(context, currentTicket),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_forever_rounded, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Hapus Permanen',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => _handleRestore(context, currentTicket),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restore_rounded, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Pulihkan Karcis',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back, size: 18, color: Color(0xFF0F172A)),
                                SizedBox(width: 6),
                                Text(
                                  'Kembali',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => _handleDone(context),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Done (Keluar)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'motor':
        return Icons.two_wheeler_rounded;
      case 'truk':
        return Icons.local_shipping_rounded;
      case 'mobil':
        return Icons.directions_car_rounded;
      default:
        return Icons.commute_rounded;
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? highlightColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: highlightColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFindMyVehicleCard(BuildContext context, ParkingTicket currentTicket) {
    final hasFloorOrBlock = (currentTicket.parkingFloor != null && currentTicket.parkingFloor!.isNotEmpty) ||
        (currentTicket.parkingBlock != null && currentTicket.parkingBlock!.isNotEmpty);
    final hasPhoto = currentTicket.parkingPhotoPath != null && currentTicket.parkingPhotoPath!.isNotEmpty;
    final hasCoordinates = currentTicket.latitude != null && currentTicket.longitude != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find My Vehicle',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Titik Parkir & Letak Kendaraan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => EditParkingLocationSheet.show(context, currentTicket),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 13, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Ubah Lokasi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Lantai & Blok Parkir
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasFloorOrBlock ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasFloorOrBlock ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.layers_rounded,
                  size: 20,
                  color: hasFloorOrBlock ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lantai & Tiang / Blok',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasFloorOrBlock
                            ? currentTicket.parkingLocationSummary ?? '-'
                            : 'Belum dicatat (Contoh: B2 - Tiang F12)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: hasFloorOrBlock ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!hasFloorOrBlock)
                  InkWell(
                    onTap: () => EditParkingLocationSheet.show(context, currentTicket),
                    child: const Text(
                      '+ Catat',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Foto Tiang / Blok Parkir
          if (hasPhoto) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => ParkingPhotoViewer.show(
                      context,
                      imagePath: currentTicket.parkingPhotoPath!,
                      title: 'Foto Tiang / Blok Parkir',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.file(
                            File(currentTicket.parkingPhotoPath!),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 64,
                              height: 64,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.broken_image, color: Color(0xFF64748B)),
                            ),
                          ),
                          Container(
                            width: 64,
                            height: 64,
                            color: Colors.black26,
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto Tiang Tersimpan',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Ketuk foto untuk memperbesar',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => ParkingPhotoViewer.show(
                                context,
                                imagePath: currentTicket.parkingPhotoPath!,
                                title: 'Foto Tiang / Blok Parkir',
                              ),
                              child: const Text(
                                'Lihat Full',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            InkWell(
                              onTap: () => _handleQuickPhoto(context, currentTicket),
                              child: const Text(
                                'Ganti Foto',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            InkWell(
                              onTap: () async {
                                final provider = Provider.of<ParkingProvider>(context, listen: false);
                                await provider.updateParkingLocation(currentTicket.id, clearParkingPhoto: true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Foto tiang parkir berhasil dihapus.'),
                                      backgroundColor: Color(0xFF059669),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Hapus Foto',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt_rounded, size: 17),
                    label: const Text('Foto Tiang / Blok Parkir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _handleQuickPhoto(context, currentTicket, preferredSource: ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 17),
                    label: const Text('Pilih Galeri'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: const Color(0xFF334155),
                    ),
                    onPressed: () => _handleQuickPhoto(context, currentTicket, preferredSource: ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // 3. Titik Koordinat GPS & Buka di Google Maps
          if (hasCoordinates) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Koordinat: ${currentTicket.latitude!.toStringAsFixed(6)}, ${currentTicket.longitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          final provider = Provider.of<ParkingProvider>(context, listen: false);
                          await provider.updateParkingLocation(currentTicket.id, clearCoordinates: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Titik koordinat GPS berhasil dihapus.'),
                                backgroundColor: Color(0xFF059669),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            'Hapus',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text('Buka di Google Maps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () => _handleOpenMap(
                            context,
                            currentTicket.latitude!,
                            currentTicket.longitude!,
                            currentTicket.plateNumber != null
                                ? 'Kendaraan ${currentTicket.plateNumber}'
                                : 'Kendaraan Parkir',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final url = currentTicket.googleMapsUrl ??
                              'https://www.google.com/maps/search/?api=1&query=${currentTicket.latitude},${currentTicket.longitude}';
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tautan Google Maps disalin ke clipboard.'),
                              backgroundColor: Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF065F46)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                          side: const BorderSide(color: Color(0xFF86EFAC)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _handleQuickGps(context, currentTicket),
                        child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Simpan Titik GPS Parkir (Drop Pin)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: const Color(0xFF059669),
              ),
              onPressed: () => _handleQuickGps(context, currentTicket),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleOpenMap(BuildContext context, double lat, double lng, String label) async {
    final success = await LocationService.openGoogleMaps(
      latitude: lat,
      longitude: lng,
      label: label,
    );
    if (!success && context.mounted) {
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka Google Maps. Tautan telah disalin ke clipboard.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleQuickPhoto(BuildContext context, ParkingTicket currentTicket, {ImageSource? preferredSource}) async {
    final path = await PhotoService.pickPillarPhoto(context, preferredSource: preferredSource);
    if (path != null && context.mounted) {
      final provider = Provider.of<ParkingProvider>(context, listen: false);
      await provider.updateParkingLocation(currentTicket.id, parkingPhotoPath: path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto tiang parkir berhasil disimpan.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleQuickGps(BuildContext context, ParkingTicket currentTicket) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mengambil titik lokasi GPS...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final result = await LocationService.getCurrentCoordinates();
    if (context.mounted) {
      if (result.isSuccess && result.latitude != null && result.longitude != null) {
        final provider = Provider.of<ParkingProvider>(context, listen: false);
        await provider.updateParkingLocation(
          currentTicket.id,
          latitude: result.latitude,
          longitude: result.longitude,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Titik koordinat GPS berhasil disimpan.'),
              backgroundColor: Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Gagal mengambil titik GPS.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            action: result.isPermissionDeniedForever
                ? SnackBarAction(
                    label: 'Pengaturan',
                    textColor: Colors.white,
                    onPressed: () => LocationService.openAppSettings(),
                  )
                : null,
          ),
        );
      }
    }
  }

  /// Physical paper ticket photo card (Pencegahan Denda Tiket Hilang)
  Widget _buildPhysicalTicketPhotoCard(BuildContext context, ParkingTicket currentTicket) {
    final hasPhoto = currentTicket.hasTicketPhoto;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPhoto ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          width: hasPhoto ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bukti Fisik Karcis Kertas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Lampiran foto struk karcis fisik',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPhoto)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text(
                        'Tersimpan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Informative banner on avoiding lost ticket fine
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pencegahan Denda: Jika tiket kertas hilang/tercecer, foto struk fisik sering kali diterima oleh pos sekuriti/loket untuk verifikasi nomor tiket sehingga terhindar dari denda tiket hilang (Rp 25.000 - Rp 50.000).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (hasPhoto) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => ParkingPhotoViewer.show(
                      context,
                      imagePath: currentTicket.ticketPhotoPath!,
                      title: 'Foto Struk Fisik Karcis',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.file(
                            File(currentTicket.ticketPhotoPath!),
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 68,
                              height: 68,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.broken_image, color: Color(0xFF64748B)),
                            ),
                          ),
                          Container(
                            width: 68,
                            height: 68,
                            color: Colors.black26,
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto Karcis Fisik Terlampir',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Siap diverifikasi petugas jika karcis tercecer',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => ParkingPhotoViewer.show(
                                context,
                                imagePath: currentTicket.ticketPhotoPath!,
                                title: 'Foto Struk Fisik Karcis',
                              ),
                              child: const Text(
                                'Lihat Full',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            InkWell(
                              onTap: () => _handlePickTicketPhoto(context, currentTicket),
                              child: const Text(
                                'Ganti Foto',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            InkWell(
                              onTap: () => _handleDeleteTicketPhoto(context, currentTicket),
                              child: const Text(
                                'Hapus',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Foto Karcis Kertas (Cegah Denda)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => _handlePickTicketPhoto(context, currentTicket),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handlePickTicketPhoto(BuildContext context, ParkingTicket currentTicket) async {
    final path = await PhotoService.pickTicketPhoto(context);
    if (path != null && context.mounted) {
      final provider = Provider.of<ParkingProvider>(context, listen: false);
      await provider.updateTicketPhoto(currentTicket.id, ticketPhotoPath: path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto bukti fisik karcis berhasil disimpan.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteTicketPhoto(BuildContext context, ParkingTicket currentTicket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Foto Karcis?'),
        content: const Text('Foto bukti fisik karcis kertas ini akan dihapus dari lampiran.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<ParkingProvider>(context, listen: false);
      await provider.updateTicketPhoto(currentTicket.id, clearTicketPhoto: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto bukti fisik karcis dihapus.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Show forward/share modal bottom sheet (WhatsApp, Telegram, System Share, Copy)
  void _showShareBottomSheet(BuildContext context, ParkingTicket currentTicket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bagikan Karcis Parkir',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Kirim barcode/QR & detail masuk ke teman/supir/keluarga',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Ticket summary badge
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    ScanScreen.isBarcodeFormat(currentTicket.format)
                        ? Icons.view_week_rounded
                        : Icons.qr_code_2_rounded,
                    color: const Color(0xFF2563EB),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentTicket.rawCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currentTicket.vehicleType}${currentTicket.plateNumber != null ? " • ${currentTicket.plateNumber}" : ""}${currentTicket.locationName != null ? " • ${currentTicket.locationName}" : ""}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Share via System (All Apps / Image + Text)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share_rounded, color: Color(0xFF2563EB)),
              ),
              title: const Text('Bagikan Lengkap (Gambar Barcode/QR + Rincian)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Bisa dikirim ke WhatsApp, Telegram, atau aplikasi lainnya', style: TextStyle(fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.of(ctx).pop();
                String? imagePath = await TicketShareService.captureRepaintBoundary(_qrRepaintBoundaryKey);
                imagePath ??= await TicketShareService.generateTicketCodeImageFile(currentTicket);
                await TicketShareService.shareTicketViaSystem(
                  ticket: currentTicket,
                  qrImagePath: imagePath,
                );
              },
            ),
            const SizedBox(height: 8),

            // 2. Share to WhatsApp
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF2E7D32)),
              ),
              title: const Text('Kirim ke WhatsApp', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Kirim foto QR/Barcode & rincian karcis ke WhatsApp', style: TextStyle(fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await TicketShareService.shareToWhatsApp(currentTicket);
              },
            ),
            const SizedBox(height: 8),

            // 3. Share to Telegram
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded, color: Color(0xFF0284C7)),
              ),
              title: const Text('Kirim ke Telegram', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Kirim foto QR/Barcode & rincian karcis ke Telegram', style: TextStyle(fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await TicketShareService.shareToTelegram(currentTicket);
              },
            ),
            const SizedBox(height: 8),

            // 4. Copy to Clipboard
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.copy_rounded, color: Color(0xFF475569)),
              ),
              title: const Text('Salin Rincian & Kode Karcis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Salin seluruh rincian karcis ke clipboard', style: TextStyle(fontSize: 12)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await TicketShareService.copyTicketDetails(context, currentTicket);
              },
            ),
          ],
        ),
      ),
    ),
  );
  }
}
