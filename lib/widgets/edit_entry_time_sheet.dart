import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parking_ticket.dart';
import '../providers/parking_provider.dart';

class EditEntryTimeSheet extends StatefulWidget {
  final ParkingTicket ticket;

  const EditEntryTimeSheet({
    super.key,
    required this.ticket,
  });

  static Future<bool?> show(BuildContext context, ParkingTicket ticket) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditEntryTimeSheet(ticket: ticket),
    );
  }

  @override
  State<EditEntryTimeSheet> createState() => _EditEntryTimeSheetState();
}

class _EditEntryTimeSheetState extends State<EditEntryTimeSheet> {
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.ticket.entryTime;
  }

  void _adjustMinutes(int minutes) {
    setState(() {
      _selectedDateTime = _selectedDateTime.add(Duration(minutes: minutes));
    });
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  String _formatCalculatedDuration() {
    final diff = DateTime.now().difference(_selectedDateTime);
    if (diff.isNegative) {
      return 'Waktu masuk di masa depan (${diff.inMinutes.abs()} mnt lagi)';
    }
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours jam $minutes mnt';
    } else {
      return '$minutes mnt';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(_selectedDateTime);
    String dateStr;
    try {
      dateStr = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(_selectedDateTime);
    } catch (_) {
      dateStr = DateFormat('EEE, dd MMM yyyy').format(_selectedDateTime);
    }

    final ticketLabel = widget.ticket.plateNumber?.isNotEmpty == true
        ? widget.ticket.plateNumber!
        : 'Karcis #${widget.ticket.rawCode.substring(0, widget.ticket.rawCode.length.clamp(0, 8))}';

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
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
            const SizedBox(height: 14),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ubah Jam Masuk',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        ticketLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Active Selected Time Display Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WAKTU MASUK TERPILIH',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time_rounded, size: 16),
                            label: const Text(
                              'Pilih Jam',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Ubah Tanggal',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1, color: Color(0xFFE2E8F0)),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'Durasi Parkir Terhitung: ${_formatCalculatedDuration()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quick Adjustments Section
            const Text(
              'Penyesuaian Cepat Mundur (Menit/Jam)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickButton(label: '-5 mnt', onTap: () => _adjustMinutes(-5)),
                _buildQuickButton(label: '-10 mnt', onTap: () => _adjustMinutes(-10)),
                _buildQuickButton(label: '-15 mnt', onTap: () => _adjustMinutes(-15)),
                _buildQuickButton(label: '-30 mnt', onTap: () => _adjustMinutes(-30)),
                _buildQuickButton(label: '-1 jam', onTap: () => _adjustMinutes(-60)),
                _buildQuickButton(
                  label: '+5 mnt',
                  onTap: () => _adjustMinutes(5),
                  color: const Color(0xFFF1F5F9),
                  textColor: const Color(0xFF334155),
                ),
                _buildQuickButton(
                  label: 'Set Jam Sekarang',
                  onTap: () {
                    setState(() {
                      _selectedDateTime = DateTime.now();
                    });
                  },
                  color: const Color(0xFFF1F5F9),
                  textColor: const Color(0xFF334155),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save / Cancel Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final provider = Provider.of<ParkingProvider>(context, listen: false);
                      await provider.updateTicketEntryTime(widget.ticket.id, _selectedDateTime);

                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Jam masuk berhasil diubah menjadi $timeStr ($dateStr)'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton({
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFFEFF6FF),
    Color textColor = const Color(0xFF2563EB),
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
