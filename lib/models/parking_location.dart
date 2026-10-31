import 'dart:convert';
import 'parking_rate_rule.dart';

/// Represents a parking location configuration with customizable rules per vehicle type.
class ParkingLocation {
  final String id;
  final String name;
  final String category;
  final String? address;
  final bool isDefaultTemplate;
  final Map<String, ParkingRateRule> rates;

  const ParkingLocation({
    required this.id,
    required this.name,
    this.category = 'Mall / Pusat Belanja',
    this.address,
    this.isDefaultTemplate = false,
    required this.rates,
  });

  /// Get rate rule for a vehicle type (e.g. 'Mobil', 'Motor', 'Truk', 'Lainnya')
  ParkingRateRule getRateFor(String vehicleType) {
    if (rates.containsKey(vehicleType)) {
      return rates[vehicleType]!;
    }
    // Case-insensitive lookup
    for (final entry in rates.entries) {
      if (entry.key.toLowerCase() == vehicleType.toLowerCase()) {
        return entry.value;
      }
    }
    // Fallback to Mobil or default
    return rates['Mobil'] ?? ParkingRateRule.defaultFor(vehicleType);
  }

  ParkingLocation copyWith({
    String? id,
    String? name,
    String? category,
    String? address,
    bool? isDefaultTemplate,
    Map<String, ParkingRateRule>? rates,
  }) {
    return ParkingLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      isDefaultTemplate: isDefaultTemplate ?? this.isDefaultTemplate,
      rates: rates ?? this.rates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'address': address,
      'isDefaultTemplate': isDefaultTemplate ? 1 : 0,
      'rates': rates.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  factory ParkingLocation.fromMap(Map<String, dynamic> map) {
    final rawRates = map['rates'];
    final ratesMap = <String, ParkingRateRule>{};

    if (rawRates is Map) {
      rawRates.forEach((key, value) {
        if (value is Map) {
          ratesMap[key.toString()] =
              ParkingRateRule.fromMap(Map<String, dynamic>.from(value));
        }
      });
    }

    // Ensure at least Mobil and Motor are present
    if (!ratesMap.containsKey('Mobil')) {
      ratesMap['Mobil'] = ParkingRateRule.defaultFor('Mobil');
    }
    if (!ratesMap.containsKey('Motor')) {
      ratesMap['Motor'] = ParkingRateRule.defaultFor('Motor');
    }

    final isDefault = (map['isDefaultTemplate'] is bool)
        ? map['isDefaultTemplate'] as bool
        : ((map['isDefaultTemplate'] as num?)?.toInt() ?? 0) == 1;

    return ParkingLocation(
      id: map['id'] as String,
      name: map['name'] as String,
      category: (map['category'] as String?) ?? 'Mall / Pusat Belanja',
      address: map['address'] as String?,
      isDefaultTemplate: isDefault,
      rates: ratesMap,
    );
  }

  String toJson() => json.encode(toMap());

  factory ParkingLocation.fromJson(String source) =>
      ParkingLocation.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Predefined Indonesian parking templates
  static List<ParkingLocation> get defaultTemplates => [
        ParkingLocation(
          id: 'mall_ptc',
          name: 'Mall PTC (Pakuwon)',
          category: 'Mall / Pusat Belanja',
          address: 'Jl. Mayjend Jonosewojo No.2, Surabaya Barat',
          isDefaultTemplate: true,
          rates: {
            'Motor': const ParkingRateRule(
              firstHourRate: 2000,
              hourlyRate: 2000,
              dailyMaxRate: 20000,
              gracePeriodMinutes: 10,
              initialHours: 1,
              initialRate: 2000,
            ),
            'Mobil': const ParkingRateRule(
              firstHourRate: 5000,
              hourlyRate: 4000,
              dailyMaxRate: 60000,
              gracePeriodMinutes: 10,
              initialHours: 1,
              initialRate: 5000,
              tiers: [
                RateTier(afterHours: 4, hourlyRate: 6000),
              ],
            ),
            'Truk': const ParkingRateRule(
              firstHourRate: 10000,
              hourlyRate: 8000,
              dailyMaxRate: 80000,
              gracePeriodMinutes: 10,
              initialHours: 1,
              initialRate: 10000,
            ),
          },
        ),
        ParkingLocation(
          id: 'mall_gi',
          name: 'Grand Indonesia',
          category: 'Mall / Pusat Belanja',
          address: 'Jl. M.H. Thamrin No.1, Jakarta Pusat',
          isDefaultTemplate: true,
          rates: {
            'Motor': const ParkingRateRule(
              firstHourRate: 2000,
              hourlyRate: 2000,
              dailyMaxRate: 25000,
              gracePeriodMinutes: 15,
              initialHours: 1,
              initialRate: 2000,
            ),
            'Mobil': const ParkingRateRule(
              firstHourRate: 5000,
              hourlyRate: 4000,
              dailyMaxRate: 60000,
              gracePeriodMinutes: 15,
              initialHours: 1,
              initialRate: 5000,
              tiers: [
                RateTier(afterHours: 5, hourlyRate: 5000),
              ],
            ),
            'Truk': const ParkingRateRule(
              firstHourRate: 12000,
              hourlyRate: 10000,
              dailyMaxRate: 100000,
              gracePeriodMinutes: 15,
              initialHours: 1,
              initialRate: 12000,
            ),
          },
        ),
        ParkingLocation(
          id: 'mall_tp',
          name: 'Tunjungan Plaza (TP)',
          category: 'Mall / Pusat Belanja',
          address: 'Jl. Embong Malang No.7-21, Surabaya',
          isDefaultTemplate: true,
          rates: {
            'Motor': const ParkingRateRule(
              firstHourRate: 3000,
              hourlyRate: 2000,
              dailyMaxRate: 25000,
              gracePeriodMinutes: 10,
              initialHours: 2,
              initialRate: 3000,
            ),
            'Mobil': const ParkingRateRule(
              firstHourRate: 5000,
              hourlyRate: 4000,
              dailyMaxRate: 50000,
              gracePeriodMinutes: 10,
              initialHours: 1,
              initialRate: 5000,
            ),
          },
        ),
        ParkingLocation(
          id: 'stasiun_krl',
          name: 'Stasiun Kereta / KRL',
          category: 'Stasiun & Terminal',
          address: 'Parkir Stasiun Commuter Line & Kereta Api',
          isDefaultTemplate: true,
          rates: {
            'Motor': const ParkingRateRule(
              firstHourRate: 3000,
              hourlyRate: 1000,
              dailyMaxRate: 15000,
              gracePeriodMinutes: 10,
              initialHours: 2,
              initialRate: 3000,
            ),
            'Mobil': const ParkingRateRule(
              firstHourRate: 6000,
              hourlyRate: 3000,
              dailyMaxRate: 40000,
              gracePeriodMinutes: 10,
              initialHours: 1,
              initialRate: 6000,
            ),
          },
        ),
        ParkingLocation(
          id: 'bandara_soetta',
          name: 'Bandara Soekarno-Hatta',
          category: 'Bandara',
          address: 'Terminal 1, 2, 3 & Gedung Parkir Inap',
          isDefaultTemplate: true,
          rates: {
            'Motor': const ParkingRateRule(
              firstHourRate: 5000,
              hourlyRate: 2000,
              dailyMaxRate: 30000,
              gracePeriodMinutes: 15,
              initialHours: 4,
              initialRate: 5000,
            ),
            'Mobil': const ParkingRateRule(
              firstHourRate: 10000,
              hourlyRate: 6000,
              dailyMaxRate: 120000,
              gracePeriodMinutes: 15,
              initialHours: 1,
              initialRate: 10000,
              tiers: [
                RateTier(afterHours: 4, hourlyRate: 10000),
              ],
            ),
          },
        ),
        ParkingLocation(
          id: 'pasar_flat',
          name: 'Pasar & Wisata (Sekali Bayar)',
          category: 'Pasar & Pinggir Jalan',
          address: 'Area Parkir Flat / Sekali Masuk',
          isDefaultTemplate: true,
          rates: {
            'Motor': const ParkingRateRule(
              isFlatRate: true,
              flatRate: 2000,
              firstHourRate: 2000,
              hourlyRate: 0,
              dailyMaxRate: 2000,
            ),
            'Mobil': const ParkingRateRule(
              isFlatRate: true,
              flatRate: 5000,
              firstHourRate: 5000,
              hourlyRate: 0,
              dailyMaxRate: 5000,
            ),
            'Truk': const ParkingRateRule(
              isFlatRate: true,
              flatRate: 10000,
              firstHourRate: 10000,
              hourlyRate: 0,
              dailyMaxRate: 10000,
            ),
          },
        ),
        ParkingLocation(
          id: 'rs_publik',
          name: 'Rumah Sakit & Fasilitas Umum',
          category: 'Fasilitas Umum',
          address: 'Area Parkir RS & Layanan Publik',
          isDefaultTemplate: true,
          rates: {
            'Motor': const ParkingRateRule(
              firstHourRate: 2000,
              hourlyRate: 1000,
              dailyMaxRate: 15000,
              gracePeriodMinutes: 15,
              initialHours: 1,
              initialRate: 2000,
            ),
            'Mobil': const ParkingRateRule(
              firstHourRate: 4000,
              hourlyRate: 2500,
              dailyMaxRate: 35000,
              gracePeriodMinutes: 15,
              initialHours: 1,
              initialRate: 4000,
            ),
          },
        ),
      ];
}
