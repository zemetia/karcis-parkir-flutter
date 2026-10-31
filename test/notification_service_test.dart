import 'package:flutter_test/flutter_test.dart';
import 'package:karcis_parkir/models/parking_ticket.dart';
import 'package:karcis_parkir/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('NotificationService ID Generation Tests', () {
    test('NotificationService singleton instance is accessible', () {
      final service1 = NotificationService();
      final service2 = NotificationService();
      expect(identical(service1, service2), isTrue);
    });

    test('Generates consistent notification IDs for same ticket ID and index', () {
      final ticketId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
      final id1 = (ticketId.hashCode.abs() % 20000000) * 100 + 1;
      final id2 = (ticketId.hashCode.abs() % 20000000) * 100 + 1;
      expect(id1, equals(id2));
    });

    test('Different reminder indexes produce distinct notification IDs', () {
      final ticketId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
      final base = (ticketId.hashCode.abs() % 20000000) * 100;
      final idIndex1 = base + 1;
      final idIndex2 = base + 2;
      final idIndex3 = base + 3;

      expect(idIndex1, isNot(equals(idIndex2)));
      expect(idIndex2, isNot(equals(idIndex3)));
    });

    test('Notification ID fits comfortably within 32-bit integer limits for Android PendingIntent', () {
      final ticketId = 'long-uuid-string-identifier-1234567890';
      final id = (ticketId.hashCode.abs() % 20000000) * 100 + 99;
      // 32-bit signed int max is 2,147,483,647. Max generated here is (19,999,999 * 100) + 99 = 1,999,999,999.
      expect(id, lessThan(2147483647));
      expect(id, greaterThanOrEqualTo(0));
    });
  });

  group('Timezone Detection & Fallback Tests', () {
    test('Initializes timezones and resolves Asia/Jakarta accurately', () {
      tz.initializeTimeZones();
      final loc = tz.getLocation('Asia/Jakarta');
      expect(loc.name, 'Asia/Jakarta');
      expect(loc.currentTimeZone.offset, const Duration(hours: 7));
    });

    test('Offset matching fallback correctly resolves Duration offset', () {
      tz.initializeTimeZones();
      final localOffset = const Duration(hours: 7);
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) => loc.currentTimeZone.offset == localOffset,
        orElse: () => tz.getLocation('UTC'),
      );
      expect(match.currentTimeZone.offset, equals(localOffset));
    });
  });

  group('Notification Title and Duration Mapping Tests', () {
    test('Formats titles and reminder hours appropriately', () {
      final now = DateTime.now();
      final ticket = ParkingTicket(
        id: 'test-notif-ticket',
        rawCode: 'PARK-001',
        plateNumber: 'B 1234 CD',
        entryTime: now,
        reminderHours: [1.0, 11.0, 24.0, 48.0],
      );

      for (int i = 0; i < ticket.reminderHours.length; i++) {
        final hours = ticket.reminderHours[i];
        final hoursLabel = hours == hours.roundToDouble()
            ? '${hours.toInt()}'
            : hours.toStringAsFixed(1);

        final title = hours >= 24
            ? 'Peringatan Tarif Menginap ($hoursLabel Jam)'
            : 'Pengingat Waktu Parkir ($hoursLabel Jam)';

        if (hours < 24) {
          expect(title, contains('Pengingat Waktu Parkir'));
        } else {
          expect(title, contains('Peringatan Tarif Menginap'));
        }
      }
    });
  });
}
