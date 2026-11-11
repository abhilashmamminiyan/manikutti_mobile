import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../services/notification_service.dart';
import '../services/screenshot_extractor_service.dart';
import '../services/sync_service.dart';
import '../services/widget_data_service.dart';
import '../theme/app_theme.dart';

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

  bool _extracting = true;
  bool _saving = false;
  bool _autoLogEnabled = false;
  bool _isFamilyExpense = false;

  String _type = 'Expense';
  String _category = 'Food';
  String _bankAccount = TransactionModel.bankSbi;
  String _sourceLabel = 'Scanning...';
  DateTime _selectedDate = DateTime.now().toUtc();
  List<String> _categories = CategoryService.defaultCategories;
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
    super.dispose();
  }

  Future<void> _initAndExtract() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoLogEnabled = prefs.getBool('auto_log_shared_screenshots') ?? false;
      final cats = await CategoryService.instance.getExpenseCategories();
      if (cats.isNotEmpty) {
        _categories = cats;
      }

      final extracted = await ScreenshotExtractorService.instance
          .extractFromImageFile(widget.imagePath);

      if (!mounted) return;
      setState(() {
        if (extracted.amount > 0) {
          _amountController.text = extracted.amount.toStringAsFixed(
            extracted.amount % 1 == 0 ? 0 : 2,
          );
        }
        _noteController.text = extracted.note;
        _type = extracted.type;
        if (_categories.contains(extracted.category)) {
          _category = extracted.category;
        } else if (extracted.type == 'Income') {
          _category = 'Salary';
        } else {
          _category = _categories.first;
        }
        _bankAccount = extracted.bankAccount.toUpperCase().contains('CANARA')
            ? TransactionModel.bankCanara
            : TransactionModel.bankSbi;
        _selectedDate = extracted.date.toUtc();
        _rawOcr = extracted.rawOcrText;
        _sourceLabel = _humanSourceLabel(extracted.source);
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
      final note = _noteController.text.trim().isEmpty
          ? 'Screenshot Payment'
          : _noteController.text.trim();
      final utcIso = _selectedDate.toUtc().toIso8601String();
      final userEmail = await ApiService.instance.getUserEmail() ?? '';

      if (_isFamilyExpense) {
        final familyCode = await ApiService.instance.getCachedFamilyCode();
        final ok = await ApiService.instance.createTransaction(
          sheetName: 'Family_Expenses',
          familyCode: familyCode,
          expense: {
            'date': utcIso,
            'amount': amount,
            'category': _category,
            'note': note,
          },
        );
        if (!ok) {
          // Offline safety: store locally in personal ledger queued for sync
          await DbHelper.instance.insertTransaction(
            TransactionModel(
              date: utcIso,
              amount: amount,
              category: _category,
              note: '[Family] $note',
              isPaid: true,
              type: 'Expense',
              addedBy: userEmail,
              bankAccount: _bankAccount,
              synced: false,
            ),
          );
        }
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
                  : 'Logged ₹${amount.toStringAsFixed(0)} ($_category)',
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
      _category = categoryItems.first;
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Family Expense',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: _isFamilyExpense,
                      onChanged: (v) => setState(() => _isFamilyExpense = v),
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
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
                  ),
                ],
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
