import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';

void main() {
  group('ParkingTicket Model Tests', () {
    test('Serializes to and from Map accurately', () {
      final now = DateTime.now();
      final ticket = ParkingTicket(
        id: 'test-uuid-1',
        rawCode: 'PRK-998822',
        format: 'QR_CODE',
        plateNumber: 'B 1234 XYZ',
        vehicleType: 'Mobil',
        locationName: 'Grand Indonesia B1',
        entryTime: now,
        notes: 'Pilar A12',
        firstReminderHours: 11.0,
        secondReminderHours: 24.0,
        isCompleted: false,
      );

      final map = ticket.toMap();
      final restored = ParkingTicket.fromMap(map);

      expect(restored.id, 'test-uuid-1');
      expect(restored.rawCode, 'PRK-998822');
      expect(restored.plateNumber, 'B 1234 XYZ');
      expect(restored.vehicleType, 'Mobil');
      expect(restored.locationName, 'Grand Indonesia B1');
      expect(restored.firstReminderHours, 11.0);
      expect(restored.secondReminderHours, 24.0);
      expect(restored.reminderHours, [11.0, 24.0]);
      expect(restored.isCompleted, isFalse);
    });

    test('Serializes custom reminder hours list accurately', () {
      final now = DateTime.now();
      final ticket = ParkingTicket(
        id: 'test-custom-hours',
        rawCode: 'PRK-CUSTOM-1',
        entryTime: now,
        reminderHours: [2.0, 6.0, 11.0, 24.0],
      );

      final map = ticket.toMap();
      final restored = ParkingTicket.fromMap(map);

      expect(restored.reminderHours, [2.0, 6.0, 11.0, 24.0]);
      expect(restored.firstReminderHours, 2.0);
      expect(restored.secondReminderHours, 6.0);
    });

    test('durationFormatted formats elapsed time correctly', () {
      final now = DateTime.now();

      // Case 1: 45 minutes ago
      final t1 = ParkingTicket(
        id: '1',
        rawCode: 'code1',
        entryTime: now.subtract(const Duration(minutes: 45)),
      );
      expect(t1.durationFormatted, '45 mnt');

      // Case 2: 2 hours 15 minutes ago
      final t2 = ParkingTicket(
        id: '2',
        rawCode: 'code2',
        entryTime: now.subtract(const Duration(hours: 2, minutes: 15)),
      );
      expect(t2.durationFormatted, '2 jam 15 mnt');

      // Case 3: 11 hours 0 minutes ago
      final t3 = ParkingTicket(
        id: '3',
        rawCode: 'code3',
        entryTime: now.subtract(const Duration(hours: 11)),
      );
      expect(t3.durationFormatted, '11 jam 0 mnt');

      // Case 4: Future time / slight clock skew
      final t4 = ParkingTicket(
        id: '4',
        rawCode: 'code4',
        entryTime: now.add(const Duration(minutes: 5)),
      );
      expect(t4.durationFormatted, '0 mnt');
    });

    test('copyWith updates fields while preserving existing values', () {
      final original = ParkingTicket(
        id: 'orig-id',
        rawCode: 'orig-code',
        entryTime: DateTime(2026, 1, 1, 10, 0),
        firstReminderHours: 11.0,
      );

      final updated = original.copyWith(
        plateNumber: 'D 5678 AA',
        isCompleted: true,
      );

      expect(updated.id, 'orig-id');
      expect(updated.rawCode, 'orig-code');
      expect(updated.plateNumber, 'D 5678 AA');
      expect(updated.isCompleted, isTrue);
      expect(updated.firstReminderHours, 11.0);
    });
  });
}
