import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoService {
  static String? testMockImagePath;
  static String? testMockTicketImagePath;
  static final ImagePicker _picker = ImagePicker();

  /// Prompt user to choose between Camera or Gallery, then capture/pick the photo
  static Future<String?> pickPillarPhoto(
    BuildContext context, {
    ImageSource? preferredSource,
  }) async {
    if (testMockImagePath != null) {
      return testMockImagePath;
    }

    ImageSource? source = preferredSource;
    source ??= await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
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
              const Text(
                'Ambil Foto Tiang / Blok Parkir',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Foto nomor tiang atau tanda blok (misal: B2 - Tiang F12) agar mudah ditemukan.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Buka Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ambil foto tiang parkir langsung'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569)),
                ),
                title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Gunakan foto yang sudah ada di galeri'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

    if (source == null) return null;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null) return null;

      // Copy file to persistent application storage
      final appDir = await getApplicationDocumentsDirectory();
      final targetDirectory = Directory(p.join(appDir.path, 'parking_photos'));
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
      }

      final fileName =
          'pillar_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path).isNotEmpty ? p.extension(picked.path) : ".jpg"}';
      final persistentPath = p.join(targetDirectory.path, fileName);
      final savedFile = await File(picked.path).copy(persistentPath);

      return savedFile.path;
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      return null;
    }
  }

  /// Prompt user to choose between Camera or Gallery, then capture/pick the physical ticket receipt
  static Future<String?> pickTicketPhoto(
    BuildContext context, {
    ImageSource? preferredSource,
  }) async {
    if (testMockTicketImagePath != null) {
      return testMockTicketImagePath;
    }

    ImageSource? source = preferredSource;
    source ??= await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
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
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Foto Bukti Fisik Karcis Kertas',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simpan foto fisik lembar karcis sebagai lampiran. Jika tiket kertas hilang/tercecer, foto struk fisik sering kali diterima oleh pos sekuriti/loket untuk verifikasi nomor tiket sehingga terhindar dari denda tiket hilang (Rp 25.000 - Rp 50.000).',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Buka Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ambil foto lembar karcis sekarang'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF475569)),
                ),
                title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Gunakan foto struk yang sudah ada di galeri'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

    if (source == null) return null;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked == null) return null;

      // Copy file to persistent application storage
      Directory appDir;
      try {
        appDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        appDir = await getTemporaryDirectory();
      }
      final targetDirectory = Directory(p.join(appDir.path, 'ticket_photos'));
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: true);
      }

      final fileName =
          'ticket_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path).isNotEmpty ? p.extension(picked.path) : ".jpg"}';
      final persistentPath = p.join(targetDirectory.path, fileName);
      final savedFile = await File(picked.path).copy(persistentPath);

      return savedFile.path;
    } catch (e) {
      debugPrint('Error capturing physical ticket photo: $e');
      return null;
    }
  }

  /// Delete persistent photo file from storage
  static Future<void> deletePhotoFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting photo file: $e');
    }
  }
}
