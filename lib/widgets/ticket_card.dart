import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/parking_ticket.dart';
import 'edit_entry_time_sheet.dart';

class TicketCard extends StatelessWidget {
  final ParkingTicket ticket;
  final VoidCallback onTap;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
  });

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

  @override
  Widget build(BuildContext context) {
    final duration = ticket.durationParked;
    final passedLimits = ticket.reminderHours
        .where((h) => duration.inMinutes >= (h * 60).round())
        .toList();
    final isFirstLimitPassed = passedLimits.isNotEmpty;
    final double highestPassed = isFirstLimitPassed ? passedLimits.last : 0.0;
    final isSecondLimitPassed = isFirstLimitPassed && highestPassed >= 24;

    String formattedDate;
    try {
      formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(ticket.entryTime);
    } catch (_) {
      formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(ticket.entryTime);
    }

    final hasPlate = ticket.plateNumber != null && ticket.plateNumber!.isNotEmpty;
    final titleText = hasPlate ? ticket.plateNumber! : 'Karcis #${ticket.rawCode.substring(0, ticket.rawCode.length.clamp(0, 8))}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isFirstLimitPassed ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isFirstLimitPassed ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Vehicle Icon + Title + QR Mini Preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getVehicleIcon(ticket.vehicleType),
                      color: const Color(0xFF2563EB),
                      size: 24,
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else
                              Text(
                                ticket.vehicleType,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // QR Mini thumbnail preview
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: QrImageView(
                      data: ticket.rawCode,
                      version: QrVersions.auto,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              ),
              // Bottom Row: Entry Time & Live Elapsed Duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Waktu Masuk',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => EditEntryTimeSheet.show(context, ticket),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 11, color: Color(0xFF2563EB)),
                                  SizedBox(width: 2),
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
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isFirstLimitPassed
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFirstLimitPassed
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: isFirstLimitPassed
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          ticket.durationFormatted,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isFirstLimitPassed
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isFirstLimitPassed) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
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
            ],
          ),
        ),
      ),
    );
  }
}
