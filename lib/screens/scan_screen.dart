import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import '../widgets/location_picker_sheet.dart';

enum ScanMode {
  all,
  barcode,
  qr,
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  static String formatDisplayName(String format) {
    final f = format.toLowerCase().replaceAll('_', '');
    if (f.contains('microqr')) {
      return 'QR Code (Micro QR)';
    } else if (f.contains('qr')) {
      return 'QR Code';
    } else if (f.contains('code128')) {
      return 'Barcode (Code 128)';
    } else if (f.contains('code39')) {
      return 'Barcode (Code 39)';
    } else if (f.contains('code93')) {
      return 'Barcode (Code 93)';
    } else if (f.contains('ean13')) {
      return 'Barcode (EAN-13)';
    } else if (f.contains('ean8')) {
      return 'Barcode (EAN-8)';
    } else if (f.contains('upca')) {
      return 'Barcode (UPC-A)';
    } else if (f.contains('upce')) {
      return 'Barcode (UPC-E)';
    } else if (f.contains('codabar')) {
      return 'Barcode (Codabar)';
    } else if (f.contains('itf')) {
      return 'Barcode (ITF)';
    } else if (f.contains('pdf417')) {
      return 'Barcode (PDF-417)';
    } else if (f.contains('databar')) {
      return 'Barcode (GS1 DataBar)';
    } else if (f.contains('datamatrix')) {
      return 'Data Matrix';
    } else if (f.contains('aztec')) {
      return 'Aztec Code';
    } else if (f.contains('maxi')) {
      return 'MaxiCode';
    } else if (f.contains('manual')) {
      return 'Input Manual';
    } else if (f.contains('code') || f.contains('barcode')) {
      return 'Barcode (${format.toUpperCase()})';
    }
    return format.toUpperCase();
  }

