import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/parking_ticket.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      try {
        final localOffset = DateTime.now().timeZoneOffset;
        final match = tz.timeZoneDatabase.locations.values.firstWhere(
          (loc) => loc.currentTimeZone.offset == localOffset,
          orElse: () => tz.getLocation('UTC'),
        );
        tz.setLocalLocation(match);
      } catch (_) {}

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification clicked: ${details.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  Future<void> requestPermissions() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
        await androidImpl?.requestExactAlarmsPermission();
      } else if (!kIsWeb && Platform.isIOS) {
        final iosImpl = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  // Generates stable integer ID from ticket string ID and reminder index
  int _generateNotificationId(String ticketId, int reminderIndex) {
    return (ticketId.hashCode.abs() % 100000) * 100 + reminderIndex;
  }

  Future<void> scheduleTicketReminders(ParkingTicket ticket) async {
    if (!_isInitialized) return;

    final now = DateTime.now();

    for (int i = 0; i < ticket.reminderHours.length; i++) {
      final hours = ticket.reminderHours[i];
      final reminderMinutes = (hours * 60).round();
      final reminderTime = ticket.entryTime.add(Duration(minutes: reminderMinutes));

      if (reminderTime.isAfter(now)) {
        final scheduledDate = tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.local,
          reminderTime.millisecondsSinceEpoch,
        );
        final id = _generateNotificationId(ticket.id, i + 1);
        final hoursLabel = hours == hours.roundToDouble()
            ? '${hours.toInt()}'
            : hours.toStringAsFixed(1);

        final title = hours >= 24
            ? 'Peringatan Tarif Menginap ($hoursLabel Jam)'
            : 'Pengingat Waktu Parkir ($hoursLabel Jam)';
        final body = 'Karcis ${ticket.plateNumber ?? ticket.rawCode}: '
            'Kendaraan telah diparkir selama $hoursLabel jam.';

        await _scheduleNotification(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          payload: ticket.id,
        );
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'parking_ticket_alerts',
        'Pengingat Karcis Parkir',
        channelDescription: 'Notifikasi batas waktu parkir dan tarif menginap',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      debugPrint('Scheduled notification $id at $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> cancelTicketReminders(String ticketId) async {
    if (!_isInitialized) return;
    try {
      for (int i = 1; i <= 30; i++) {
        await _notifications.cancel(id: _generateNotificationId(ticketId, i));
      }
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Notifikasi Uji Coba',
        channelDescription: 'Uji coba alarm & notifikasi karcis',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails();
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id: 9999,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }
}
