import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parking_ticket.dart';
import '../providers/parking_provider.dart';
import '../screens/scan_screen.dart';
import '../screens/ticket_detail_screen.dart';

enum HistoryFilter {
  thisMonth,
  all,
}

class HistoryScreen extends StatefulWidget {
  final bool isTab;

  const HistoryScreen({super.key, this.isTab = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.thisMonth;

  List<ParkingTicket> _filterTickets(List<ParkingTicket> tickets) {
    if (_filter == HistoryFilter.all) {
      return tickets;
    }
    final now = DateTime.now();
    return tickets.where((t) {
      return t.entryTime.year == now.year && t.entryTime.month == now.month;
    }).toList();
  }

  Future<void> _handleRestore(BuildContext context, ParkingTicket ticket) async {
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
        content: Text(
          'Karcis ${ticket.plateNumber?.isNotEmpty == true ? ticket.plateNumber : ticket.rawCode} akan dipulihkan kembali ke daftar karcis aktif.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
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
      await provider.restoreTicket(ticket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karcis berhasil dipulihkan ke daftar aktif.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handlePermanentDelete(BuildContext context, ParkingTicket ticket) async {
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
        content: Text(
          'Karcis ${ticket.plateNumber?.isNotEmpty == true ? ticket.plateNumber : ticket.rawCode} akan dihapus selamanya dari penyimpanan. Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
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
      await provider.deleteTicketPermanently(ticket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karcis telah dihapus secara permanen.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleClearAllHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text('Hapus Semua Riwayat?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Seluruh karcis di riwayat parkir akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
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
            child: const Text('Ya, Hapus Semua', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<ParkingProvider>(context, listen: false);
      await provider.clearHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seluruh riwayat parkir berhasil dibersihkan.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

  Widget _buildStatisticsCard(List<ParkingTicket> tickets) {
    final count = tickets.length;
    final carCount = tickets.where((t) => t.vehicleType.toLowerCase() == 'mobil').length;
    final bikeCount = tickets.where((t) => t.vehicleType.toLowerCase() == 'motor').length;
    final otherCount = count - carCount - bikeCount;

    // Most visited location
    final locMap = <String, int>{};
    for (final t in tickets) {
      final loc = t.locationName?.trim();
      if (loc != null && loc.isNotEmpty) {
        locMap[loc] = (locMap[loc] ?? 0) + 1;
      }
    }
    String topLoc = '-';
    int topLocCount = 0;
    locMap.forEach((k, v) {
      if (v > topLocCount) {
        topLoc = k;
        topLocCount = v;
      }
    });

    final barcodeCount = tickets.where((t) => ScanScreen.isBarcodeFormat(t.format)).length;
    final qrCount = count - barcodeCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics_rounded, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Statistik Frekuensi Parkir',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: Text(
                  _filter == HistoryFilter.thisMonth ? 'Bulan Ini' : 'Semua Waktu',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL FREKUENSI',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'karcis parkir',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                height: 48,
                width: 1,
                color: Colors.white12,
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOKASI TERSERING',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topLocCount > 0 ? '$topLoc ($topLocCount x)' : '-',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE2E8F0),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(
                icon: Icons.directions_car_rounded,
                label: 'Mobil',
                value: '$carCount',
              ),
              _buildMiniStat(
                icon: Icons.two_wheeler_rounded,
                label: 'Motor',
                value: '$bikeCount',
              ),
              if (otherCount > 0)
                _buildMiniStat(
                  icon: Icons.commute_rounded,
                  label: 'Lainnya',
                  value: '$otherCount',
                ),
              _buildMiniStat(
                icon: Icons.view_week_rounded,
                label: 'Barcode 1D',
                value: '$barcodeCount',
              ),
              _buildMiniStat(
                icon: Icons.qr_code_2_rounded,
                label: 'QR Code',
                value: '$qrCount',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final now = DateTime.now();
    String monthName;
    try {
      monthName = DateFormat('MMMM yyyy', 'id_ID').format(now);
    } catch (_) {
      monthName = DateFormat('MMMM yyyy').format(now);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('Bulan Ini ($monthName)'),
            selected: _filter == HistoryFilter.thisMonth,
            selectedColor: const Color(0xFF2563EB),
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _filter == HistoryFilter.thisMonth ? Colors.white : const Color(0xFF475569),
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _filter = HistoryFilter.thisMonth;
                });
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Semua'),
            selected: _filter == HistoryFilter.all,
            selectedColor: const Color(0xFF2563EB),
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _filter == HistoryFilter.all ? Colors.white : const Color(0xFF475569),
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _filter = HistoryFilter.all;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Consumer<ParkingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final historyTickets = provider.historyTickets;
        final filteredTickets = _filterTickets(historyTickets);

        return RefreshIndicator(
          onRefresh: () => provider.loadTickets(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              // Filter Chips (Bulan Ini / Semua)
              _buildFilterChips(),

              // Parking Frequency Statistics Card
              _buildStatisticsCard(filteredTickets),

              // History tickets list header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    const Text(
                      'Daftar Riwayat Selesai',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Text(
                        '${filteredTickets.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (historyTickets.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _handleClearAllHistory(context),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                        label: const Text('Hapus Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),

              // Empty State
              if (filteredTickets.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_toggle_off_rounded,
                          size: 48,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Riwayat Parkir',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _filter == HistoryFilter.thisMonth
                            ? 'Tidak ada karcis parkir yang diselesaikan pada bulan ini.'
                            : 'Karcis yang Anda selesaikan akan otomatis diarsipkan di sini.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filteredTickets.map((ticket) {
                  final isBarcode = ScanScreen.isBarcodeFormat(ticket.format);
                  String formattedDate;
                  try {
                    formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(ticket.entryTime);
                  } catch (_) {
                    formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(ticket.entryTime);
                  }

                  final titleText = ticket.plateNumber != null && ticket.plateNumber!.isNotEmpty
                      ? ticket.plateNumber!
                      : 'Karcis #${ticket.rawCode.substring(0, ticket.rawCode.length.clamp(0, 8))}';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TicketDetailScreen(ticket: ticket),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Vehicle Icon + Title + Status Badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getVehicleIcon(ticket.vehicleType),
                                    color: const Color(0xFF475569),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        titleText,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (ticket.locationName != null && ticket.locationName!.isNotEmpty) ...[
                                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${ticket.vehicleType} • ${ticket.locationName}',
                                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ] else
                                            Text(
                                              ticket.vehicleType,
                                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Selesai',
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
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                            ),
                            // Middle Row: Entry Time & Format tag
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isBarcode ? Icons.view_week_rounded : Icons.qr_code_2_rounded,
                                        size: 12,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ScanScreen.formatDisplayName(ticket.format),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Action buttons: Pulihkan & Hapus Permanen
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFFECACA)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _handlePermanentDelete(context, ticket),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                                  label: const Text('Hapus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    foregroundColor: const Color(0xFF2563EB),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: Color(0xFFDBEAFE)),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _handleRestore(context, ticket),
                                  icon: const Icon(Icons.restore_rounded, size: 14),
                                  label: const Text('Pulihkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );

    if (widget.isTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Riwayat Parkir'),
        centerTitle: true,
      ),
      body: content,
    );
  }
}
