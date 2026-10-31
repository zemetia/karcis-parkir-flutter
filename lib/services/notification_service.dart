import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/parking_ticket.dart';
import '../screens/ticket_detail_screen.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static String? currentViewingTicketId;
  static String? _lastNavigatedTicketId;
  static DateTime? _lastNavigatedTime;

  final StreamController<String> _notificationClickController =
      StreamController<String>.broadcast();
  Stream<String> get onNotificationClick => _notificationClickController.stream;

  String? _pendingTicketId;
  String? get pendingTicketId => _pendingTicketId;

  String? consumePendingTicketId() {
    final id = _pendingTicketId;
    _pendingTicketId = null;
    return id;
  }

  void setPendingTicketId(String? id) {
    _pendingTicketId = id;
  }

  void _handleNotificationPayload(String payload) {
    _pendingTicketId = payload;
    _notificationClickController.add(payload);
    navigateToTicket(payload);
  }

  static Future<void> navigateToTicket(String ticketId) async {
    final now = DateTime.now();
    if (_lastNavigatedTicketId == ticketId &&
        _lastNavigatedTime != null &&
        now.difference(_lastNavigatedTime!) < const Duration(milliseconds: 1000)) {
      debugPrint('Ignoring duplicate navigation to ticket $ticketId');
      return;
    }

    if (currentViewingTicketId == ticketId) {
      debugPrint('Ticket $ticketId is already open on screen');
      return;
    }

    _lastNavigatedTicketId = ticketId;
    _lastNavigatedTime = now;

    try {
      final ticket = await DatabaseService.instance.getTicketById(ticketId);
      if (ticket != null) {
        final navState = navigatorKey.currentState;
        if (navState != null) {
          navState.push(
            MaterialPageRoute(
              builder: (_) => TicketDetailScreen(ticket: ticket),
            ),
          );
        } else {
          NotificationService()._pendingTicketId = ticketId;
        }
      } else {
        debugPrint('Ticket $ticketId not found in database for navigation');
      }
    } catch (e) {
      debugPrint('Error navigating to ticket: $e');
    }
  }

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
            final payload = details.payload;
            debugPrint('Notification clicked: payload=$payload, actionId=${details.actionId}');
            if (payload != null && payload.isNotEmpty) {
              _handleNotificationPayload(payload);
            }
          },
        );

        final launchDetails =
            await _notifications.getNotificationAppLaunchDetails();
        if (launchDetails != null &&
            launchDetails.didNotificationLaunchApp &&
            launchDetails.notificationResponse?.payload != null) {
          _pendingTicketId = launchDetails.notificationResponse!.payload;
          debugPrint('App launched from notification with payload: $_pendingTicketId');
        }
      } catch (e) {
        debugPrint('Platform notifications plugin initialization notice: $e');
      }

      // Pre-create Android notification channels with max priority and alerts
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final androidImpl = _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

          const liveChannel = AndroidNotificationChannel(
            'active_parking_status_v1',
            'Status Parkir Berjalan',
            description: 'Notifikasi waktu parkir aktif dan akses cepat barcode',
            importance: Importance.defaultImportance,
            enableVibration: false,
            playSound: false,
            showBadge: true,
          );

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

          await androidImpl?.createNotificationChannel(liveChannel);
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
  // reminderIndex 0 = Live chronometer notification
  // reminderIndex 1..30 = Scheduled reminder notifications
  int _generateNotificationId(String ticketId, int reminderIndex) {
    return (ticketId.hashCode.abs() % 20000000) * 100 + reminderIndex;
  }

  int generateLiveNotificationId(String ticketId) {
    return _generateNotificationId(ticketId, 0);
  }

  Future<void> showLiveTicketNotification(ParkingTicket ticket) async {
    if (!_isInitialized) {
      await init();
    }
    if (!_isInitialized) return;

    try {
      final id = generateLiveNotificationId(ticket.id);

      final hasPlate = ticket.plateNumber != null && ticket.plateNumber!.trim().isNotEmpty;
      final title = hasPlate
          ? '🅿️ Parkir Aktif: ${ticket.plateNumber!.trim()}'
          : '🅿️ Parkir Aktif: ${ticket.vehicleType}';

      final List<String> details = [];
      if (ticket.locationName != null && ticket.locationName!.trim().isNotEmpty) {
        details.add(ticket.locationName!.trim());
      }
      if (ticket.parkingFloor != null && ticket.parkingFloor!.trim().isNotEmpty) {
        details.add('Lt. ${ticket.parkingFloor!.trim()}');
      }
      if (ticket.parkingBlock != null && ticket.parkingBlock!.trim().isNotEmpty) {
        details.add('Blok ${ticket.parkingBlock!.trim()}');
      }

      final String locationStr = details.isNotEmpty ? details.join(' • ') : '';
      final String body = locationStr.isNotEmpty
          ? '$locationStr\nKetuk untuk buka tiket & scan barcode saat keluar'
          : 'Ketuk untuk langsung buka tiket & scan barcode saat keluar';

      final androidDetails = AndroidNotificationDetails(
        'active_parking_status_v1',
        'Status Parkir Berjalan',
        channelDescription: 'Notifikasi waktu parkir aktif dan akses cepat barcode',
        importance: Importance.defaultImportance,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        when: ticket.entryTime.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: false,
        onlyAlertOnce: true,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.stopwatch,
        visibility: NotificationVisibility.public,
        subText: ticket.vehicleType,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Waktu Parkir Berjalan',
        ),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'open_ticket',
            'Buka Barcode / Scan',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: ticket.id,
      );
      debugPrint('Live chronometer notification displayed for ticket ${ticket.id} (id: $id)');
    } catch (e) {
      debugPrint('Error showing live ticket notification: $e');
    }
  }

  Future<void> cancelLiveTicketNotification(String ticketId) async {
    if (!_isInitialized) {
      await init();
    }
    try {
      await _notifications.cancel(id: generateLiveNotificationId(ticketId));
    } catch (e) {
      debugPrint('Error cancelling live notification: $e');
    }
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
      // Cancels live notification (index 0) and scheduled reminders (1..30)
      for (int i = 0; i <= 30; i++) {
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
