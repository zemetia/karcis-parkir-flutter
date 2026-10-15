import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parking_ticket.dart';
import '../providers/parking_provider.dart';
import '../widgets/edit_entry_time_sheet.dart';
import '../widgets/qr_display.dart';

class TicketDetailScreen extends StatelessWidget {
  final ParkingTicket ticket;

  const TicketDetailScreen({
    super.key,
    required this.ticket,
  });

  Future<void> _handleDone(BuildContext context) async {
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
        content: const Text(
          'Karcis ini akan diselesaikan dan dihapus dari daftar aktif.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
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
      await provider.completeTicket(ticket.id);

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
          (t) => t.id == ticket.id,
          orElse: () => ticket,
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
                  // Recreated QR code card with tap to expand
                  Center(
                    child: QrDisplayCard(
                      data: currentTicket.rawCode,
                      size: 230,
                    ),
                  ),

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 24),

                  // Action buttons: Done and Kembali
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
}
