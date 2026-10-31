import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? errorMessage;
  final bool isSuccess;
  final bool isPermissionDeniedForever;

  LocationResult.success({required this.latitude, required this.longitude})
      : errorMessage = null,
        isSuccess = true,
        isPermissionDeniedForever = false;

  LocationResult.failure(
    this.errorMessage, {
    this.isPermissionDeniedForever = false,
  })  : latitude = null,
        longitude = null,
        isSuccess = false;
}

class LocationService {
  static LocationResult? testMockResult;
  static Future<bool> Function(Uri uri)? mockLaunchUrlHandler;

  /// Check GPS service, request permissions, and acquire current device coordinates.
  static Future<LocationResult> getCurrentCoordinates() async {
    if (testMockResult != null) {
      return testMockResult!;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          'Layanan GPS belum aktif. Silakan aktifkan lokasi perangkat Anda.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          return LocationResult.failure(
            'Izin lokasi ditolak permanen. Buka Pengaturan aplikasi untuk memberikan izin lokasi.',
            isPermissionDeniedForever: true,
          );
        }
        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            'Izin akses lokasi ditolak. Tidak dapat mengambil titik GPS.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          'Izin lokasi ditolak permanen. Buka Pengaturan aplikasi untuk memberikan izin lokasi.',
          isPermissionDeniedForever: true,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('LocationService error: $e');
      // Attempt fallback to last known location if available
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationResult.success(
            latitude: last.latitude,
            longitude: last.longitude,
          );
        }
      } catch (_) {}

      return LocationResult.failure(
        'Gagal mendapatkan titik GPS. Pastikan berada di area dengan sinyal GPS baik.',
      );
    }
  }

  /// Open application settings so user can grant location permission manually
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  /// Open device location service settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
      return false;
    }
  }

  /// Open coordinates directly in Google Maps application or browser navigation
  static Future<bool> openGoogleMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final queryLabel = Uri.encodeComponent(label ?? 'Kendaraan Saya');
    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($queryLabel)');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

    if (mockLaunchUrlHandler != null) {
      return await mockLaunchUrlHandler!(geoUri);
    }

    try {
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch geoUri: $e');
    }

    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch webUri via canLaunchUrl: $e');
    }

    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Fallback launchUrl failed: $e');
      return false;
    }
  }
}
