import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureKeys {
  static const String homeLoan = 'home_loan';
  static const String loansEmiLedger = 'loans_emi_ledger';
  static const String repaymentSchedules = 'repayment_schedules';
  static const String monthlyDues = 'monthly_dues';
  static const String billsUtilities = 'bills_utilities';
  static const String mobileRecharges = 'mobile_recharges';
  static const String smartScan = 'smart_scan';
  static const String screenshots = 'screenshots';
  static const String bankStatement = 'bank_statement';
  static const String voiceLogging = 'voice_logging';
  static const String smsAutoTracking = 'sms_auto_tracking';
  static const String aiScreenshotExtraction = 'ai_screenshot_extraction';
  static const String aiAdvisor = 'ai_advisor';
  static const String budgetProgress = 'budget_progress';
  static const String expenseChart = 'expense_chart';
  static const String bankBalances = 'bank_balances';
  static const String salaryTracking = 'salary_tracking';
  static const String familyLedger = 'family_ledger';
  static const String familyGoals = 'family_goals';
  static const String aboutApp = 'about_app';

  static const List<String> allKeys = [
    homeLoan,
    loansEmiLedger,
    repaymentSchedules,
    monthlyDues,
    billsUtilities,
    mobileRecharges,
    smartScan,
    screenshots,
    bankStatement,
    voiceLogging,
    smsAutoTracking,
    aiScreenshotExtraction,
    aiAdvisor,
    budgetProgress,
    expenseChart,
    bankBalances,
    salaryTracking,
    familyLedger,
    familyGoals,
    aboutApp,
  ];
}

class FeatureFlagService {
  FeatureFlagService._();
  static final FeatureFlagService instance = FeatureFlagService._();

  static const String _prefsPermissionsKey = 'feature_permissions_v1';
  static const String _prefsRoleKey = 'feature_role_name_v1';
  static const String _prefsAiEnabledKey = 'feature_master_ai_enabled_v1';

  final ValueNotifier<Map<String, bool>> permissionsNotifier =
      ValueNotifier<Map<String, bool>>(_buildDefaultOpenMap());

  String _roleName = 'Member';
  bool _masterAiEnabled = true;
  bool _initialized = false;

  String get roleName => _roleName;
  bool get masterAiEnabled => _masterAiEnabled;

  /// Pure capability flag check: Returns false if all personal finance ledger
  /// modules (balances, budget gauge, expense charts, personal salary tracking)
  /// are disabled, signaling a focused family/shared view.
  bool get hasPersonalLedger =>
      isEnabled(FeatureKeys.bankBalances) ||
      isEnabled(FeatureKeys.budgetProgress) ||
      isEnabled(FeatureKeys.expenseChart) ||
      isEnabled(FeatureKeys.salaryTracking);

  static Map<String, bool> _buildDefaultOpenMap() {
    return {for (final k in FeatureKeys.allKeys) k: true};
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _roleName = prefs.getString(_prefsRoleKey) ?? 'Member';
      _masterAiEnabled = prefs.getBool(_prefsAiEnabledKey) ?? true;
      final raw = prefs.getString(_prefsPermissionsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final map = _buildDefaultOpenMap();
        for (final key in FeatureKeys.allKeys) {
          if (decoded.containsKey(key) && decoded[key] is bool) {
            map[key] = decoded[key] as bool;
          }
        }
        permissionsNotifier.value = map;
      }
    } catch (_) {
      permissionsNotifier.value = _buildDefaultOpenMap();
    }
  }

  bool isEnabled(String key) {
    if (!_masterAiEnabled &&
        (key == FeatureKeys.aiScreenshotExtraction ||
            key == FeatureKeys.aiAdvisor)) {
      return false;
    }
    return permissionsNotifier.value[key] ?? true;
  }

  Future<void> updateFromServer({
    required String roleName,
    required Map<String, dynamic>? permissions,
    bool? aiEnabled,
  }) async {
    _roleName = roleName.trim().isNotEmpty ? roleName.trim() : _roleName;
    if (aiEnabled != null) {
      _masterAiEnabled = aiEnabled;
    }

    final merged = _buildDefaultOpenMap();
    if (permissions != null) {
      for (final key in FeatureKeys.allKeys) {
        final v = permissions[key];
        if (v is bool) {
          merged[key] = v;
        }
      }
    }
    if (!_masterAiEnabled) {
      merged[FeatureKeys.aiScreenshotExtraction] = false;
      merged[FeatureKeys.aiAdvisor] = false;
    }

    permissionsNotifier.value = merged;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsRoleKey, _roleName);
      await prefs.setBool(_prefsAiEnabledKey, _masterAiEnabled);
      await prefs.setString(_prefsPermissionsKey, jsonEncode(merged));
    } catch (_) {}
  }

  Future<void> clear() async {
    _roleName = 'Member';
    _masterAiEnabled = true;
    permissionsNotifier.value = _buildDefaultOpenMap();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsRoleKey);
      await prefs.remove(_prefsAiEnabledKey);
      await prefs.remove(_prefsPermissionsKey);
    } catch (_) {}
  }
}
