import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

import 'l10n/app_localizations.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final familyInfo = await ApiService.instance.getFamilyInfo();
      if (familyInfo != null && familyInfo['familyCode'] != null) {
        final familyCode = familyInfo['familyCode'] as String;
        final notifs = await ApiService.instance.fetchNotifications(familyCode);

        if (notifs.isNotEmpty) {
          final latestNotif = notifs.first;
          final prefs = await SharedPreferences.getInstance();
          final lastNotifiedDate = prefs.getString('last_notified_date') ?? '';
          final currentNotifDate = latestNotif['date'] as String? ?? '';

          if (currentNotifDate.isNotEmpty &&
              currentNotifDate != lastNotifiedDate) {
            await prefs.setString('last_notified_date', currentNotifDate);

            await NotificationService.instance.showImmediateNotification(
              id: latestNotif['id'] ?? 1,
              title: latestNotif['title'] ?? 'New Activity Alert',
              body: latestNotif['message'] ?? '',
            );
          }
        }
      }
    } catch (e) {
      print('Background task execution failed: $e');
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isLoggedIn = false;

  try {
    // Initialize notification service
    await NotificationService.instance.initialize();

    // Initialize workmanager background sync task
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        "fetch_notifications_job",
        "fetchNotificationsTask",
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
    } catch (e) {
      print('Failed to register Workmanager: $e');
    }

    // Check if session token and email exists
    final email = await ApiService.instance.getUserEmail();
    final token = await ApiService.instance.getSessionToken();
    isLoggedIn = email != null && token != null;
  } catch (e, stackTrace) {
    print('Initialization error in main: $e\n$stackTrace');
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode') ?? 'en';
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manikutti Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Auto adapts to light/dark system mode
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: widget.isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
