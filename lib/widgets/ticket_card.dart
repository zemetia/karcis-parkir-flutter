import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../models/parking_ticket.dart';
import '../models/parking_rate_rule.dart';
import '../providers/parking_provider.dart';
import '../screens/scan_screen.dart';
import '../services/location_service.dart';
import 'edit_entry_time_sheet.dart';
import 'edit_parking_location_sheet.dart';
import 'parking_photo_viewer.dart';
import 'qr_display.dart';

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

    ParkingProvider? provider;
    try {
      provider = Provider.of<ParkingProvider>(context, listen: false);
    } catch (_) {}
    final estimatedCost = provider != null
        ? provider.estimateCostForTicket(ticket)
        : ParkingRateRule.defaultFor(ticket.vehicleType).calculateCost(ticket.durationParked);
    final costFormatted =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(estimatedCost);

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
                  // Mini thumbnail preview: Barcode 1D or QR
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ScanScreen.isBarcodeFormat(ticket.format)
                        ? Center(
                            child: BarcodeWidget(
                              barcode: QrDisplayCard.resolveBarcode(ticket.format, ticket.rawCode),
                              data: ticket.rawCode,
                              width: 42,
                              height: 28,
                              drawText: false,
                              errorBuilder: (context, error) => const Icon(
                                Icons.view_week_rounded,
                                size: 24,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          )
                        : QrImageView(
                            data: ticket.rawCode,
                            version: QrVersions.auto,
                            size: 40,
                          ),
                  ),
                ],
              ),
              if (ticket.hasVehicleLocation || ticket.hasTicketPhoto) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (ticket.hasVehicleLocation)
                      InkWell(
                        onTap: () => EditParkingLocationSheet.show(context, ticket),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pin_drop_rounded, size: 14, color: Color(0xFF059669)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  ticket.parkingLocationSummary ?? 'Titik Parkir Tersimpan',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (ticket.parkingPhotoPath != null) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.camera_alt_outlined, size: 13, color: Color(0xFF059669)),
                              ],
                              if (ticket.latitude != null) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.gps_fixed_rounded, size: 13, color: Color(0xFF059669)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (ticket.parkingPhotoPath != null)
                      InkWell(
                        onTap: () => ParkingPhotoViewer.show(
                          context,
                          imagePath: ticket.parkingPhotoPath!,
                          title: 'Foto Tiang / Blok Parkir',
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera_outlined, size: 12, color: Color(0xFF2563EB)),
                              SizedBox(width: 4),
                              Text(
                                'Foto Tiang',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (ticket.latitude != null && ticket.longitude != null)
                      InkWell(
                        onTap: () async {
                          final success = await LocationService.openGoogleMaps(
                            latitude: ticket.latitude!,
                            longitude: ticket.longitude!,
                            label: ticket.plateNumber != null
                                ? 'Kendaraan ${ticket.plateNumber}'
                                : 'Kendaraan Parkir',
                          );
                          if (!success && context.mounted) {
                            final url = ticket.googleMapsUrl ??
                                'https://www.google.com/maps/search/?api=1&query=${ticket.latitude},${ticket.longitude}';
                            await Clipboard.setData(ClipboardData(text: url));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tidak dapat membuka Google Maps. Tautan disalin ke clipboard.'),
                                backgroundColor: Color(0xFFDC2626),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.navigation_rounded, size: 12, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text(
                                'Buka Peta',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (ticket.hasTicketPhoto)
                      InkWell(
                        onTap: () {
                          if (ticket.ticketPhotoPath != null) {
                            ParkingPhotoViewer.show(
                              context,
                              imagePath: ticket.ticketPhotoPath!,
                              title: 'Foto Struk Fisik Karcis',
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 14, color: Color(0xFFD97706)),
                              SizedBox(width: 5),
                              Text(
                                'Bukti Fisik Karcis',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (!ticket.hasVehicleLocation) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => EditParkingLocationSheet.show(context, ticket),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text(
                          '+ Catat Titik Parkir (Lantai, Tiang, GPS)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              // Cost & Duration Real-Time Estimation Row
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF15803D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Durasi: ${ticket.durationFormatted} • Estimasi: $costFormatted',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
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
