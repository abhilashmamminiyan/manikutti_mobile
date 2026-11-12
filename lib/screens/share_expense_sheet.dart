import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/home_loan_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../services/notification_service.dart';
import '../services/screenshot_extractor_service.dart';
import '../services/screenshot_payee_rule_service.dart';
import '../services/sync_service.dart';
import '../services/widget_data_service.dart';
import '../theme/app_theme.dart';
import '../utils/home_loan_calculator.dart';
import 'payee_rules_screen.dart';

class ShareExpenseSheet extends StatefulWidget {
  final String imagePath;
  final VoidCallback? onLogged;

  const ShareExpenseSheet({super.key, required this.imagePath, this.onLogged});

  static const MethodChannel _shareChannel = MethodChannel(
    'com.abhilash.manikutti/share',
  );

  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    VoidCallback? onLogged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          ShareExpenseSheet(imagePath: imagePath, onLogged: onLogged),
    );
  }

  @override
  State<ShareExpenseSheet> createState() => _ShareExpenseSheetState();
}

class _ShareExpenseSheetState extends State<ShareExpenseSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _ruleLabelController = TextEditingController();
  final _rulePatternController = TextEditingController();
  final _transferToController = TextEditingController();

  bool _extracting = true;
  bool _saving = false;
  bool _autoLogEnabled = false;
  bool _savePayeeRule = false;
  bool _markMatchingDuePaid = true;

  ScreenshotLedgerTarget _target = ScreenshotLedgerTarget.personal;
  String _type = 'Expense';
  String _category = 'Other';
  String _bankAccount = TransactionModel.bankSbi;
  String _sourceLabel = 'Scanning...';
  String? _matchedRuleLabel;
  String? _linkedDueTitle;
  DateTime _selectedDate = DateTime.now().toUtc();
  List<String> _categories = List<String>.from(
    CategoryService.defaultCategories,
  );
  String _rawOcr = '';

  @override
  void initState() {
    super.initState();
    _initAndExtract();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _ruleLabelController.dispose();
    _rulePatternController.dispose();
    _transferToController.dispose();
    super.dispose();
  }

  String _guessPatternFromOcr(String ocrText, String merchant) {
    final phoneMatch = RegExp(
      r'(?:\+?91[\s\-]?)?([6-9]\d{9})',
    ).firstMatch(ocrText.replaceAll(RegExp(r'\s+'), ''));
    if (phoneMatch != null && phoneMatch.group(1) != null) {
      final phone = phoneMatch.group(1)!;
      return merchant.isNotEmpty ? '$phone, $merchant' : phone;
    }
    final upiMatch = RegExp(r'[a-zA-Z0-9._\-]+@[a-zA-Z]+').firstMatch(ocrText);
    if (upiMatch != null) {
      final upi = upiMatch.group(0)!;
      return merchant.isNotEmpty ? '$upi, $merchant' : upi;
    }
    return merchant;
  }

  Future<void> _initAndExtract() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoLogEnabled = prefs.getBool('auto_log_shared_screenshots') ?? false;
      final storedCats = await CategoryService.instance.getExpenseCategories();
      final mergedCats = <String>{
        ...storedCats,
        ...CategoryService.defaultCategories,
      }.toList();

      final extracted = await ScreenshotExtractorService.instance
          .extractFromImageFile(widget.imagePath);

      if (!mounted) return;
      if (extracted.category.isNotEmpty &&
          !mergedCats.contains(extracted.category)) {
        mergedCats.add(extracted.category);
      }

      setState(() {
        _categories = mergedCats;
        if (extracted.amount > 0) {
          _amountController.text = extracted.amount.toStringAsFixed(
            extracted.amount % 1 == 0 ? 0 : 2,
          );
        }
        _noteController.text = extracted.note;
        _type = extracted.type;
        _target = extracted.suggestedTarget;
        _matchedRuleLabel = extracted.matchedRuleLabel;
        _linkedDueTitle = extracted.linkedDueTitle;
        if (extracted.transferToMember != null) {
          _transferToController.text = extracted.transferToMember!;
        }
        if (extracted.category == 'Home Loan' &&
            (_linkedDueTitle == null || _linkedDueTitle!.isEmpty)) {
          _linkedDueTitle = 'Home loan';
        }

        if (_categories.contains(extracted.category)) {
          _category = extracted.category;
        } else if (extracted.type == 'Income') {
          _category = 'Salary';
        } else {
          _category = _categories.contains('Other')
              ? 'Other'
              : _categories.first;
        }

        _bankAccount = extracted.bankAccount.toUpperCase().contains('CANARA')
            ? TransactionModel.bankCanara
            : TransactionModel.bankSbi;
        _selectedDate = extracted.date.toUtc();
        _rawOcr = extracted.rawOcrText;
        _sourceLabel = _humanSourceLabel(extracted.source);

        _ruleLabelController.text =
            extracted.matchedRuleLabel ?? extracted.merchant;
        _rulePatternController.text = _guessPatternFromOcr(
          extracted.rawOcrText,
          extracted.merchant,
        );
        _extracting = false;
      });

      if (_autoLogEnabled &&
          extracted.amount > 0 &&
          extracted.confidence >= 0.70) {
        await _saveTransaction(forwardToWhatsApp: false, autoTriggered: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _extracting = false;
          _sourceLabel = 'Manual Verification';
        });
      }
    }
  }

  String _humanSourceLabel(String src) {
    switch (src) {
      case 'payee_rule':
        return _matchedRuleLabel != null
            ? 'Payee Rule: $_matchedRuleLabel'
            : 'Saved Payee Rule';
      case 'gemini_text':
        return 'Gemini AI (Smart Text)';
      case 'gemini_vision':
        return 'Gemini AI (Vision)';
      case 'local_disabled_by_admin':
        return 'Offline OCR (AI Disabled)';
      default:
        return 'Offline OCR & Rules';
    }
  }

  Future<void> _recordHomeLoanRepayment({
    required String familyCode,
    required double amount,
    required DateTime txDate,
  }) async {
    final rawHistory = await ApiService.instance.fetchHomeLoanHistory(
      familyCode,
    );
    final history = rawHistory
        .map((j) => HomeLoanEntry.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    history.sort((a, b) {
      final da = DateTime.tryParse(a.date) ?? DateTime(1970);
      final db = DateTime.tryParse(b.date) ?? DateTime(1970);
      return da.compareTo(db);
    });

    final rate = HomeLoanCalculator.estimateAnnualRate(history);
    // If user sends ₹12,500 to Mom to pay ₹12,000 EMI, keep EMI payment aligned with prior EMI if > 0 & <= amount
    final emiAmount =
        history.isNotEmpty &&
            history.last.totalPayment > 0 &&
            amount > history.last.totalPayment &&
            amount - history.last.totalPayment <= 1000
        ? history.last.totalPayment
        : amount;

    final calc = HomeLoanCalculator.calculateBreakdown(
      sortedHistory: history,
      selectedDate: txDate.toLocal(),
      annualRatePercent: rate,
      plannedTotalPayment: emiAmount,
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(txDate.toLocal());
    await ApiService.instance.addHomeLoanRepayment(
      date: dateStr,
      totalPayment: calc.totalPayment,
      principal: calc.principal,
      interest: calc.interest,
      balance: calc.remainingBalance,
      familyCode: familyCode,
    );
  }

  Future<void> _tryMarkMatchingMonthlyDuePaid({
    required String familyCode,
    required String utcIso,
    required double amount,
  }) async {
    if (familyCode.isEmpty) return;
    try {
      final monthlyItems = await ApiService.instance.fetchMonthlyExpenses(
        familyCode,
      );
      if (monthlyItems.isEmpty) return;

      final targetHint =
          (_linkedDueTitle ??
                  (_target == ScreenshotLedgerTarget.homeLoan
                      ? 'home loan'
                      : ''))
              .trim()
              .toLowerCase();

      dynamic match;
      if (targetHint.isNotEmpty) {
        for (final item in monthlyItems) {
          final title = (item['title'] ?? '').toString().trim().toLowerCase();
          if (title == targetHint || title.contains(targetHint)) {
            match = item;
            break;
          }
        }
      }

      // Fallback: match by exact amount if unpaid this month
      match ??= monthlyItems.cast<dynamic>().firstWhere(
        (item) =>
            (item['status'] ?? '').toString().toLowerCase() != 'paid' &&
            ((item['amount'] as num?)?.toDouble() ?? 0) == amount,
        orElse: () => null,
      );

      if (match != null &&
          match['id'] != null &&
          (match['status'] ?? '').toString().toLowerCase() != 'paid') {
        await ApiService.instance.markMonthlyExpensePaid(
          match['id'] as int,
          utcIso,
          logToFamily: false,
        );
      }
    } catch (_) {
      // Non-blocking best-effort monthly due auto-mark
    }
  }

  Future<void> _saveTransaction({
    required bool forwardToWhatsApp,
    bool autoTriggered = false,
  }) async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_savePayeeRule && _rulePatternController.text.trim().isNotEmpty) {
        final patterns = _rulePatternController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final label = _ruleLabelController.text.trim().isEmpty
            ? patterns.first
            : _ruleLabelController.text.trim();
        await ScreenshotPayeeRuleService.instance.saveRule(
          ScreenshotPayeeRule(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            matchPatterns: patterns,
            category: _category,
            target: _target,
            transactionType: _type,
            linkedDueTitle: _linkedDueTitle,
            transferToMember: _transferToController.text.trim().isEmpty
                ? null
                : _transferToController.text.trim(),
            customNote: _noteController.text.trim(),
          ),
        );
        await CategoryService.instance.addCategory(_category);
      }

      final note = _noteController.text.trim().isEmpty
          ? 'Screenshot Payment'
          : _noteController.text.trim();
      final utcIso = _selectedDate.toUtc().toIso8601String();
      final userEmail = await ApiService.instance.getUserEmail() ?? '';
      final nickname =
          await ApiService.instance.getMemberNickname() ??
          userEmail.split('@').first;
      final familyCode = await ApiService.instance.getCachedFamilyCode() ?? '';

      if (_target == ScreenshotLedgerTarget.family ||
          _target == ScreenshotLedgerTarget.homeLoan) {
        // 1. If Home Loan mode, also log repayment to HomeLoan_Ledger
        if (_target == ScreenshotLedgerTarget.homeLoan &&
            familyCode.isNotEmpty) {
          try {
            await _recordHomeLoanRepayment(
              familyCode: familyCode,
              amount: amount,
              txDate: _selectedDate,
            );
          } catch (_) {
            // Continue logging to Family_Expenses even if HomeLoan_Ledger fails
          }
        }

        // 2. Log into Family_Expenses (visible to all family members in History & Family Card)
        final effectiveCategory =
            _target == ScreenshotLedgerTarget.homeLoan && _category == 'Other'
            ? 'Home Loan'
            : _category;
        final ok = await ApiService.instance.createTransaction(
          sheetName: 'Family_Expenses',
          familyCode: familyCode,
          expense: {
            'date': utcIso,
            'amount': amount,
            'category': effectiveCategory,
            'note': note,
          },
        );
        if (!ok) {
          await DbHelper.instance.insertTransaction(
            TransactionModel(
              date: utcIso,
              amount: amount,
              category: effectiveCategory,
              note: note,
              isPaid: true,
              type: 'Family',
              addedBy: userEmail,
              familyCode: familyCode,
              bankAccount: _bankAccount,
              synced: false,
            ),
          );
        }

        // 3. Auto-mark matching Monthly Due as Paid (e.g. Home loan / Bajaj / Sunitha)
        if (_markMatchingDuePaid && familyCode.isNotEmpty) {
          await _tryMarkMatchingMonthlyDuePaid(
            familyCode: familyCode,
            utcIso: utcIso,
            amount: amount,
          );
        }

        // 4. Optional inter-member pool transfer (e.g. Abhilash -> Nisha ₹12,500)
        final transferTo = _transferToController.text.trim();
        if (transferTo.isNotEmpty && familyCode.isNotEmpty) {
          await ApiService.instance.createFamilyTransfer(
            fromMember: nickname,
            toMember: transferTo,
            amount: amount,
            note: note,
            familyCode: familyCode,
            date: utcIso,
          );
        }

        unawaited(SyncService.instance.syncData());
      } else {
        await DbHelper.instance.insertTransaction(
          TransactionModel(
            date: utcIso,
            amount: amount,
            category: _category,
            note: note,
            isPaid: true,
            type: _type,
            addedBy: userEmail,
            bankAccount: _bankAccount,
            synced: false,
          ),
        );
        SyncService.instance.syncData();
        await WidgetDataService.updateWidgetData();
      }

      await NotificationService.instance.showImmediateNotification(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: autoTriggered
            ? 'Auto-Logged Screenshot: ₹${amount.toStringAsFixed(0)}'
            : 'Expense Logged: ₹${amount.toStringAsFixed(0)}',
        body: '$_category • $note',
        payload: 'transaction_logged',
      );

      if (forwardToWhatsApp) {
        final caption =
            'Paid ₹${amount.toStringAsFixed(0)} ($note) — logged in Manikutti';
        await ShareExpenseSheet._shareChannel.invokeMethod<bool>('shareImage', {
          'path': widget.imagePath,
          'caption': caption,
          'whatsappOnly': true,
        });
      }

      widget.onLogged?.call();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              forwardToWhatsApp
                  ? 'Logged ₹${amount.toStringAsFixed(0)} & opening WhatsApp...'
                  : 'Logged ₹${amount.toStringAsFixed(0)} (${_target.displayName} • $_category)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to log payment: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final categoryItems = _type == 'Income'
        ? ['Salary', 'Kadam', 'Investment', 'Other']
        : _categories;

    if (!categoryItems.contains(_category)) {
      _category = categoryItems.contains('Other')
          ? 'Other'
          : categoryItems.first;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.receipt_long),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Payment Screenshot',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _sourceLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Manage Payee Rules',
                  icon: const Icon(Icons.rule_folder_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PayeeRulesScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_extracting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Extracting payment amount & merchant...'),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Paid To / Note',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Save To',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SegmentedButton<ScreenshotLedgerTarget>(
                segments: const [
                  ButtonSegment(
                    value: ScreenshotLedgerTarget.personal,
                    label: Text('Personal', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.person_outline, size: 16),
                  ),
                  ButtonSegment(
                    value: ScreenshotLedgerTarget.homeLoan,
                    label: Text('Home Loan', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.home_work_outlined, size: 16),
                  ),
                ],
                selected: {_target},
                onSelectionChanged: (s) {
                  setState(() {
                    _target = s.first;
                    if (_target == ScreenshotLedgerTarget.homeLoan &&
                        _categories.contains('Home Loan')) {
                      _category = 'Home Loan';
                      _linkedDueTitle ??= 'Home loan';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: categoryItems
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _bankAccount,
                      decoration: InputDecoration(
                        labelText: 'Bank',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items:
                          const [
                                TransactionModel.bankSbi,
                                TransactionModel.bankCanara,
                              ]
                              .map(
                                (b) =>
                                    DropdownMenuItem(value: b, child: Text(b)),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _bankAccount = v);
                      },
                    ),
                  ),
                ],
              ),
              if (_target != ScreenshotLedgerTarget.personal) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    _target == ScreenshotLedgerTarget.homeLoan
                        ? 'Log Home Loan repayment + Family Expense & mark "Home loan" Paid'
                        : 'Also mark matching Monthly Due as Paid (if found)',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  value: _markMatchingDuePaid,
                  onChanged: (v) =>
                      setState(() => _markMatchingDuePaid = v ?? true),
                ),
                TextField(
                  controller: _transferToController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Pool Transfer To Member (optional, e.g. Nisha)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Remember category & destination for this payee/number',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                value: _savePayeeRule,
                onChanged: (v) => setState(() => _savePayeeRule = v),
              ),
              if (_savePayeeRule) ...[
                TextField(
                  controller: _ruleLabelController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Payee Name (e.g. Athulya or Nisha)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _rulePatternController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Phone / UPI / Name to Match',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Auto-log next time',
                  style: TextStyle(fontSize: 13),
                ),
                value: _autoLogEnabled,
                onChanged: (v) async {
                  setState(() => _autoLogEnabled = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('auto_log_shared_screenshots', v);
                },
              ),
              if (_rawOcr.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'View scanned receipt text',
                    style: TextStyle(fontSize: 12),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _rawOcr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _saveTransaction(forwardToWhatsApp: false),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Log & Notify'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _saveTransaction(forwardToWhatsApp: true),
                      icon: const Icon(Icons.share),
                      label: const Text('Log & WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
