import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

import 'l10n/app_localizations.dart';
import 'screens/app_lock_screen.dart';

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
    // Initialize notification service safely
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      print('Failed to initialize NotificationService: $e');
    }

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

    // Check if session token/PIN and email exists
    final email = await ApiService.instance.getUserEmail();
    final token = await ApiService.instance.getSessionToken();
    final hasPin = await ApiService.instance.hasPin();

    isLoggedIn =
        (email != null && email.isNotEmpty) && (token != null || hasPin);

    runApp(MyApp(isLoggedIn: isLoggedIn, hasPin: hasPin));
  } catch (e, stackTrace) {
    print('Initialization error in main: $e\n$stackTrace');
    runApp(const MyApp(isLoggedIn: false, hasPin: false));
  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool hasPin;

  const MyApp({super.key, required this.isLoggedIn, required this.hasPin});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  static void setThemeMode(BuildContext context, ThemeMode newThemeMode) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setThemeMode(newThemeMode);
  }

  static ThemeMode getThemeMode(BuildContext context) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    return state?._themeMode ?? ThemeMode.system;
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  late bool _isLocked = widget.isLoggedIn && widget.hasPin;

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  void setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocale();
    _loadThemeMode();
    _checkInitialLockState();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('themeMode') ?? 'system';
    setState(() {
      if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  Future<void> _checkInitialLockState() async {
    final hasPin = await ApiService.instance.hasPin();
    if (widget.isLoggedIn && hasPin) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _checkLockStatusForBackground();
    }
  }

  Future<void> _checkLockStatusForBackground() async {
    final hasPin = await ApiService.instance.hasPin();
    if (widget.isLoggedIn && hasPin) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode') ?? 'en';
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manikutti Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            if (_isLocked)
              Positioned.fill(
                child: AppLockScreen(
                  onUnlock: () {
                    setState(() {
                      _isLocked = false;
                    });
                  },
                ),
              ),
          ],
        );
      },
      home: widget.isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
