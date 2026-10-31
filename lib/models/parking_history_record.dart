import 'dart:convert';

/// Record representing a completed parking session for history and reimbursement tracking.
class ParkingHistoryRecord {
  final String id;
  final String ticketId;
  final String rawCode;
  final String format;
  final String? plateNumber;
  final String vehicleType;
  final String? locationName;
  final DateTime entryTime;
  final DateTime exitTime;
  final int durationMinutes;
  final String durationFormatted;
  final int cost; // Nominal biaya dalam Rupiah
  final String? notes;
  final DateTime createdAt;

  ParkingHistoryRecord({
    required this.id,
    required this.ticketId,
    required this.rawCode,
    this.format = 'QR_CODE',
    this.plateNumber,
    this.vehicleType = 'Mobil',
    this.locationName,
    required this.entryTime,
    required this.exitTime,
    required this.durationMinutes,
    required this.durationFormatted,
    required this.cost,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticketId': ticketId,
      'rawCode': rawCode,
      'format': format,
      'plateNumber': plateNumber,
      'vehicleType': vehicleType,
      'locationName': locationName,
      'entryTime': entryTime.toIso8601String(),
      'exitTime': exitTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'durationFormatted': durationFormatted,
      'cost': cost,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ParkingHistoryRecord.fromMap(Map<String, dynamic> map) {
    return ParkingHistoryRecord(
      id: map['id'] as String,
      ticketId: map['ticketId'] as String,
      rawCode: map['rawCode'] as String,
      format: (map['format'] as String?) ?? 'QR_CODE',
      plateNumber: map['plateNumber'] as String?,
      vehicleType: (map['vehicleType'] as String?) ?? 'Mobil',
      locationName: map['locationName'] as String?,
      entryTime: DateTime.parse(map['entryTime'] as String),
      exitTime: DateTime.parse(map['exitTime'] as String),
      durationMinutes: (map['durationMinutes'] as num).toInt(),
      durationFormatted: (map['durationFormatted'] as String?) ?? '',
      cost: (map['cost'] as num).toInt(),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ParkingHistoryRecord.fromJson(String source) =>
      ParkingHistoryRecord.fromMap(json.decode(source) as Map<String, dynamic>);
}
