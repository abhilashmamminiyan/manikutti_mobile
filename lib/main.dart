import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/widget_data_service.dart';
import 'widgets/voice_logging_sheet.dart';
import 'widgets/voice_dialog_screen.dart';
import 'theme/app_theme.dart';

import 'l10n/app_localizations.dart';
import 'screens/app_lock_screen.dart';
import 'services/whats_new_service.dart';
import 'services/category_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      // Check Day 4 & Day 5 Salary Prompt
      final today = DateTime.now();
      if (today.day == 4 || today.day == 5) {
        final prefs = await SharedPreferences.getInstance();
        final confirmed =
            prefs.getBool('salary_confirmed_${today.year}_${today.month}') ??
            false;
        final lastPromptDay =
            prefs.getInt('salary_prompt_sent_${today.year}_${today.month}') ??
            0;
        if (!confirmed && lastPromptDay != today.day) {
          await prefs.setInt(
            'salary_prompt_sent_${today.year}_${today.month}',
            today.day,
          );
          await NotificationService.instance.showSalaryPromptNotificationNow(
            isFollowup: today.day == 5,
          );
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

    // Initialize release notes & What's New service
    try {
      await WhatsNewService.instance.init();
    } catch (e) {
      print('Failed to initialize WhatsNewService: $e');
    }

    // Initialize category preferences & sync with home widget
    try {
      await CategoryService.instance.init();
    } catch (e) {
      print('Failed to initialize CategoryService: $e');
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

    bool startLocked = false;
    final defaultRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final isVoiceRoute = defaultRoute.contains('voice-dialog');

    if (isLoggedIn && hasPin && !isVoiceRoute) {
      final prefs = await SharedPreferences.getInstance();
      final lastPaused = prefs.getInt('last_app_paused_epoch_ms') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - lastPaused;
      // Require unlock if cold start (lastPaused == 0) or if >= 2 minutes (120,000ms) elapsed
      if (lastPaused == 0 || elapsed >= 2 * 60 * 1000 || elapsed < 0) {
        startLocked = true;
      } else {
        startLocked = false;
      }
    }

    runApp(
      MyApp(isLoggedIn: isLoggedIn, hasPin: hasPin, initialLocked: startLocked),
    );
  } catch (e, stackTrace) {
    print('Initialization error in main: $e\n$stackTrace');
    runApp(const MyApp(isLoggedIn: false, hasPin: false, initialLocked: false));
  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool hasPin;
  final bool initialLocked;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.hasPin,
    this.initialLocked = false,
  });

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
  late bool _isLocked = widget.initialLocked;
  int? _lastPausedEpochMs;
  static const int lockGracePeriodMs = 2 * 60 * 1000; // 2 minutes grace period

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

  StreamSubscription? _widgetClickSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocale();
    _loadThemeMode();
    _checkInitialLockState();
    _initHomeWidgetAndDeepLinks();
  }

  Future<void> _initHomeWidgetAndDeepLinks() async {
    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        _handleDeepLinkUri(initialUri);
      }

      _widgetClickSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
        if (uri != null) {
          _handleDeepLinkUri(uri);
        }
      });

      unawaited(WidgetDataService.updateWidgetData());
    } catch (e) {
      debugPrint('Error initializing HomeWidget: $e');
    }
  }

  void _handleDeepLinkUri(Uri uri) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      final isVoice =
          uri.host == 'voice-expense' ||
          uri.host == 'voice-dialog' ||
          (uri.host == 'manikutti.vercel.app' &&
              (uri.path.contains('voice-dialog') ||
                  uri.path.contains('voice-expense')));

      final isAdd =
          uri.host == 'add-transaction' ||
          (uri.host == 'manikutti.vercel.app' &&
              uri.path.contains('add-transaction'));

      if (isVoice) {
        final query = uri.queryParameters['query'];
        VoiceLoggingSheet.show(context, initialQuery: query);
      } else if (isAdd) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        );
      }
    });
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
    final defaultRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (defaultRoute.contains('voice-dialog')) {
      if (_isLocked) {
        setState(() {
          _isLocked = false;
        });
      }
      return;
    }

    final hasPin = await ApiService.instance.hasPin();
    if (!widget.isLoggedIn || !hasPin) {
      if (_isLocked) {
        setState(() {
          _isLocked = false;
        });
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPaused = prefs.getInt('last_app_paused_epoch_ms') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastPaused;

    if (lastPaused > 0 && elapsed < lockGracePeriodMs && elapsed >= 0) {
      if (_isLocked) {
        setState(() {
          _isLocked = false;
        });
      }
    } else {
      if (!_isLocked) {
        setState(() {
          _isLocked = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppPaused() async {
    // If already locked, don't update timestamp so grace period isn't extended while locked
    if (_isLocked) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _lastPausedEpochMs = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_app_paused_epoch_ms', now);
  }

  Future<void> _handleAppResumed() async {
    final defaultRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (defaultRoute.contains('voice-dialog')) {
      return;
    }

    final hasPin = await ApiService.instance.hasPin();
    if (!widget.isLoggedIn || !hasPin) {
      return;
    }

    // If already locked, keep locked
    if (_isLocked) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPaused =
        _lastPausedEpochMs ?? prefs.getInt('last_app_paused_epoch_ms') ?? 0;

    if (lastPaused == 0) {
      setState(() {
        _isLocked = true;
      });
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastPaused;

    if (elapsed >= lockGracePeriodMs || elapsed < 0) {
      // 2 minutes or more elapsed since leaving the app: lock it!
      setState(() {
        _isLocked = true;
      });
    } else {
      debugPrint(
        'App resumed within 2-minute grace period ($elapsed ms). No unlock prompt.',
      );
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
    _widgetClickSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Manikutti Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null) {
          final isVoice =
              uri.path.contains('voice-dialog') ||
              uri.host == 'voice-dialog' ||
              uri.path.contains('voice-expense') ||
              uri.host == 'voice-expense';
          if (isVoice) {
            final query = uri.queryParameters['query'];
            return PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, _, __) =>
                  VoiceDialogScreen(initialQuery: query),
            );
          }
        }
        return null;
      },
      builder: (context, child) {
        final defaultRoute =
            WidgetsBinding.instance.platformDispatcher.defaultRouteName;
        final isVoiceRoute = defaultRoute.contains('voice-dialog');

        return Stack(
          children: [
            if (child != null) child,
            if (_isLocked && !isVoiceRoute)
              Positioned.fill(
                child: AppLockScreen(
                  onUnlock: () async {
                    setState(() {
                      _isLocked = false;
                    });
                    final now = DateTime.now().millisecondsSinceEpoch;
                    _lastPausedEpochMs = now;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('last_app_paused_epoch_ms', now);
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

/// Dedicated entrypoint for VoiceDialogActivity (translucent overlay on home screen)
@pragma('vm:entry-point')
void voiceDialogMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Failed to initialize NotificationService in voice dialog: $e');
  }
  runApp(const VoiceDialogApp());
}

class VoiceDialogApp extends StatelessWidget {
  const VoiceDialogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final defaultRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final uri = Uri.tryParse(defaultRoute);
    final query = uri?.queryParameters['query'];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: VoiceDialogScreen(initialQuery: query),
    );
  }
}