  static bool isBarcodeFormat(String format) {
    final f = format.toLowerCase().replaceAll('_', '');
    if (f.contains('qr') ||
        f.contains('manual') ||
        f.contains('datamatrix') ||
        f.contains('aztec') ||
        f.contains('maxi') ||
        f.contains('unknown') ||
        f.contains('all')) {
      return false;
    }
    return f.contains('code') ||
        f.contains('ean') ||
        f.contains('upc') ||
        f.contains('itf') ||
        f.contains('codabar') ||
        f.contains('pdf417') ||
        f.contains('databar') ||
        f.contains('barcode');
  }

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [
      BarcodeFormat.all,
    ],
  );

  bool _isProcessing = false;
  bool _isManualInputOpen = false;
  ScanMode _selectedMode = ScanMode.all;
  bool _isZoomed = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _isManualInputOpen) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    Barcode? targetBarcode;
    if (_selectedMode == ScanMode.barcode) {
      for (final b in barcodes) {
        final code = b.rawValue;
        if (code != null && code.trim().isNotEmpty && ScanScreen.isBarcodeFormat(b.format.name)) {
          targetBarcode = b;
          break;
        }
      }
    } else if (_selectedMode == ScanMode.qr) {
      for (final b in barcodes) {
        final code = b.rawValue;
        if (code != null && code.trim().isNotEmpty && !ScanScreen.isBarcodeFormat(b.format.name)) {
          targetBarcode = b;
          break;
        }
      }
    } else {
      for (final b in barcodes) {
        final code = b.rawValue;
        if (code != null && code.trim().isNotEmpty) {
          targetBarcode = b;
          break;
        }
      }
    }

    if (targetBarcode != null) {
      final code = targetBarcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _showSaveTicketSheet(scannedCode: code.trim(), format: targetBarcode.format.name);
      }
    }
  }

  void _showSaveTicketSheet({
    required String scannedCode,
    String format = 'QR_CODE',
  }) {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });
    final plateController = TextEditingController();
    final locationController = TextEditingController();
    final floorController = TextEditingController();
    final blockController = TextEditingController();
    final notesController = TextEditingController();
    String selectedVehicle = 'Mobil';
    DateTime selectedTime = DateTime.now();
    String? photoPath;
    String? ticketPhotoPath;
    double? latitude;
    double? longitude;
    bool isGettingGps = false;
    final floorSuggestions = ['B1', 'B2', 'B3', 'P1', 'P2', 'P3', 'GF', 'Lt 1', 'Lt 2', 'Lt 3', 'Rooftop'];
    final blockSuggestions = ['Tiang ', 'Blok ', 'Zona A', 'Zona B', 'Zona C'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final timeStr =
              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
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
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Karcis Berhasil Dipindai',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Scanned code preview container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'KODE KARCIS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFDBEAFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    ScanScreen.isBarcodeFormat(format)
                                        ? Icons.view_week_rounded
                                        : (format.toLowerCase().contains('manual')
                                            ? Icons.keyboard_outlined
                                            : Icons.qr_code_2_rounded),
                                    size: 13,
                                    color: const Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    ScanScreen.formatDisplayName(format),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          scannedCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Plat Nomor Kendaraan
                  TextField(
                    controller: plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Plat Nomor Kendaraan (Opsional)',
                      hintText: 'B 1234 ABC',
                      prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Jenis Kendaraan Chips
                  Row(
                    children: [
                      const Text(
                        'Jenis:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 10),
                      Wrap(
                        spacing: 8,
                        children: ['Mobil', 'Motor', 'Lainnya'].map((type) {
                          final isSelected = selectedVehicle == type;
                          return ChoiceChip(
                            label: Text(type),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() {
                                  selectedVehicle = type;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lokasi Parkir & Template
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: locationController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Lokasi / Nama Gedung (Opsional)',
                          hintText: 'Mall PTC, Grand Indonesia, dll',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.bookmark_border_rounded, color: Color(0xFF2563EB)),
                            tooltip: 'Pilih dari Template Lokasi',
                            onPressed: () async {
                              final picked = await LocationPickerSheet.show(
                                sheetContext,
                                currentLocation: locationController.text.trim(),
                                vehicleType: selectedVehicle,
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  locationController.text = picked.name;
                                });
                              }
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Quick Template Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...['Mall PTC (Pakuwon)', 'Grand Indonesia', 'Stasiun Kereta / KRL', 'Pasar & Wisata (Sekali Bayar)']
                                .map((templateName) {
                              final isSelected = locationController.text.trim().toLowerCase() ==
                                  templateName.toLowerCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(
                                    templateName.contains('PTC')
                                        ? 'Mall PTC'
                                        : (templateName.contains('Stasiun')
                                            ? 'Stasiun KRL'
                                            : (templateName.contains('Pasar')
                                                ? 'Pasar Flat'
                                                : templateName)),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                    ),
                                  ),
                                  backgroundColor: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  onPressed: () {
                                    setSheetState(() {
                                      locationController.text = templateName;
                                    });
                                  },
                                ),
                              );
                            }),
                            ActionChip(
                              avatar: const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF2563EB)),
                              label: const Text(
                                'Template Lain...',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              backgroundColor: const Color(0xFFEFF6FF),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onPressed: () async {
                                final picked = await LocationPickerSheet.show(
                                  sheetContext,
                                  currentLocation: locationController.text.trim(),
                                  vehicleType: selectedVehicle,
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    locationController.text = picked.name;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // Matched Location Tariff Info Banner
                      Builder(
                        builder: (_) {
                          final parkingProvider =
                              Provider.of<ParkingProvider>(sheetContext, listen: false);
                          final matchedLoc = parkingProvider.locationService
                              .findLocationByName(locationController.text);

                          if (matchedLoc != null) {
                            final rule = matchedLoc.getRateFor(selectedVehicle);
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                                        children: [
                                          TextSpan(
                                            text: 'Tarif ${matchedLoc.name} ($selectedVehicle): ',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          TextSpan(
                                            text: rule.summaryDescription,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Titik Parkir (Find My Vehicle)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pin_drop_rounded, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 6),
                            Text(
                              'Titik Parkir (Find My Vehicle)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Field Lantai & Blok
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: floorController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: 'Lantai',
                                  hintText: 'B2, P1',
                                  prefixIcon: const Icon(Icons.layers_outlined, size: 18),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: blockController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: 'No. Tiang / Blok',
                                  hintText: 'Tiang F12, Blok C',
                                  prefixIcon: const Icon(Icons.grid_view_rounded, size: 18),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick Floor Chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: floorSuggestions.map((floor) {
                            final isSelected = floorController.text.trim().toUpperCase() == floor.toUpperCase();
                            return ChoiceChip(
                              label: Text(floor),
                              selected: isSelected,
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                              onSelected: (selected) {
                                setSheetState(() {
                                  floorController.text = selected ? floor : '';
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: blockSuggestions.map((sug) {
                            return ActionChip(
                              label: Text('+ $sug'),
                              backgroundColor: const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              labelStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  if (blockController.text.isEmpty) {
                                    blockController.text = sug;
                                  } else if (!blockController.text.contains(sug.trim())) {
                                    blockController.text = '${blockController.text} $sug'.trim();
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        // Quick Photo and GPS buttons row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: photoPath != null
                                    ? const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669))
                                    : const Icon(Icons.camera_alt_outlined, size: 16),
                                label: Text(
                                  photoPath != null ? 'Foto Ada' : 'Foto Tiang',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: photoPath != null ? const Color(0xFF059669) : const Color(0xFF2563EB),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  side: BorderSide(
                                    color: photoPath != null ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  final p = await PhotoService.pickPillarPhoto(sheetContext);
                                  if (p != null) {
                                    setSheetState(() {
                                      photoPath = p;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: isGettingGps
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                      )
                                    : (latitude != null
                                        ? const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669))
                                        : const Icon(Icons.my_location_rounded, size: 16)),
                                label: Text(
                                  latitude != null ? 'GPS Ada' : 'Drop Pin GPS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: latitude != null ? const Color(0xFF059669) : const Color(0xFF2563EB),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  side: BorderSide(
                                    color: latitude != null ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isGettingGps
                                    ? null
                                    : () async {
                                        setSheetState(() {
                                          isGettingGps = true;
                                        });
                                        final locResult = await LocationService.getCurrentCoordinates();
                                        setSheetState(() {
                                          isGettingGps = false;
                                          if (locResult.isSuccess && locResult.latitude != null) {
                                            latitude = locResult.latitude;
                                            longitude = locResult.longitude;
                                          }
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Jam Masuk Picker
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: sheetContext,
                        initialTime: TimeOfDay.fromDateTime(selectedTime),
                      );
                      if (pickedTime != null) {
                        setSheetState(() {
                          final now = DateTime.now();
                          selectedTime = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Jam Masuk Parkir',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Text(
                            'Ubah',
                            style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Catatan Tambahan
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      hintText: 'Dekat pilar H7 atau lobi barat',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Foto Struk Karcis Kertas (Opsional - Cegah Denda)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ticketPhotoPath != null ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          ticketPhotoPath != null ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
                          color: ticketPhotoPath != null ? const Color(0xFF059669) : const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ticketPhotoPath != null ? 'Foto Karcis Terlampir' : 'Foto Karcis Kertas (Cegah Denda)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: ticketPhotoPath != null ? const Color(0xFF059669) : const Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'Bukti jika tiket kertas hilang/tercecer',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        if (ticketPhotoPath != null) ...[
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Color(0xFFDC2626)),
                            tooltip: 'Hapus Lampiran Foto',
                            onPressed: () {
                              setSheetState(() {
                                ticketPhotoPath = null;
                              });
                            },
                          ),
                        ],
                        TextButton(
                          onPressed: () async {
                            final picked = await PhotoService.pickTicketPhoto(sheetContext);
                            if (picked != null) {
                              setSheetState(() {
                                ticketPhotoPath = picked;
                              });
                            }
                          },
                          child: Text(
                            ticketPhotoPath != null ? 'Ganti' : '+ Foto',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Simpan Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final provider = Provider.of<ParkingProvider>(context, listen: false);
                      final ticket = await provider.addTicket(
                        rawCode: scannedCode,
                        format: format,
                        plateNumber: plateController.text.trim().isNotEmpty
                            ? plateController.text.trim()
                            : null,
                        vehicleType: selectedVehicle,
                        locationName: locationController.text.trim().isNotEmpty
                            ? locationController.text.trim()
                            : null,
                        entryTime: selectedTime,
                        notes: notesController.text.trim().isNotEmpty
                            ? notesController.text.trim()
                            : null,
                        parkingFloor: floorController.text.trim().isNotEmpty
                            ? floorController.text.trim()
                            : null,
                        parkingBlock: blockController.text.trim().isNotEmpty
                            ? blockController.text.trim()
                            : null,
                        parkingPhotoPath: photoPath,
                        ticketPhotoPath: ticketPhotoPath,
                        latitude: latitude,
                        longitude: longitude,
                      );

                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop(); // close bottom sheet
                      }
                      if (mounted) {
                        Navigator.of(context).pop(ticket); // return ticket to HomeScreen
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Simpan Karcis',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  void _showManualInputDialog() {
    setState(() {
      _isManualInputOpen = true;
    });
    final codeController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.keyboard_outlined, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Input Kode Karcis Manual', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: codeController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nomor / Barcode Karcis',
                    hintText: 'PRK-20261014-9981 atau nomor barcode',
                    prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                    errorText: errorMessage,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) {
                    if (codeController.text.trim().isEmpty) {
                      setDialogState(() {
                        errorMessage = 'Kode karcis tidak boleh kosong';
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mendukung nomor karcis, QR code, atau barcode.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final text = codeController.text.trim();
                  if (text.isEmpty) {
                    setDialogState(() {
                      errorMessage = 'Kode karcis tidak boleh kosong';
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  _showSaveTicketSheet(scannedCode: text, format: 'MANUAL');
                },
                child: const Text('Lanjutkan'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isManualInputOpen = false;
        });
      }
    });
  }

  List<Widget> _buildCornerBrackets(double width, double height) {
    const double length = 22;
    const double thickness = 3.5;
    const double radius = 4;
    const Color cornerColor = Color(0xFF38BDF8);

    return [
      // Top-Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: length,
          height: length,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cornerColor, width: thickness),
              left: BorderSide(color: cornerColor, width: thickness),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(radius)),
          ),
        ),
      ),
      // Top-Right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: length,
          height: length,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cornerColor, width: thickness),
              right: BorderSide(color: cornerColor, width: thickness),
            ),
            borderRadius: BorderRadius.only(topRight: Radius.circular(radius)),
          ),
        ),
      ),
      // Bottom-Left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: length,
          height: length,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cornerColor, width: thickness),
              left: BorderSide(color: cornerColor, width: thickness),
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(radius)),
          ),
        ),
      ),
      // Bottom-Right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: length,
          height: length,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cornerColor, width: thickness),
              right: BorderSide(color: cornerColor, width: thickness),
            ),
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(radius)),
          ),
        ),
      ),
    ];
  }

  Widget _buildModePill({
    required ScanMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    double frameWidth;
    double frameHeight;
    String guideText;

    switch (_selectedMode) {
      case ScanMode.barcode:
        frameWidth = (screenWidth * 0.88).clamp(280.0, 330.0);
        frameHeight = 140.0;
        guideText = 'Posisikan garis barcode secara horizontal di dalam kotak';
        break;
      case ScanMode.qr:
        frameWidth = 260.0;
        frameHeight = 260.0;
        guideText = 'Posisikan QR code di dalam kotak pemindai';
        break;
      case ScanMode.all:
        frameWidth = 280.0;
        frameHeight = 210.0;
        guideText = 'Arahkan kamera ke barcode atau QR code karcis';
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Pindai Karcis Baru', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Zoom ${_isZoomed ? "2x (Aktif)" : "1x"}',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _isZoomed ? const Color(0xFF2563EB) : Colors.transparent,
                border: Border.all(color: _isZoomed ? const Color(0xFF38BDF8) : Colors.white60),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isZoomed ? '2x' : '1x',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
              ),
            ),
            onPressed: () async {
              final newZoom = !_isZoomed;
              setState(() {
                _isZoomed = newZoom;
              });
              try {
                if (newZoom) {
                  await _cameraController.setZoomScale(0.35);
                } else {
                  await _cameraController.resetZoomScale();
                }
              } catch (_) {}
            },
          ),
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _cameraController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: state.torchState == TorchState.on ? Colors.amber : Colors.white,
                );
              },
            ),
            onPressed: () async {
              try {
                await _cameraController.toggleTorch();
              } catch (_) {}
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () async {
              try {
                await _cameraController.switchCamera();
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 48),
                      const SizedBox(height: 14),
                      const Text(
                        'Kamera tidak dapat diakses atau izin belum diberikan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (!_isManualInputOpen) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _showManualInputDialog,
                          icon: const Icon(Icons.keyboard_outlined, size: 20),
                          label: const Text('Input Kode Manual', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // Top Mode Switcher (Semua, Barcode, QR Code)
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModePill(
                      mode: ScanMode.all,
                      label: 'Semua',
                      icon: Icons.filter_center_focus_rounded,
                    ),
                    const SizedBox(width: 4),
                    _buildModePill(
                      mode: ScanMode.barcode,
                      label: 'Barcode',
                      icon: Icons.view_week_rounded,
                    ),
                    const SizedBox(width: 4),
                    _buildModePill(
                      mode: ScanMode.qr,
                      label: 'QR Code',
                      icon: Icons.qr_code_2_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Viewfinder scan frame overlay with dynamic aspect ratio & animated laser line
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              width: frameWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 4 Corner Brackets
                  ..._buildCornerBrackets(frameWidth, frameHeight),

                  // Animated laser scanning line
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Positioned(
                        top: 8 + (frameHeight - 20) * _animation.value,
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF38BDF8),
                                Color(0xFF2563EB),
                                Color(0xFF38BDF8),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.7),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Guidance text & Manual Input button at bottom
          if (!_isManualInputOpen)
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedMode == ScanMode.barcode
                            ? Icons.view_week_rounded
                            : (_selectedMode == ScanMode.qr
                                ? Icons.qr_code_2_rounded
                                : Icons.camera_alt_outlined),
                        size: 16,
                        color: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          guideText,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _showManualInputDialog,
                  icon: const Icon(Icons.keyboard_outlined, size: 20),
                  label: const Text('Input Kode Manual'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
