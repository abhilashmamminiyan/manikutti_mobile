import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  static final ValueNotifier<String?> onNotificationPayload =
      ValueNotifier<String?>(null);

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
        onNotificationPayload.value = details.payload;
      },
    );

    // Request permissions on Android 13+ (API 33+)
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'voice_expense_channel',
          'Voice & Widget Expenses',
          description:
              'Instant confirmation alerts for expenses and income logged via voice or widget',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'payment_channel',
          'Payment Notifications',
          description: 'Alerts when someone pays a family commitment',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
    }
    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      print('[NotificationService] Exact alarm permission request notice: $e');
    }

    _isInitialized = true;
    print(
      '[NotificationService] Local notifications initialized successfully.',
    );
  }

  Future<bool> requestPermission() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required UILocalNotificationDateInterpretation
    uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            uiLocalNotificationDateInterpretation,
        payload: payload,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      print(
        '[NotificationService] Exact alarm scheduling failed ($e). Falling back to inexact alarm.',
      );
      try {
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              uiLocalNotificationDateInterpretation,
          payload: payload,
          matchDateTimeComponents: matchDateTimeComponents,
        );
      } catch (fallbackError) {
        print(
          '[NotificationService] Inexact alarm scheduling failed: $fallbackError',
        );
      }
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'voice_expense_channel',
    String channelName = 'Voice & Widget Expenses',
    String channelDescription =
        'Instant confirmation alerts for expenses and income logged via voice or widget',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final areEnabled = await androidPlugin?.areNotificationsEnabled();
    if (areEnabled == false) {
      await androidPlugin?.requestNotificationsPermission();
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
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

    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
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
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      nextDueDate,
      tz.local,
    );

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

    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'utility_$id',
    );
    print(
      '[NotificationService] Scheduled utility notification #$id for $scheduledDate',
    );
  }

  Future<void> scheduleRechargeExpiryReminder({
    required int id,
    required String name,
    required String operatorName,
    required String phoneNumber,
    required double amount,
    required DateTime expiryDate,
    int daysBefore = 1,
  }) async {
    // Schedule reminder before expiry (e.g. 1 day before at 9:00 AM)
    final reminderTarget = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      9,
      0,
    ).subtract(Duration(days: daysBefore));

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      reminderTarget,
      tz.local,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      // If reminder date is already in the past, but expiry is still today or in future
      final expiryDayNineAm = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
        9,
        0,
      );
      final tz.TZDateTime expiryScheduled = tz.TZDateTime.from(
        expiryDayNineAm,
        tz.local,
      );
      if (expiryScheduled.isBefore(tz.TZDateTime.now(tz.local))) {
        return; // Expiry already passed
      }
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'recharge_channel',
        'Mobile Recharge Reminders',
        channelDescription: 'Reminders for mobile recharge validity expiry',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final effectiveDate = scheduledDate.isBefore(tz.TZDateTime.now(tz.local))
        ? tz.TZDateTime.from(
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day, 9, 0),
            tz.local,
          )
        : scheduledDate;

    final title = 'Recharge Expiring Soon: $name';
    final amountStr = amount > 0 ? ' (₹${amount.toStringAsFixed(0)})' : '';
    final body =
        '$operatorName recharge$amountStr for $phoneNumber expires on ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}. Recharge now!';

    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: effectiveDate,
      notificationDetails: details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'recharge_$id',
    );
    print(
      '[NotificationService] Scheduled recharge notification #$id for $effectiveDate',
    );
  }

  Future<void> cancelRechargeReminder(int id) async {
    await _localNotifications.cancel(id);
    print('[NotificationService] Cancelled recharge notification #$id');
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    print('[NotificationService] Cancelled notification #$id');
  }

  Future<void> scheduleSalaryPromptReminders({
    bool isAlreadyConfirmed = false,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    int currentYear = now.year;
    int currentMonth = now.month;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'salary_channel',
        'Salary Notifications',
        channelDescription: 'Monthly reminder to record received salary income',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(),
    );

    if (isAlreadyConfirmed) {
      await cancelNotification(9004);
      await cancelNotification(9005);

      // Schedule for day 4 and 5 of next month
      int nextMonth = currentMonth + 1;
      int nextYear = currentYear;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      final nextDay4 = tz.TZDateTime(tz.local, nextYear, nextMonth, 4, 9, 0);
      final nextDay5 = tz.TZDateTime(tz.local, nextYear, nextMonth, 5, 9, 0);

      await _safeZonedSchedule(
        id: 9004,
        title: 'Have you got your salary?',
        body: 'Tap to confirm or edit your monthly salary income.',
        scheduledDate: nextDay4,
        notificationDetails: details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'salary_prompt',
      );

      await _safeZonedSchedule(
        id: 9005,
        title: 'Salary Follow-up: Have you got your salary?',
        body:
            'Please confirm your salary to record it as income in your transaction log.',
        scheduledDate: nextDay5,
        notificationDetails: details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'salary_prompt',
      );
      print(
        '[NotificationService] Salary prompt scheduled for next month (day 4 & 5)',
      );
      return;
    }

    final day4ThisMonth = tz.TZDateTime(
      tz.local,
      currentYear,
      currentMonth,
      4,
      9,
      0,
    );
    final day5ThisMonth = tz.TZDateTime(
      tz.local,
      currentYear,
      currentMonth,
      5,
      9,
      0,
    );

    if (day4ThisMonth.isAfter(now)) {
      await _safeZonedSchedule(
        id: 9004,
        title: 'Have you got your salary?',
        body: 'Tap to confirm or edit your monthly salary income.',
        scheduledDate: day4ThisMonth,
        notificationDetails: details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'salary_prompt',
      );
      await _safeZonedSchedule(
        id: 9005,
        title: 'Salary Follow-up: Have you got your salary?',
        body:
            'Please confirm your salary to record it as income in your transaction log.',
        scheduledDate: day5ThisMonth,
        notificationDetails: details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'salary_prompt',
      );
    } else if (now.day == 4) {
      await _safeZonedSchedule(
        id: 9005,
        title: 'Salary Follow-up: Have you got your salary?',
        body:
            'Please confirm your salary to record it as income in your transaction log.',
        scheduledDate: day5ThisMonth,
        notificationDetails: details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'salary_prompt',
      );
    } else if (now.day == 5 && day5ThisMonth.isAfter(now)) {
      await _safeZonedSchedule(
        id: 9005,
        title: 'Salary Follow-up: Have you got your salary?',
        body:
            'Please confirm your salary to record it as income in your transaction log.',
        scheduledDate: day5ThisMonth,
        notificationDetails: details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'salary_prompt',
      );
    }
  }

  Future<void> showSalaryPromptNotificationNow({
    bool isFollowup = false,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'salary_channel',
        'Salary Notifications',
        channelDescription: 'Monthly reminder to record received salary income',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      isFollowup ? 9005 : 9004,
      isFollowup
          ? 'Salary Follow-up: Have you got your salary?'
          : 'Have you got your salary?',
      'Tap to confirm or edit your monthly salary income.',
      details,
      payload: 'salary_prompt',
    );
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
