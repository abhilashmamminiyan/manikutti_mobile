import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ScreenshotLedgerTarget { personal, family, homeLoan }

extension ScreenshotLedgerTargetExt on ScreenshotLedgerTarget {
  String get key {
    switch (this) {
      case ScreenshotLedgerTarget.personal:
        return 'personal';
      case ScreenshotLedgerTarget.family:
        return 'family';
      case ScreenshotLedgerTarget.homeLoan:
        return 'home_loan';
    }
  }

  String get displayName {
    switch (this) {
      case ScreenshotLedgerTarget.personal:
        return 'Personal';
      case ScreenshotLedgerTarget.family:
        return 'Family';
      case ScreenshotLedgerTarget.homeLoan:
        return 'Home Loan + Family';
    }
  }

  static ScreenshotLedgerTarget fromKey(String? raw) {
    switch (raw) {
      case 'family':
        return ScreenshotLedgerTarget.family;
      case 'home_loan':
        return ScreenshotLedgerTarget.homeLoan;
      default:
        return ScreenshotLedgerTarget.personal;
    }
  }
}

class ScreenshotPayeeRule {
  final String id;
  final String label;
  final List<String> matchPatterns;
  final String category;
  final ScreenshotLedgerTarget target;
  final String transactionType; // 'Expense' | 'Income'
  final String? linkedDueTitle;
  final String? transferToMember;
  final String? customNote;

  const ScreenshotPayeeRule({
    required this.id,
    required this.label,
    required this.matchPatterns,
    required this.category,
    required this.target,
    this.transactionType = 'Expense',
    this.linkedDueTitle,
    this.transferToMember,
    this.customNote,
  });

  factory ScreenshotPayeeRule.fromJson(Map<String, dynamic> json) {
    final rawPatterns = json['matchPatterns'];
    final patterns = rawPatterns is List
        ? rawPatterns.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : (json['matchPattern']?.toString() ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    return ScreenshotPayeeRule(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: json['label']?.toString().trim() ?? 'Saved Payee',
      matchPatterns: patterns,
      category: json['category']?.toString().trim() ?? 'Other',
      target: ScreenshotLedgerTargetExt.fromKey(json['target']?.toString()),
      transactionType: json['transactionType']?.toString() == 'Income' ? 'Income' : 'Expense',
      linkedDueTitle: _cleanOptional(json['linkedDueTitle']),
      transferToMember: _cleanOptional(json['transferToMember']),
      customNote: _cleanOptional(json['customNote']),
    );
  }

  static String? _cleanOptional(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'matchPatterns': matchPatterns,
      'category': category,
      'target': target.key,
      'transactionType': transactionType,
      if (linkedDueTitle != null) 'linkedDueTitle': linkedDueTitle,
      if (transferToMember != null) 'transferToMember': transferToMember,
      if (customNote != null) 'customNote': customNote,
    };
  }

  bool matchesText(String rawOcrText, {String merchant = '', String note = ''}) {
    final combined = '$rawOcrText\n$merchant\n$note'.toLowerCase();
    final combinedDigits = combined.replaceAll(RegExp(r'[^0-9]'), '');

    for (final rawPattern in matchPatterns) {
      final pattern = rawPattern.trim().toLowerCase();
      if (pattern.isEmpty) continue;

      final patternDigits = pattern.replaceAll(RegExp(r'[^0-9]'), '');
      if (patternDigits.length >= 7) {
        final tail = patternDigits.length > 10
            ? patternDigits.substring(patternDigits.length - 10)
            : patternDigits;
        if (combinedDigits.contains(tail)) {
          return true;
        }
      }

      if (combined.contains(pattern)) {
        return true;
      }
    }
    return false;
  }
}

class ScreenshotPayeeRuleService {
  ScreenshotPayeeRuleService._();
  static final ScreenshotPayeeRuleService instance = ScreenshotPayeeRuleService._();

  static const String _prefsKey = 'screenshot_payee_rules_v1';

  final ValueNotifier<List<ScreenshotPayeeRule>> rulesNotifier =
      ValueNotifier<List<ScreenshotPayeeRule>>([]);

  Future<List<ScreenshotPayeeRule>> getRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        rulesNotifier.value = const [];
        return const [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final rules = decoded
          .whereType<Map>()
          .map((m) => ScreenshotPayeeRule.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      rulesNotifier.value = rules;
      return rules;
    } catch (e) {
      if (kDebugMode) print('Error reading payee rules: $e');
      return const [];
    }
  }

  Future<void> saveRule(ScreenshotPayeeRule rule) async {
    final current = List<ScreenshotPayeeRule>.from(await getRules());
    final idx = current.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      current[idx] = rule;
    } else {
      current.insert(0, rule);
    }
    await _persist(current);
  }

  Future<void> deleteRule(String id) async {
    final current = List<ScreenshotPayeeRule>.from(await getRules());
    current.removeWhere((r) => r.id == id);
    await _persist(current);
  }

  Future<void> _persist(List<ScreenshotPayeeRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(rules.map((r) => r.toJson()).toList()),
    );
    rulesNotifier.value = List<ScreenshotPayeeRule>.unmodifiable(rules);
  }

  Future<ScreenshotPayeeRule?> findMatchingRule({
    required String rawOcrText,
    String merchant = '',
    String note = '',
  }) async {
    final rules = await getRules();
    return matchFirstRule(
      rules,
      rawOcrText: rawOcrText,
      merchant: merchant,
      note: note,
    );
  }

  static ScreenshotPayeeRule? matchFirstRule(
    List<ScreenshotPayeeRule> rules, {
    required String rawOcrText,
    String merchant = '',
    String note = '',
  }) {
    for (final rule in rules) {
      if (rule.matchesText(rawOcrText, merchant: merchant, note: note)) {
        return rule;
      }
    }
    return null;
  }
}
