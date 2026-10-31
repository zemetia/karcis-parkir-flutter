import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      try {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
          final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
          final id = timeZoneInfo.identifier;
          if (tz.timeZoneDatabase.locations.containsKey(id)) {
            tz.setLocalLocation(tz.getLocation(id));
          } else {
            _fallbackToOffsetTimezone();
          }
        } else {
          _fallbackToOffsetTimezone();
        }
      } catch (e) {
        debugPrint('Could not set timezone via flutter_timezone: $e');
        _fallbackToOffsetTimezone();
      }

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

      try {
        await _notifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse details) {
            debugPrint('Notification clicked: ${details.payload}');
          },
        );
      } catch (e) {
        debugPrint('Platform notifications plugin initialization notice: $e');
      }

      // Pre-create Android notification channels with max priority and alerts
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final androidImpl = _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

          const alertChannel = AndroidNotificationChannel(
            'parking_ticket_alerts',
            'Pengingat Karcis Parkir',
            description: 'Notifikasi batas waktu parkir dan tarif menginap',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          );

          const testChannel = AndroidNotificationChannel(
            'test_channel',
            'Notifikasi Uji Coba',
            description: 'Uji coba alarm & notifikasi karcis',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            showBadge: true,
          );

          await androidImpl?.createNotificationChannel(alertChannel);
          await androidImpl?.createNotificationChannel(testChannel);
        } catch (e) {
          debugPrint('Error creating notification channels: $e');
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      _isInitialized = true;
    }
  }

  void _fallbackToOffsetTimezone() {
    try {
      final localOffset = DateTime.now().timeZoneOffset;
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (loc) => loc.currentTimeZone.offset == localOffset,
        orElse: () => tz.getLocation('UTC'),
      );
      tz.setLocalLocation(match);
    } catch (_) {}
  }

  Future<bool> requestPermissions() async {
    try {
      if (!_isInitialized) {
        await init();
      }

      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final bool? notifGranted = await androidImpl?.requestNotificationsPermission();
        return notifGranted ?? true;
      } else if (!kIsWeb && Platform.isIOS) {
        final iosImpl = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final bool? granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  // Generates stable integer ID from ticket string ID and reminder index
  // Range: 0 to ~1,999,999,999 which safely fits inside 32-bit signed int (max 2,147,483,647)
  int _generateNotificationId(String ticketId, int reminderIndex) {
    return (ticketId.hashCode.abs() % 20000000) * 100 + reminderIndex;
  }

  Future<void> scheduleTicketReminders(ParkingTicket ticket) async {
    if (!_isInitialized) {
      await init();
    }
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
        ticker: 'Pengingat Karcis Parkir',
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      const scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

      try {
        await _notifications.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: scheduleMode,
          payload: payload,
        );
        debugPrint('Scheduled notification $id at $scheduledDate (mode: $scheduleMode)');
      } catch (e) {
        if (!kIsWeb && Platform.isAndroid) {
          debugPrint('Exact alarm scheduling failed, attempting inexact fallback: $e');
          await _notifications.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
          debugPrint('Scheduled notification $id at $scheduledDate (fallback inexact)');
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> cancelTicketReminders(String ticketId) async {
    if (!_isInitialized) {
      await init();
    }
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
    if (!_isInitialized) {
      await init();
    }
    try {
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Notifikasi Uji Coba',
        channelDescription: 'Uji coba alarm & notifikasi karcis',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
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
