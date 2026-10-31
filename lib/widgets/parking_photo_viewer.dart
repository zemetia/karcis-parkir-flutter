import 'dart:io';
import 'package:flutter/material.dart';

class ParkingPhotoViewer extends StatefulWidget {
  final String imagePath;
  final String? title;

  const ParkingPhotoViewer({
    super.key,
    required this.imagePath,
    this.title,
  });

  static void show(BuildContext context, {required String imagePath, String? title}) {
    showDialog(
      context: context,
      builder: (ctx) => ParkingPhotoViewer(imagePath: imagePath, title: title),
    );
  }

  @override
  State<ParkingPhotoViewer> createState() => _ParkingPhotoViewerState();
}

class _ParkingPhotoViewerState extends State<ParkingPhotoViewer> {
  int _quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);
    final exists = file.existsSync();

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0F172A),
              child: Row(
                children: [
                  Icon(
                    widget.title != null &&
                            (widget.title!.toLowerCase().contains('struk') ||
                                widget.title!.toLowerCase().contains('karcis'))
                        ? Icons.receipt_long_rounded
                        : Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title ?? 'Foto Lampiran Parkir',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
                    tooltip: 'Putar 90°',
                    onPressed: () {
                      setState(() {
                        _quarterTurns = (_quarterTurns + 1) % 4;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.8,
                maxScale: 4.0,
                child: exists
                    ? RotatedBox(
                        quarterTurns: _quarterTurns,
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                          cacheWidth: 2048,
                          errorBuilder: (ctx, err, stack) => const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'Gagal memuat file foto',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'File foto tidak ditemukan di penyimpanan',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.zoom_in, color: Colors.white60, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    widget.title != null &&
                            (widget.title!.toLowerCase().contains('struk') ||
                                widget.title!.toLowerCase().contains('karcis'))
                        ? 'Cubit untuk zoom • Ketuk putar jika miring'
                        : 'Cubit untuk zoom • Ketuk putar untuk rotasi 90°',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
