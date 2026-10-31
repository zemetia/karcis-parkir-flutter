import 'dart:convert';

/// Rate tier for multi-stage parking rules.
/// e.g. afterHours = 4, hourlyRate = 6000 means hours after hour 4 cost Rp 6.000/hour.
class RateTier {
  final int afterHours; // e.g. 2, 4, 6...
  final int hourlyRate; // e.g. 5000, 6000

  const RateTier({
    required this.afterHours,
    required this.hourlyRate,
  });

  RateTier copyWith({
    int? afterHours,
    int? hourlyRate,
  }) {
    return RateTier(
      afterHours: afterHours ?? this.afterHours,
      hourlyRate: hourlyRate ?? this.hourlyRate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'afterHours': afterHours,
      'hourlyRate': hourlyRate,
    };
  }

  factory RateTier.fromMap(Map<String, dynamic> map) {
    return RateTier(
      afterHours: (map['afterHours'] as num?)?.toInt() ?? 0,
      hourlyRate: (map['hourlyRate'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory RateTier.fromJson(String source) =>
      RateTier.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// Parking rate rule configuration.
/// Supports standard hourly rates, flat rates (sekali bayar), and tiered step rates (e.g. Mall PTC).
class ParkingRateRule {
  final int firstHourRate; // e.g. 4000 (kept for backwards compatibility)
  final int hourlyRate; // e.g. 3000
  final int dailyMaxRate; // e.g. 40000 (0 means unlimited / no daily cap)
  final int gracePeriodMinutes; // e.g. 0 or 15 minutes (free exit window)

  // Advanced flexible pricing properties
  final bool isFlatRate; // true: sekali bayar
  final int flatRate; // nominal jika flat rate (e.g. 2000)
  final int initialHours; // durasi jam pertama (default 1)
  final int? initialRate; // tarif untuk initialHours pertama (fallback to firstHourRate)
  final List<RateTier> tiers; // jenjang bertingkat setelah X jam

  const ParkingRateRule({
    this.firstHourRate = 4000,
    this.hourlyRate = 3000,
    this.dailyMaxRate = 40000,
    this.gracePeriodMinutes = 0,
    this.isFlatRate = false,
    this.flatRate = 0,
    this.initialHours = 1,
    this.initialRate,
    this.tiers = const [],
  });

  /// The effective rate for the initial block of hours.
  int get effectiveInitialRate => initialRate ?? firstHourRate;

  /// The effective duration of the initial block of hours.
  int get effectiveInitialHours => initialHours > 0 ? initialHours : 1;

  /// Calculates estimated cost based on elapsed duration.
  int calculateCost(Duration duration) {
    if (duration.isNegative || duration.inMinutes <= 0) {
      return 0;
    }

    final totalMinutes = duration.inMinutes;

    // Grace period check
    if (gracePeriodMinutes > 0 && totalMinutes <= gracePeriodMinutes) {
      return 0;
    }

    // Pure flat rate (sekali bayar)
    if (isFlatRate) {
      final effectiveFlat = flatRate > 0 ? flatRate : firstHourRate;
      final totalDays = totalMinutes ~/ (24 * 60);
      final remMinutes = totalMinutes % (24 * 60);
      final dayUnits = totalDays + (remMinutes > gracePeriodMinutes ? 1 : 0);
      return (dayUnits <= 0 ? 1 : dayUnits) * effectiveFlat;
    }

    final totalDays = totalMinutes ~/ (24 * 60);
    final remMinutes = totalMinutes % (24 * 60);

    // Calculate fractional day cost
    int calculateDayCost(int minutes) {
      if (minutes <= 0) return 0;
      if (gracePeriodMinutes > 0 && minutes <= gracePeriodMinutes) return 0;

      final totalHours = (minutes / 60.0).ceil();
      if (totalHours <= 0) return 0;

      final baseHours = effectiveInitialHours;
      final baseRate = effectiveInitialRate;

      int cost = baseRate;
      if (totalHours <= baseHours) {
        if (dailyMaxRate > 0 && cost > dailyMaxRate) cost = dailyMaxRate;
        return cost;
      }

      // Process tiers
      final sortedTiers = List<RateTier>.from(tiers)
        ..sort((a, b) => b.afterHours.compareTo(a.afterHours));

      for (int h = baseHours + 1; h <= totalHours; h++) {
        int hourCost = hourlyRate;
        for (final tier in sortedTiers) {
          if (h > tier.afterHours) {
            hourCost = tier.hourlyRate;
            break;
          }
        }
        cost += hourCost;
      }

      if (dailyMaxRate > 0 && cost > dailyMaxRate) {
        cost = dailyMaxRate;
      }
      return cost;
    }

    // Full 24-hour day cost
    int dayCost;
    if (dailyMaxRate > 0) {
      dayCost = dailyMaxRate;
    } else {
      dayCost = calculateDayCost(24 * 60);
    }

    final remainderCost = calculateDayCost(remMinutes);

    return (totalDays * dayCost) + remainderCost;
  }

  /// Human-readable explanation of how the tariff is calculated.
  String get summaryDescription {
    if (isFlatRate) {
      final rate = flatRate > 0 ? flatRate : firstHourRate;
      return 'Sekali Bayar: Rp ${_formatNumber(rate)}';
    }

    final baseH = effectiveInitialHours;
    final baseR = effectiveInitialRate;
    final parts = <String>[];

    if (baseH == 1) {
      parts.add('1 jam pertama Rp ${_formatNumber(baseR)}');
    } else {
      parts.add('$baseH jam pertama Rp ${_formatNumber(baseR)}');
    }

    if (tiers.isEmpty) {
      parts.add('+Rp ${_formatNumber(hourlyRate)}/jam');
    } else {
      final sorted = List<RateTier>.from(tiers)
        ..sort((a, b) => a.afterHours.compareTo(b.afterHours));
      final firstTier = sorted.first;
      parts.add('s/d jam ke-${firstTier.afterHours} +Rp ${_formatNumber(hourlyRate)}/jam');
      for (int i = 0; i < sorted.length; i++) {
        final t = sorted[i];
        final nextLimit = (i + 1 < sorted.length) ? 's/d jam ke-${sorted[i + 1].afterHours} ' : '';
        parts.add('setelah ${t.afterHours} jam $nextLimit+Rp ${_formatNumber(t.hourlyRate)}/jam');
      }
    }

    if (dailyMaxRate > 0) {
      parts.add('maks Rp ${_formatNumber(dailyMaxRate)}/hari');
    }

    if (gracePeriodMinutes > 0) {
      parts.add('bebas biaya $gracePeriodMinutes mnt');
    }

    return parts.join(' • ');
  }

  static String _formatNumber(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  ParkingRateRule copyWith({
    int? firstHourRate,
    int? hourlyRate,
    int? dailyMaxRate,
    int? gracePeriodMinutes,
    bool? isFlatRate,
    int? flatRate,
    int? initialHours,
    int? initialRate,
    List<RateTier>? tiers,
  }) {
    final effectiveFirst = initialRate ?? firstHourRate ?? this.firstHourRate;
    return ParkingRateRule(
      firstHourRate: effectiveFirst,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      dailyMaxRate: dailyMaxRate ?? this.dailyMaxRate,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      isFlatRate: isFlatRate ?? this.isFlatRate,
      flatRate: flatRate ?? this.flatRate,
      initialHours: initialHours ?? this.initialHours,
      initialRate: initialRate ?? this.initialRate ?? effectiveFirst,
      tiers: tiers ?? this.tiers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstHourRate': initialRate ?? firstHourRate,
      'hourlyRate': hourlyRate,
      'dailyMaxRate': dailyMaxRate,
      'gracePeriodMinutes': gracePeriodMinutes,
      'isFlatRate': isFlatRate ? 1 : 0,
      'flatRate': flatRate,
      'initialHours': initialHours,
      'initialRate': initialRate ?? firstHourRate,
      'tiers': tiers.map((t) => t.toMap()).toList(),
    };
  }

  factory ParkingRateRule.fromMap(Map<String, dynamic> map) {
    List<RateTier> parsedTiers = [];
    if (map['tiers'] is List) {
      parsedTiers = (map['tiers'] as List)
          .map((t) => RateTier.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList();
    }

    final first = (map['firstHourRate'] as num?)?.toInt() ?? 4000;
    final initRate = (map['initialRate'] as num?)?.toInt() ?? first;
    final initHours = (map['initialHours'] as num?)?.toInt() ?? 1;
    final isFlat = (map['isFlatRate'] is bool)
        ? map['isFlatRate'] as bool
        : ((map['isFlatRate'] as num?)?.toInt() ?? 0) == 1;

    return ParkingRateRule(
      firstHourRate: first,
      hourlyRate: (map['hourlyRate'] as num?)?.toInt() ?? 3000,
      dailyMaxRate: (map['dailyMaxRate'] as num?)?.toInt() ?? 40000,
      gracePeriodMinutes: (map['gracePeriodMinutes'] as num?)?.toInt() ?? 0,
      isFlatRate: isFlat,
      flatRate: (map['flatRate'] as num?)?.toInt() ?? 0,
      initialHours: initHours,
      initialRate: initRate,
      tiers: parsedTiers,
    );
  }

  String toJson() => json.encode(toMap());

  factory ParkingRateRule.fromJson(String source) =>
      ParkingRateRule.fromMap(json.decode(source) as Map<String, dynamic>);

  static ParkingRateRule defaultFor(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'motor':
        return const ParkingRateRule(
          firstHourRate: 2000,
          hourlyRate: 1000,
          dailyMaxRate: 20000,
          gracePeriodMinutes: 0,
          initialHours: 1,
          initialRate: 2000,
        );
      case 'truk':
        return const ParkingRateRule(
          firstHourRate: 6000,
          hourlyRate: 5000,
          dailyMaxRate: 60000,
          gracePeriodMinutes: 0,
          initialHours: 1,
          initialRate: 6000,
        );
      case 'mobil':
      default:
        return const ParkingRateRule(
          firstHourRate: 4000,
          hourlyRate: 3000,
          dailyMaxRate: 40000,
          gracePeriodMinutes: 0,
          initialHours: 1,
          initialRate: 4000,
        );
    }
  }
}
