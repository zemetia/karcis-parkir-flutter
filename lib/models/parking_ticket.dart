import 'dart:convert';

class ParkingTicket {
  final String id;
  final String rawCode;
  final String format; // e.g. QR_CODE, CODE_128, MANUAL, etc.
  final String? plateNumber;
  final String vehicleType; // Mobil, Motor, Truk, Lainnya
  final String? locationName;
  final DateTime entryTime;
  final String? notes;
  final DateTime createdAt;
  final double firstReminderHours; // Default 11 (1 jam sebelum 12 jam)
  final double secondReminderHours; // Default 24 (24 jam)
  final List<double> reminderHours; // Dynamic list of reminder hours
  final bool isCompleted;

  ParkingTicket({
    required this.id,
    required this.rawCode,
    this.format = 'QR_CODE',
    this.plateNumber,
    this.vehicleType = 'Mobil',
    this.locationName,
    required this.entryTime,
    this.notes,
    DateTime? createdAt,
    double? firstReminderHours,
    double? secondReminderHours,
    List<double>? reminderHours,
    this.isCompleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        reminderHours = _normalizeReminderHours(
          reminderHours,
          firstReminderHours ?? 11.0,
          secondReminderHours ?? 24.0,
        ),
        firstReminderHours = firstReminderHours ??
            (reminderHours != null && reminderHours.isNotEmpty
                ? reminderHours.first
                : 11.0),
        secondReminderHours = secondReminderHours ??
            (reminderHours != null && reminderHours.length > 1
                ? reminderHours[1]
                : (reminderHours != null && reminderHours.isNotEmpty
                    ? reminderHours.first
                    : 24.0));

  static List<double> _normalizeReminderHours(
    List<double>? hours,
    double fallbackFirst,
    double fallbackSecond,
  ) {
    if (hours != null && hours.isNotEmpty) {
      final list = hours.toSet().toList()..sort();
      return list;
    }
    final fallback = {fallbackFirst, fallbackSecond}.toList()..sort();
    return fallback;
  }

  Duration get durationParked => DateTime.now().difference(entryTime);

  String get durationFormatted {
    final duration = durationParked;
    if (duration.isNegative) {
      return '0 mnt';
    }
    final totalHours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (totalHours > 0) {
      return '$totalHours jam $minutes mnt';
    } else {
      return '$minutes mnt';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawCode': rawCode,
      'format': format,
      'plateNumber': plateNumber,
      'vehicleType': vehicleType,
      'locationName': locationName,
      'entryTime': entryTime.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'firstReminderHours': reminderHours.isNotEmpty ? reminderHours.first : firstReminderHours,
      'secondReminderHours': reminderHours.length > 1 ? reminderHours[1] : secondReminderHours,
      'reminderHours': reminderHours.join(','),
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory ParkingTicket.fromMap(Map<String, dynamic> map) {
    final first = (map['firstReminderHours'] as num?)?.toDouble() ?? 11.0;
    final second = (map['secondReminderHours'] as num?)?.toDouble() ?? 24.0;
    List<double>? parsedHours;
    final rawHoursStr = map['reminderHours'] as String?;
    if (rawHoursStr != null && rawHoursStr.trim().isNotEmpty) {
      parsedHours = rawHoursStr
          .split(',')
          .map((s) => double.tryParse(s.trim()))
          .whereType<double>()
          .toList();
      parsedHours.sort();
    }

    return ParkingTicket(
      id: map['id'] as String,
      rawCode: map['rawCode'] as String,
      format: (map['format'] as String?) ?? 'QR_CODE',
      plateNumber: map['plateNumber'] as String?,
      vehicleType: (map['vehicleType'] as String?) ?? 'Mobil',
      locationName: map['locationName'] as String?,
      entryTime: DateTime.parse(map['entryTime'] as String),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      firstReminderHours: first,
      secondReminderHours: second,
      reminderHours: parsedHours,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
    );
  }

  String toJson() => json.encode(toMap());

  factory ParkingTicket.fromJson(String source) =>
      ParkingTicket.fromMap(json.decode(source) as Map<String, dynamic>);

  ParkingTicket copyWith({
    String? id,
    String? rawCode,
    String? format,
    String? plateNumber,
    String? vehicleType,
    String? locationName,
    DateTime? entryTime,
    String? notes,
    DateTime? createdAt,
    double? firstReminderHours,
    double? secondReminderHours,
    List<double>? reminderHours,
    bool? isCompleted,
  }) {
    return ParkingTicket(
      id: id ?? this.id,
      rawCode: rawCode ?? this.rawCode,
      format: format ?? this.format,
      plateNumber: plateNumber ?? this.plateNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      locationName: locationName ?? this.locationName,
      entryTime: entryTime ?? this.entryTime,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      firstReminderHours: firstReminderHours ?? this.firstReminderHours,
      secondReminderHours: secondReminderHours ?? this.secondReminderHours,
      reminderHours: reminderHours ?? this.reminderHours,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
