import 'dart:convert';

/// Parking rate rule configuration.
/// Defaults match typical parking rates (e.g. 1st hour Rp 4.000, next hours Rp 3.000, daily max Rp 40.000).
class ParkingRateRule {
  final int firstHourRate; // e.g. 4000
  final int hourlyRate; // e.g. 3000
  final int dailyMaxRate; // e.g. 40000 (0 means unlimited / no daily cap)
  final int gracePeriodMinutes; // e.g. 0 or 15 minutes (free exit window)

  const ParkingRateRule({
    this.firstHourRate = 4000,
    this.hourlyRate = 3000,
    this.dailyMaxRate = 40000,
    this.gracePeriodMinutes = 0,
  });

  /// Calculates estimated cost based on elapsed duration.
  ///
  /// Examples:
  /// - 15 mins (with 0 grace): 1st hour Rp 4.000
  /// - 2 hours 15 mins: 1st hour (4.000) + 2 extra hours (2 * 3.000) = Rp 10.000
  /// - 18 hours: 4.000 + 17 * 3.000 = 55.000 -> capped at dailyMax (Rp 40.000)
  /// - 26 hours (1 day + 2h): 40.000 + 4.000 + 3.000 = Rp 47.000
  int calculateCost(Duration duration) {
    if (duration.isNegative || duration.inMinutes <= 0) {
      return 0;
    }

    final totalMinutes = duration.inMinutes;

    // Grace period check
    if (gracePeriodMinutes > 0 && totalMinutes <= gracePeriodMinutes) {
      return 0;
    }

    final totalDays = totalMinutes ~/ (24 * 60);
    final remMinutes = totalMinutes % (24 * 60);

    // Full 24-hour day cost
    int dayCost;
    if (dailyMaxRate > 0) {
      dayCost = dailyMaxRate;
    } else {
      dayCost = firstHourRate + (23 * hourlyRate);
    }

    // Remainder cost within the fractional day
    int remainderCost = 0;
    if (remMinutes > 0) {
      if (gracePeriodMinutes > 0 && remMinutes <= gracePeriodMinutes) {
        remainderCost = 0;
      } else if (remMinutes <= 60) {
        remainderCost = firstHourRate;
      } else {
        final extraMinutes = remMinutes - 60;
        final extraHours = (extraMinutes / 60).ceil();
        remainderCost = firstHourRate + (extraHours * hourlyRate);
      }

      if (dailyMaxRate > 0 && remainderCost > dailyMaxRate) {
        remainderCost = dailyMaxRate;
      }
    }

    return (totalDays * dayCost) + remainderCost;
  }

  ParkingRateRule copyWith({
    int? firstHourRate,
    int? hourlyRate,
    int? dailyMaxRate,
    int? gracePeriodMinutes,
  }) {
    return ParkingRateRule(
      firstHourRate: firstHourRate ?? this.firstHourRate,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      dailyMaxRate: dailyMaxRate ?? this.dailyMaxRate,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstHourRate': firstHourRate,
      'hourlyRate': hourlyRate,
      'dailyMaxRate': dailyMaxRate,
      'gracePeriodMinutes': gracePeriodMinutes,
    };
  }

  factory ParkingRateRule.fromMap(Map<String, dynamic> map) {
    return ParkingRateRule(
      firstHourRate: (map['firstHourRate'] as num?)?.toInt() ?? 4000,
      hourlyRate: (map['hourlyRate'] as num?)?.toInt() ?? 3000,
      dailyMaxRate: (map['dailyMaxRate'] as num?)?.toInt() ?? 40000,
      gracePeriodMinutes: (map['gracePeriodMinutes'] as num?)?.toInt() ?? 0,
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
        );
      case 'truk':
        return const ParkingRateRule(
          firstHourRate: 6000,
          hourlyRate: 5000,
          dailyMaxRate: 60000,
          gracePeriodMinutes: 0,
        );
      case 'mobil':
      default:
        return const ParkingRateRule(
          firstHourRate: 4000,
          hourlyRate: 3000,
          dailyMaxRate: 40000,
          gracePeriodMinutes: 0,
        );
    }
  }
}
