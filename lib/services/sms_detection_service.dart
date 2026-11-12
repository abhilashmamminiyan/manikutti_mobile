import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bank_balance_service.dart';
import 'sync_service.dart';
import 'widget_data_service.dart';

class PendingSmsTransaction {
  final String id;
  final double amount;
  final String type;
  final String category;
  final String merchant;
  final String bankAccount;
  final double? availableBalance;
  final bool isEmi;
  final String rawBody;
  final int timestampMs;

  PendingSmsTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.bankAccount,
    this.availableBalance,
    required this.isEmi,
    required this.rawBody,
    required this.timestampMs,
  });

  factory PendingSmsTransaction.fromJson(Map<String, dynamic> json) {
    return PendingSmsTransaction(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type']?.toString() ?? 'Expense',
      category: json['category']?.toString() ?? 'Other',
      merchant: json['merchant']?.toString() ?? 'Bank SMS',
      bankAccount: json['bankAccount']?.toString() ?? 'SBI',
      availableBalance: json['availableBalance'] != null
          ? (json['availableBalance'] as num?)?.toDouble()
          : null,
      isEmi: json['isEmi'] == true,
      rawBody: json['rawBody']?.toString() ?? '',
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class SmsDetectionService {
  static final SmsDetectionService instance = SmsDetectionService._internal();
  SmsDetectionService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.abhilash.manikutti/sms',
  );
  static const String keySmsEnabled = 'sms_detection_enabled';
  static const String keyConfiguredEmiAmounts = 'configured_emi_amounts';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keySmsEnabled) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySmsEnabled, enabled);
  }

  Future<void> syncConfiguredEmiAmounts(List<double> amounts) async {
    final clean = amounts
        .where((a) => a > 0)
        .map((a) => a.toStringAsFixed(0))
        .toSet()
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyConfiguredEmiAmounts, clean.join(','));
  }

  Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasSmsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('[SmsDetectionService] hasPermission error: $e');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestSmsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('[SmsDetectionService] requestPermission error: $e');
      return false;
    }
  }

  Future<int> scanRecentSms({int hours = 48}) async {
    if (!await isEnabled()) return 0;
    if (!await hasPermission()) return 0;
    try {
      final count = await _channel.invokeMethod<int>('scanRecentSms', {
        'hours': hours,
      });
      return count ?? 0;
    } catch (e) {
      debugPrint('[SmsDetectionService] scanRecentSms error: $e');
      return 0;
    }
  }

  Future<List<PendingSmsTransaction>> getPendingSms() async {
    try {
      final raw = await _channel.invokeMethod<String>('getPendingSms');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PendingSmsTransaction.fromJson)
          .where((item) => item.id.isNotEmpty && item.amount > 0)
          .toList();
    } catch (e) {
      debugPrint('[SmsDetectionService] getPendingSms error: $e');
      return [];
    }
  }

  Future<PendingSmsTransaction?> confirmPendingSms(String id) async {
    try {
      final raw = await _channel.invokeMethod<String>('confirmPendingSms', {
        'id': id,
      });
      await BankBalanceService.instance.init();
      await WidgetDataService.updateWidgetData();
      unawaited(SyncService.instance.syncData());
      if (raw != null && raw.isNotEmpty) {
        return PendingSmsTransaction.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[SmsDetectionService] confirmPendingSms error: $e');
      return null;
    }
  }

  Future<void> dismissPendingSms(String id) async {
    try {
      await _channel.invokeMethod('dismissPendingSms', {'id': id});
    } catch (e) {
      debugPrint('[SmsDetectionService] dismissPendingSms error: $e');
    }
  }
}

void unawaited(Future<void> future) {}
