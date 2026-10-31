import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/parking_ticket.dart';
import '../providers/parking_provider.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import 'parking_photo_viewer.dart';

class EditParkingLocationSheet extends StatefulWidget {
  final ParkingTicket ticket;

  const EditParkingLocationSheet({
    super.key,
    required this.ticket,
  });

  static Future<void> show(BuildContext context, ParkingTicket ticket) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditParkingLocationSheet(ticket: ticket),
    );
  }

  @override
  State<EditParkingLocationSheet> createState() => _EditParkingLocationSheetState();
}

class _EditParkingLocationSheetState extends State<EditParkingLocationSheet> {
  late TextEditingController _floorController;
  late TextEditingController _blockController;
  String? _photoPath;
  bool _photoRemoved = false;
  double? _latitude;
  double? _longitude;
  bool _coordinatesRemoved = false;
  bool _isGettingLocation = false;

  final List<String> _floorSuggestions = [
    'B1',
    'B2',
    'B3',
    'P1',
    'P2',
    'P3',
    'GF',
    'Lt 1',
    'Lt 2',
    'Lt 3',
    'Rooftop',
  ];

  final List<String> _blockSuggestions = [
    'Tiang ',
    'Blok ',
    'Zona A',
    'Zona B',
    'Zona C',
  ];

  @override
  void initState() {
    super.initState();
    _floorController = TextEditingController(text: widget.ticket.parkingFloor ?? '');
    _blockController = TextEditingController(text: widget.ticket.parkingBlock ?? '');
    _photoPath = widget.ticket.parkingPhotoPath;
    _latitude = widget.ticket.latitude;
    _longitude = widget.ticket.longitude;
  }

  @override
  void dispose() {
    _floorController.dispose();
    _blockController.dispose();
    super.dispose();
  }

  Future<void> _handleCapturePhoto({ImageSource? preferredSource}) async {
    final path = await PhotoService.pickPillarPhoto(context, preferredSource: preferredSource);
    if (path != null && mounted) {
      setState(() {
        _photoPath = path;
        _photoRemoved = false;
      });
    }
  }

  Future<void> _handleGetLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    final result = await LocationService.getCurrentCoordinates();

    if (!mounted) return;

    setState(() {
      _isGettingLocation = false;
    });

    if (result.isSuccess && result.latitude != null && result.longitude != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _coordinatesRemoved = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Titik koordinat GPS berhasil disimpan.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Gagal mengambil titik GPS.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
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

  Future<void> _handleOpenMap() async {
    if (_latitude == null || _longitude == null) return;
    final success = await LocationService.openGoogleMaps(
      latitude: _latitude!,
      longitude: _longitude!,
      label: widget.ticket.plateNumber != null
          ? 'Kendaraan ${widget.ticket.plateNumber}'
          : 'Kendaraan Parkir',
    );
    if (!success && mounted) {
      final url = 'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude';
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka Google Maps. Tautan telah disalin ke clipboard.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSave() async {
    final provider = Provider.of<ParkingProvider>(context, listen: false);

    final floor = _floorController.text.trim();
    final block = _blockController.text.trim();

    await provider.updateParkingLocation(
      widget.ticket.id,
      parkingFloor: floor.isNotEmpty ? floor : null,
      clearParkingFloor: floor.isEmpty,
      parkingBlock: block.isNotEmpty ? block : null,
      clearParkingBlock: block.isEmpty,
      parkingPhotoPath: _photoPath,
      clearParkingPhoto: _photoRemoved,
      latitude: _latitude,
      longitude: _longitude,
      clearCoordinates: _coordinatesRemoved,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Titik parkir berhasil diperbarui.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  child: Text(
                    'Titik Parkir Kendaraan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Catat lantai, nomor tiang/blok, foto, dan titik koordinat GPS agar mudah menemukan kendaraan.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Field Lantai & Blok Parkir
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _floorController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Lantai Parkir',
                      hintText: 'B2, P1, Lt 3',
                      prefixIcon: const Icon(Icons.layers_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _blockController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'No. Tiang / Blok',
                      hintText: 'Tiang F12, Blok C',
                      prefixIcon: const Icon(Icons.grid_view_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Pilihan Cepat Lantai
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _floorSuggestions.map((floor) {
                final isSelected = _floorController.text.trim().toUpperCase() == floor.toUpperCase();
                return ChoiceChip(
                  label: Text(floor),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _floorController.text = selected ? floor : '';
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Pilihan Cepat Prefix Blok / Tiang
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _blockSuggestions.map((sug) {
                return ActionChip(
                  label: Text('+ $sug'),
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  labelStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                  onPressed: () {
                    setState(() {
                      if (_blockController.text.isEmpty) {
                        _blockController.text = sug;
                      } else if (!_blockController.text.contains(sug.trim())) {
                        _blockController.text = '${_blockController.text} $sug'.trim();
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            // Section Foto Tiang / Blok Parkir
            const Text(
              'Foto Tiang / Blok Parkir',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),

            if (_photoPath != null && !_photoRemoved) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => ParkingPhotoViewer.show(context, imagePath: _photoPath!),
                      borderRadius: BorderRadius.circular(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.file(
                              File(_photoPath!),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                width: 60,
                                height: 60,
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(Icons.broken_image, color: Color(0xFF64748B)),
                              ),
                            ),
                            Container(
                              width: 60,
                              height: 60,
                              color: Colors.black26,
                              child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
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
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Ketuk gambar untuk memperbesar',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              InkWell(
                                onTap: _handleCapturePhoto,
                                child: const Text(
                                  'Ganti Foto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _photoRemoved = true;
                                    _photoPath = null;
                                  });
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
                      label: const Text('Buka Kamera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => _handleCapturePhoto(preferredSource: ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 17),
                      label: const Text('Pilih Galeri'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: const Color(0xFF334155),
                      ),
                      onPressed: () => _handleCapturePhoto(preferredSource: ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            // Section Titik Koordinat GPS (Drop Pin)
            const Text(
              'Titik Lokasi GPS (Drop Pin)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),

            if (_latitude != null && _longitude != null && !_coordinatesRemoved) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'Titik GPS Parkir Tersimpan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _coordinatesRemoved = true;
                              _latitude = null;
                              _longitude = null;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Text(
                              'Hapus',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Koordinat: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF047857),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.map_rounded, size: 16),
                            label: const Text('Buka di Google Maps'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: _handleOpenMap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            side: const BorderSide(color: Color(0xFF86EFAC)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final url = 'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude';
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            side: const BorderSide(color: Color(0xFF86EFAC)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isGettingLocation ? null : _handleGetLocation,
                          child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  _isGettingLocation ? 'Mengambil titik GPS...' : 'Simpan Titik GPS Parkir (Drop Pin)',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: const Color(0xFF2563EB),
                ),
                onPressed: _isGettingLocation ? null : _handleGetLocation,
              ),
            ],

            const SizedBox(height: 24),

            // Simpan Perubahan Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _handleSave,
              child: const Text(
                'Simpan Lokasi Parkir',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
