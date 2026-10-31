import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parking_location.dart';
import '../models/parking_rate_rule.dart';

class ParkingLocationService {
  static const String keyCustomLocations = 'parking_locations_custom_list';
  final SharedPreferences _prefs;

  List<ParkingLocation> _locations = [];

  ParkingLocationService(this._prefs) {
    _loadLocations();
  }

  void _loadLocations() {
    final rawJson = _prefs.getString(keyCustomLocations);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = json.decode(rawJson) as List;
        _locations = decoded
            .map((item) =>
                ParkingLocation.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        _locations = List.from(ParkingLocation.defaultTemplates);
      }
    } else {
      _locations = List.from(ParkingLocation.defaultTemplates);
    }
  }

  List<ParkingLocation> get locations => List.unmodifiable(_locations);

  /// Find a location by full or partial name (case-insensitive)
  /// e.g. "PTC" or "Mall PTC" will match "Mall PTC (Pakuwon)"
  ParkingLocation? findLocationByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final query = name.trim().toLowerCase();

    // 1. Exact match
    for (final loc in _locations) {
      if (loc.name.toLowerCase() == query) {
        return loc;
      }
    }

    // 2. Contains match (full phrase)
    // e.g. query "mall ptc" is contained in "mall ptc (pakuwon)"
    for (final loc in _locations) {
      final locLower = loc.name.toLowerCase();
      if (locLower.contains(query) || query.contains(locLower)) {
        return loc;
      }
    }

    // 3. Known specific aliases / word boundary match
    // e.g. "PTC" matches "Mall PTC (Pakuwon)", "TP" matches "Tunjungan Plaza (TP)"
    for (final loc in _locations) {
      final regExp = RegExp(r'\b' + RegExp.escape(query) + r'\b', caseSensitive: false);
      if (regExp.hasMatch(loc.name)) {
        if (query.length >= 3 || loc.name.toLowerCase().contains('($query)')) {
          return loc;
        }
      }
    }

    return null;
  }

  /// Get rate rule for a specific location and vehicle type
  ParkingRateRule? getRateRule(String? locationName, String vehicleType) {
    final loc = findLocationByName(locationName);
    if (loc != null) {
      return loc.getRateFor(vehicleType);
    }
    return null;
  }

  /// Save or update a location
  Future<bool> saveLocation(ParkingLocation location) async {
    final index = _locations.indexWhere((l) => l.id == location.id);
    if (index >= 0) {
      _locations[index] = location;
    } else {
      _locations.add(location);
    }
    return await _persist();
  }

  /// Delete a location by its ID
  Future<bool> deleteLocation(String id) async {
    _locations.removeWhere((l) => l.id == id);
    return await _persist();
  }

  /// Reset all locations back to default templates
  Future<bool> resetToDefaults() async {
    _locations = List.from(ParkingLocation.defaultTemplates);
    return await _prefs.remove(keyCustomLocations);
  }

  Future<bool> _persist() async {
    final jsonList = _locations.map((l) => l.toMap()).toList();
    return await _prefs.setString(keyCustomLocations, json.encode(jsonList));
  }
}
