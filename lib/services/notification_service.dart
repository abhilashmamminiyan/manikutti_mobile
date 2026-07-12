import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._init();

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Timezone Database
    tz.initializeTimeZones();

    // Android Settings: Using default launcher icon
    const androidSettings = AndroidInitializationSettings('app_icon');

    // iOS Settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        print('[NotificationService] Notification clicked: ${details.payload}');
      },
    );

    // Request permissions on Android 13+ (API 33+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _isInitialized = true;
    print(
      '[NotificationService] Local notifications initialized successfully.',
    );
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'payment_channel',
        'Payment Notifications',
        channelDescription: 'Alerts when someone pays a family commitment',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  Future<void> scheduleMonthlyReminder({
    required int id,
    required String title,
    required String body,
    required int dueDay,
  }) async {
    final scheduledDate = _nextInstanceOfDay(dueDay);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'dues_channel',
        'Due Reminders',
        channelDescription: 'Reminders for regular family dues',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
    print(
      '[NotificationService] Scheduled monthly notification #$id for day $dueDay at 9:00 AM (Next run: $scheduledDate)',
    );
  }

  Future<void> scheduleUtilityReminder({
    required int id,
    required String title,
    required String body,
    required DateTime nextDueDate,
  }) async {
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(nextDueDate, tz.local);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'utility_channel',
        'Utility Reminders',
        channelDescription: 'Reminders for utility recharges',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'utility_$id',
    );
    print(
      '[NotificationService] Scheduled utility notification #$id for $scheduledDate',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    print('[NotificationService] Cancelled notification #$id');
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    print('[NotificationService] Cancelled all notifications');
  }

  tz.TZDateTime _nextInstanceOfDay(int dueDay) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    int year = now.year;
    int month = now.month;

    int targetDay = dueDay;
    int lastDay = _getLastDayOfMonth(year, month);
    if (targetDay > lastDay) {
      targetDay = lastDay;
    }

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      year,
      month,
      targetDay,
      9,
      0,
      0,
    );
    if (scheduledDate.isBefore(now)) {
      month = month + 1;
      if (month > 12) {
        month = 1;
        year = year + 1;
      }
      lastDay = _getLastDayOfMonth(year, month);
      targetDay = dueDay > lastDay ? lastDay : dueDay;
      scheduledDate = tz.TZDateTime(tz.local, year, month, targetDay, 9, 0, 0);
    }
    return scheduledDate;
  }

  int _getLastDayOfMonth(int year, int month) {
    if (month == 12) return 31;
    final date = DateTime(year, month + 1, 0);
    return date.day;
  }
}
