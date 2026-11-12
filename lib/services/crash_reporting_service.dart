import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks active Navigator route names so crashes and API errors always include
/// the exact screen context.
class CrashlyticsRouteObserver extends NavigatorObserver {
  CrashlyticsRouteObserver(this._onRouteChanged);

  final void Function(String routeName) _onRouteChanged;

  void _notify(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) {
      _onRouteChanged(name);
    } else if (route != null) {
      _onRouteChanged(route.runtimeType.toString());
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _notify(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _notify(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _notify(previousRoute);
  }
}

/// Unified Firebase Crashlytics + AI-first error telemetry service.
///
/// Captures:
/// 1. Native/Flutter fatal crashes (`FlutterError.onError`, `PlatformDispatcher.instance.onError`)
/// 2. Non-fatal Dart & screen exceptions
/// 3. HTTP / API failures (e.g. `/api/sheets/home-loan`) buffered locally and flushed to
///    `/api/telemetry/errors` for live Admin Console + AI CLI diagnostics.
class CrashReportingService {
  static final CrashReportingService instance = CrashReportingService._init();

  static const String _defaultBaseUrl = 'https://manikutti.vercel.app';
  static const String _queuePrefsKey = 'pending_error_telemetry_queue';
  static const int _maxQueuedItems = 25;

  CrashReportingService._init();

  late final CrashlyticsRouteObserver routeObserver = CrashlyticsRouteObserver(
    setCurrentScreen,
  );

  bool _initialized = false;
  bool _crashlyticsReady = false;
  bool _flushing = false;
  String _currentScreen = 'app_launch';
  String _appVersion = 'unknown';
  String _buildNumber = '0';
  String? _userEmail;
  String? _familyCode;

  String get currentScreen => _currentScreen;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('user_email');
      _familyCode = prefs.getString('family_code');
    } catch (_) {}

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          true,
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'app_version',
          '$_appVersion+$_buildNumber',
        );
        if (_userEmail != null && _userEmail!.isNotEmpty) {
          await FirebaseCrashlytics.instance.setUserIdentifier(_userEmail!);
        }
        if (_familyCode != null && _familyCode!.isNotEmpty) {
          await FirebaseCrashlytics.instance.setCustomKey(
            'family_code',
            _familyCode!,
          );
        }
        _crashlyticsReady = true;
      } catch (e) {
        debugPrint('Crashlytics setup notice: $e');
      }
    }

    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_crashlyticsReady) {
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      }
      unawaited(
        _enqueueAndFlush(
          severity: 'fatal',
          screenOrRoute: _currentScreen,
          message: details.exceptionAsString(),
          stackTrace: details.stack?.toString() ?? '',
        ),
      );
      if (previousFlutterError != null) {
        previousFlutterError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_crashlyticsReady) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
        );
      }
      unawaited(
        _enqueueAndFlush(
          severity: 'fatal',
          screenOrRoute: _currentScreen,
          message: error.toString(),
          stackTrace: stack.toString(),
        ),
      );
      return true;
    };

    // Best-effort flush of crashes/errors buffered from an earlier run.
    unawaited(flushPendingTelemetry());
  }

  void setCurrentScreen(String screenName) {
    final trimmed = screenName.trim();
    if (trimmed.isEmpty) return;
    _currentScreen = trimmed;
    if (_crashlyticsReady) {
      unawaited(FirebaseCrashlytics.instance.setCustomKey('screen', trimmed));
      unawaited(FirebaseCrashlytics.instance.log('screen: $trimmed'));
    }
  }

  Future<void> setUserContext({String? email, String? familyCode}) async {
    if (email != null && email.trim().isNotEmpty) {
      _userEmail = email.trim();
      if (_crashlyticsReady) {
        unawaited(FirebaseCrashlytics.instance.setUserIdentifier(_userEmail!));
      }
    }
    if (familyCode != null && familyCode.trim().isNotEmpty) {
      _familyCode = familyCode.trim();
      if (_crashlyticsReady) {
        unawaited(
          FirebaseCrashlytics.instance.setCustomKey(
            'family_code',
            _familyCode!,
          ),
        );
      }
    }
    unawaited(flushPendingTelemetry());
  }

  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String reason = 'Non-fatal Flutter error',
    bool fatal = false,
    String? screenOrRoute,
    Map<String, Object>? context,
  }) async {
    final route = screenOrRoute ?? _currentScreen;
    if (_crashlyticsReady) {
      try {
        if (context != null) {
          for (final entry in context.entries) {
            await FirebaseCrashlytics.instance.setCustomKey(
              entry.key,
              entry.value.toString(),
            );
          }
        }
        await FirebaseCrashlytics.instance.recordError(
          error,
          stack ?? StackTrace.current,
          reason: reason,
          fatal: fatal,
        );
      } catch (_) {}
    }
    await _enqueueAndFlush(
      severity: fatal ? 'fatal' : 'error',
      screenOrRoute: route,
      message: '$reason: $error',
      stackTrace: (stack ?? StackTrace.current).toString(),
    );
  }

  Future<void> recordApiFailure({
    required String method,
    required String endpoint,
    int? statusCode,
    Object? error,
    StackTrace? stack,
    String? responseSnippet,
  }) async {
    // Guard against infinite telemetry recursion.
    if (endpoint.contains('/api/telemetry/errors')) return;

    final sanitizedEndpoint = _sanitizeUrl(endpoint);
    final summary = statusCode != null
        ? 'HTTP $statusCode $method $sanitizedEndpoint'
        : 'API Exception $method $sanitizedEndpoint: $error';
    final detail = responseSnippet != null && responseSnippet.isNotEmpty
        ? '$summary | body=${_truncate(responseSnippet, 300)}'
        : summary;

    if (_crashlyticsReady) {
      try {
        await FirebaseCrashlytics.instance.setCustomKey(
          'api_route',
          sanitizedEndpoint,
        );
        await FirebaseCrashlytics.instance.setCustomKey('http_method', method);
        if (statusCode != null) {
          await FirebaseCrashlytics.instance.setCustomKey(
            'http_status',
            statusCode,
          );
        }
        await FirebaseCrashlytics.instance.log(detail);
        await FirebaseCrashlytics.instance.recordError(
          error ?? Exception(summary),
          stack ?? StackTrace.current,
          reason: 'API Failure ($method $sanitizedEndpoint)',
          fatal: false,
        );
      } catch (_) {}
    }

    await _enqueueAndFlush(
      severity: (statusCode != null && statusCode >= 500) || statusCode == null
          ? 'error'
          : 'warn',
      screenOrRoute: '$_currentScreen -> $sanitizedEndpoint',
      method: method,
      httpStatus: statusCode,
      message: detail,
      stackTrace: (stack ?? StackTrace.current).toString(),
    );
  }

  Future<void> _enqueueAndFlush({
    required String severity,
    required String screenOrRoute,
    required String message,
    String? method,
    int? httpStatus,
    String stackTrace = '',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getStringList(_queuePrefsKey) ?? <String>[];
      final payload = <String, dynamic>{
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'source': 'mobile',
        'severity': severity,
        'screenOrRoute': _truncate(screenOrRoute, 200),
        if (method != null) 'method': method,
        if (httpStatus != null) 'httpStatus': httpStatus,
        'message': _truncate(message, 800),
        'stackTraceSnippet': _truncate(stackTrace, 1500),
        'userEmail': _userEmail ?? prefs.getString('user_email') ?? '',
        'familyCode': _familyCode ?? prefs.getString('family_code') ?? '',
        'appVersion': _appVersion,
        'buildNumber': _buildNumber,
        'deviceInfo': _deviceSummary(),
      };
      final updated = [...existingRaw, jsonEncode(payload)];
      final capped = updated.length > _maxQueuedItems
          ? updated.sublist(updated.length - _maxQueuedItems)
          : updated;
      await prefs.setStringList(_queuePrefsKey, capped);
    } catch (_) {}

    await flushPendingTelemetry();
  }

  Future<void> flushPendingTelemetry() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final queued = prefs.getStringList(_queuePrefsKey) ?? <String>[];
      if (queued.isEmpty) return;

      final token = prefs.getString('session_token');
      if (token == null || token.isEmpty) return;

      final baseUrl = kDebugMode
          ? (prefs.getString('api_base_url') ?? _defaultBaseUrl)
          : _defaultBaseUrl;

      final items = <Map<String, dynamic>>[];
      for (final raw in queued) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is Map<String, dynamic>) {
            items.add(parsed);
          }
        } catch (_) {}
      }
      if (items.isEmpty) {
        await prefs.remove(_queuePrefsKey);
        return;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/telemetry/errors'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'items': items}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.remove(_queuePrefsKey);
      }
    } catch (_) {
      // Retain queue silently for next launch / online transition.
    } finally {
      _flushing = false;
    }
  }

  static String _sanitizeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return _truncate(url, 180);
    return uri.path.isNotEmpty ? uri.path : _truncate(url, 180);
  }

  static String _truncate(String value, int maxLen) {
    if (value.length <= maxLen) return value;
    return '${value.substring(0, maxLen)}...';
  }

  static String _deviceSummary() {
    if (kIsWeb) return 'web';
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'mobile';
    }
  }
}
