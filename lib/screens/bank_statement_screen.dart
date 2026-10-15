import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'transactions_log_screen.dart';

enum StatementFilterTab { readyToImport, all, duplicates }

class StatementTransactionItem {
  final String rawDate; // YYYY-MM-DD
  final double amount;
  final String type; // Expense or Income
  String category;
  final String description;
  String note;
  bool isSelected;
  bool isDuplicate;
  String? duplicateReason;
  late final TextEditingController noteController;

  StatementTransactionItem({
    required this.rawDate,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.note,
    this.isSelected = true,
    this.isDuplicate = false,
    this.duplicateReason,
  }) {
    noteController = TextEditingController(text: note);
  }

  void dispose() {
    noteController.dispose();
  }
}

class BankStatementScreen extends StatefulWidget {
  const BankStatementScreen({super.key});

  @override
  State<BankStatementScreen> createState() => _BankStatementScreenState();
}

class _BankStatementScreenState extends State<BankStatementScreen> {
  bool _isPicking = false;
  bool _isParsing = false;
  bool _isSaving = false;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _errorMessage;

  List<StatementTransactionItem> _items = [];
  StatementFilterTab _currentTab = StatementFilterTab.readyToImport;

  final List<String> _categories = [
    'Food',
    'Housing',
    'Transport',
    'Utilities',
    'Leisure',
    'Health',
    'Shopping',
    'Salary',
    'Investment',
    'General',
  ];

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndParseStatement() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'csv', 'xlsx', 'xls'],
        withData: true, // Needed for web/desktop and direct byte access
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final file = result.files.first;
      Uint8List? fileBytes = file.bytes;

      if (fileBytes == null && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        setState(() {
          _isPicking = false;
          _errorMessage = 'Could not read the selected file.';
        });
        return;
      }

      // Check if file is a PDF and if it's password protected
      if (file.name.toLowerCase().endsWith('.pdf')) {
        bool isProtected = false;
        try {
          final testDoc = PdfLoadedDocument(fileBytes);
          testDoc.close();
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('password') ||
              msg.contains('encrypted') ||
              msg.contains('security')) {
            isProtected = true;
          } else {
            final sample = String.fromCharCodes(fileBytes.take(4096));
            if (sample.contains('/Encrypt')) {
              isProtected = true;
            }
          }
        }

        if (isProtected) {
          setState(() => _isPicking = false);
          final unlocked = await _showPdfPasswordDialog(
            context,
            fileBytes,
            file.name,
          );
          if (unlocked == null) {
            // User cancelled
            return;
          }
          fileBytes = unlocked;
        }
      }

      setState(() {
        _isPicking = false;
        _isParsing = true;
        _selectedFileName = file.name;
        _selectedFileSize = file.size;
        _errorMessage = null;
      });

      // Send to backend Gemini parser API
      final parseResult = await ApiService.instance.parseBankStatement(
        fileBytes: fileBytes,
        fileName: file.name,
      );

      if (!mounted) return;

      if (parseResult['success'] == true &&
          parseResult['transactions'] is List) {
        final List<dynamic> rawList = parseResult['transactions'];
        await _processParsedTransactions(rawList);
      } else {
        // If file is CSV, try local fallback
        if (file.name.toLowerCase().endsWith('.csv')) {
          final text = utf8.decode(fileBytes, allowMalformed: true);
          final localParsed = _parseCsvLocally(text);
          if (localParsed.isNotEmpty) {
            await _processParsedTransactions(localParsed);
            return;
          }
        }

        setState(() {
          _isParsing = false;
          _errorMessage =
              parseResult['error'] ??
              'Failed to parse transactions from statement. Please ensure it is a valid bank statement.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPicking = false;
          _isParsing = false;
          _errorMessage = 'Error reading file: $e';
        });
      }
    }
  }

  Future<Uint8List?> _showPdfPasswordDialog(
    BuildContext context,
    Uint8List originalBytes,
    String fileName,
  ) async {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? errorText;
    bool isUnlocking = false;

    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final theme = Theme.of(dialogContext);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Protected PDF Statement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'The PDF "$fileName" is protected with a password. Enter your password below to unlock and extract transactions.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.outline,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Statement Password',
                        hintText: 'Enter bank statement password',
                        prefixIcon: const Icon(Icons.key_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() => obscure = !obscure);
                          },
                        ),
                        errorText: errorText,
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceContainer
                            : AppTheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) {
                        _attemptUnlock(
                          dialogContext,
                          setDialogState,
                          originalBytes,
                          passwordController.text,
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Helpful Bank Password Hints Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2829)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Common Bank Password Patterns',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• SBI: 5 letters of Name (lower) + last 4 digits of Mobile, or DOB (DDMMYYYY) + last 4 digits of Mobile.\n'
                            '• HDFC: Customer ID (8-9 digits).\n'
                            '• ICICI: 4 letters of Name (lower) + DOB in DDMM format.\n'
                            '• Axis Bank: 4 letters of Name (CAPS) + last 4 digits of Mobile/Cust ID.\n'
                            '• Federal Bank: 14-digit Account Number or Customer ID.\n'
                            '• Canara Bank: 4 letters of Name (lower) + last 4 digits of Mobile.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: AppTheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUnlocking
                      ? null
                      : () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isUnlocking
                      ? null
                      : () {
                          _attemptUnlock(
                            dialogContext,
                            setDialogState,
                            originalBytes,
                            passwordController.text,
                          );
                        },
                  child: isUnlocking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Unlock & Parse'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _attemptUnlock(
    BuildContext dialogContext,
    void Function(void Function()) setDialogState,
    Uint8List originalBytes,
    String password,
  ) {
    if (password.trim().isEmpty) {
      setDialogState(() {
        // Validation error
      });
      return;
    }

    setDialogState(() {
      // Begin unlocking
    });

    try {
      final doc = PdfLoadedDocument(originalBytes, password: password.trim());
      // Remove passwords so the resulting document is unlocked for the AI parser
      doc.security.userPassword = '';
      doc.security.ownerPassword = '';
      final unlockedBytes = doc.saveSync();
      doc.close();

      // Return decrypted bytes
      Navigator.pop(dialogContext, Uint8List.fromList(unlockedBytes));
    } catch (e) {
      setDialogState(() {
        // Failed
      });
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password. Please verify and try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _parseCsvLocally(String csvText) {
    final lines = csvText.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
    if (lines.length < 2) return [];

    final results = <Map<String, dynamic>>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',').map((c) => c.replaceAll('"', '').trim()).toList();
      if (cols.length < 3) continue;

      // Simple heuristic for date, desc, amount
      final dateStr = cols[0];
      final desc = cols[1];
      final amount = double.tryParse(cols[2].replaceAll(',', '')) ?? 0.0;
      if (amount <= 0) continue;

      results.add({
        'date': dateStr,
        'amount': amount,
        'type': 'Expense',
        'category': 'General',
        'description': desc,
        'note': desc,
      });
    }
    return results;
  }

  Future<void> _processParsedTransactions(List<dynamic> rawList) async {
    // 1. Fetch existing local transactions from SQLite for duplicate detection
    final existingTransactions =
        await DbHelper.instance.getAllTransactions();

    // 2. Dispose previous controllers
    for (final item in _items) {
      item.dispose();
    }

    final List<StatementTransactionItem> newItems = [];

    for (final raw in rawList) {
      final String rawDate = (raw['date'] ?? '').toString().trim();
      final double amount = (raw['amount'] is num)
          ? (raw['amount'] as num).toDouble()
          : (double.tryParse(raw['amount'].toString()) ?? 0.0);
      final String type = (raw['type'] == 'Income') ? 'Income' : 'Expense';
      final String category = (raw['category'] ?? 'General').toString().trim();
      final String description = (raw['description'] ?? 'Bank Transaction').toString().trim();
      final String note = (raw['note'] ?? description).toString().trim();

      if (amount <= 0 || rawDate.isEmpty) continue;

      // Normalize candidate date string YYYY-MM-DD
      String normalizedCandidateDate = rawDate;
      try {
        final parsed = DateTime.parse(rawDate);
        normalizedCandidateDate = DateFormat('yyyy-MM-dd').format(parsed);
      } catch (_) {
        // keep as is
      }

      // Check if duplicate exists on the SAME DATE with SAME AMOUNT
      bool isDup = false;
      String? dupReason;

      for (final existing in existingTransactions) {
        String existingDateOnly = existing.date;
        try {
          final dt = DateTime.parse(existing.date);
          existingDateOnly = DateFormat('yyyy-MM-dd').format(dt.toLocal());
        } catch (_) {}

        final isSameDate = existingDateOnly == normalizedCandidateDate;
        final isSameAmount = (existing.amount - amount).abs() < 0.01;
        final isSameType = (existing.type == type) ||
            (type == 'Expense' && existing.type != 'Income');

        if (isSameDate && isSameAmount && isSameType) {
          isDup = true;
          dupReason =
              'Already logged on $normalizedCandidateDate: ₹${existing.amount.toStringAsFixed(2)} (${existing.note.isNotEmpty ? existing.note : existing.category})';
          break;
        }
      }

      newItems.add(
        StatementTransactionItem(
          rawDate: normalizedCandidateDate,
          amount: amount,
          type: type,
          category: _categories.contains(category) ? category : 'General',
          description: description,
          note: note,
          isDuplicate: isDup,
          isSelected: !isDup, // Duplicate is filtered out / unselected by default!
          duplicateReason: dupReason,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _items = newItems;
        _isParsing = false;
        // If all items are duplicates, open all tab, otherwise ready to import
        final nonDupCount = _items.where((i) => !i.isDuplicate).length;
        _currentTab = nonDupCount > 0
            ? StatementFilterTab.readyToImport
            : StatementFilterTab.all;
      });
    }
  }

  List<StatementTransactionItem> get _displayedItems {
    switch (_currentTab) {
      case StatementFilterTab.readyToImport:
        return _items.where((i) => !i.isDuplicate).toList();
      case StatementFilterTab.duplicates:
        return _items.where((i) => i.isDuplicate).toList();
      case StatementFilterTab.all:
        return _items;
    }
  }

  void _selectAll(bool select) {
    setState(() {
      for (final item in _displayedItems) {
        item.isSelected = select;
      }
    });
  }

  void _selectNonDuplicatesOnly() {
    setState(() {
      for (final item in _items) {
        item.isSelected = !item.isDuplicate;
      }
    });
  }

  Future<void> _saveSelectedTransactions() async {
    final selectedItems = _items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one transaction to import.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Import'),
        content: Text(
          'Are you sure you want to save ${selectedItems.length} transactions to your Google Sheet and local Transaction Logs?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final userEmail = await ApiService.instance.getUserEmail();

      // Format payload for batch API and local SQLite
      final List<Map<String, dynamic>> sheetPayload = [];
      final List<TransactionModel> localModels = [];

      for (final item in selectedItems) {
        // Read updated note from controller
        final finalNote = item.noteController.text.trim().isNotEmpty
            ? item.noteController.text.trim()
            : item.note;

        DateTime parsedDate;
        try {
          parsedDate = DateTime.parse(item.rawDate);
        } catch (_) {
          parsedDate = DateTime.now();
        }

        final utcDate = parsedDate.toUtc().toIso8601String();

        sheetPayload.add({
          'date': utcDate,
          'amount': item.amount,
          'category': item.category,
          'note': finalNote,
          'isPaid': true,
          'type': item.type,
        });

        localModels.add(
          TransactionModel(
            date: utcDate,
            amount: item.amount,
            category: item.category,
            note: finalNote,
            isPaid: true,
            type: item.type,
            addedBy: userEmail,
            synced: true, // directly synced via batch API
          ),
        );
      }

      // 1. Batch Save to Google Sheets
      final success = await ApiService.instance.batchCreateTransactions(
        sheetName: 'Personal_Expenses',
        expenses: sheetPayload,
      );

      if (!success) {
        throw Exception(
          'Google Sheets batch sync failed. Please check your internet connection.',
        );
      }

      // 2. Batch insert to local SQLite database
      await DbHelper.instance.batchInsertTransactions(localModels);

      if (!mounted) return;
      setState(() => _isSaving = false);

      // 3. Show celebration / completion sheet
      _showSuccessBottomSheet(selectedItems.length);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save transactions: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showSuccessBottomSheet(int count) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Statement Logged Successfully!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$count transactions have been recorded in your Google Sheet and local Transaction Logs.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionsLogScreen(
                                initialFilter: 'Personal',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('View Logs'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, true); // Return to dashboard
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('AI Insights'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final readyCount = _items.where((i) => !i.isDuplicate).length;
    final duplicateCount = _items.where((i) => i.isDuplicate).length;
    final selectedCount = _items.where((i) => i.isSelected).length;

    double totalSelectedAmount = 0;
    for (final item in _items.where((i) => i.isSelected)) {
      totalSelectedAmount += item.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.uploadBankStatement),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.upload_file_rounded),
              tooltip: 'Choose another statement',
              onPressed: _isSaving || _isParsing ? null : _pickAndParseStatement,
            ),
        ],
      ),
      bottomNavigationBar: _items.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceContainer
                    : AppTheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF2C3233)
                        : AppTheme.outlineVariant.withOpacity(0.25),
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$selectedCount selected',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${totalSelectedAmount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (_isSaving || selectedCount == 0)
                          ? null
                          : _saveSelectedTransactions,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Import & Save',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: _items.isEmpty
          ? _buildUploadPlaceholder(theme, isDark, l10n)
          : _buildReviewContent(
              theme,
              isDark,
              readyCount,
              duplicateCount,
            ),
    );
  }

  Widget _buildUploadPlaceholder(
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: AppTheme.heroCardGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.editorialShadow,
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.uploadBankStatement,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your monthly bank statement (.pdf, .csv, .xlsx) to automatically parse all transactions, add notes, filter out duplicates, and sync to Google Sheets.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.outline,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            if (_isPicking || _isParsing) ...[
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                _isParsing
                    ? 'AI is parsing statement transactions...\nFiltering duplicates on same date'
                    : 'Selecting file...',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ] else ...[
              InkWell(
                onTap: _pickAndParseStatement,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to Choose Statement File',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports PDF, CSV, Excel formats',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewContent(
    ThemeData theme,
    bool isDark,
    int readyCount,
    int duplicateCount,
  ) {
    final displayed = _displayedItems;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File info banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_rounded, size: 20, color: AppTheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName ?? 'Statement Document',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_selectedFileSize != null)
                              Text(
                                '${(_selectedFileSize! / 1024).toStringAsFixed(1)} KB • ${_items.length} total rows parsed',
                                style: const TextStyle(fontSize: 11, color: AppTheme.outline),
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: _pickAndParseStatement,
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Change', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Metrics row: Total | Ready | Duplicates
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Ready',
                        count: readyCount,
                        color: Colors.green,
                        icon: Icons.check_circle_outline_rounded,
                        isSelected: _currentTab == StatementFilterTab.readyToImport,
                        onTap: () => setState(() => _currentTab = StatementFilterTab.readyToImport),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Duplicates',
                        count: duplicateCount,
                        color: Colors.amber[800]!,
                        icon: Icons.filter_alt_outlined,
                        isSelected: _currentTab == StatementFilterTab.duplicates,
                        onTap: () => setState(() => _currentTab = StatementFilterTab.duplicates),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'All Rows',
                        count: _items.length,
                        color: AppTheme.primary,
                        icon: Icons.list_alt_rounded,
                        isSelected: _currentTab == StatementFilterTab.all,
                        onTap: () => setState(() => _currentTab = StatementFilterTab.all),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Duplicate info callout
                if (duplicateCount > 0 && _currentTab == StatementFilterTab.duplicates)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[900], size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$duplicateCount transaction(s) have matching dates and amounts with existing records. They are unselected by default to prevent duplicate entries.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.amber[200] : Colors.amber[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Batch Selection Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${displayed.length} item(s)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => _selectAll(true),
                          child: const Text('Select All', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => _selectAll(false),
                          child: const Text('Deselect', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: _selectNonDuplicatesOnly,
                          child: const Text('Only New', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // List of transaction items
        displayed.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _currentTab == StatementFilterTab.duplicates
                        ? 'No duplicate transactions detected! All rows are fresh.'
                        : 'No transactions found under this tab.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.outline),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = displayed[index];
                      return _buildTransactionRow(item, theme, isDark);
                    },
                    childCount: displayed.length,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.25),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(
    StatementTransactionItem item,
    ThemeData theme,
    bool isDark,
  ) {
    final isIncome = item.type == 'Income';
    final amountColor = isIncome ? Colors.green : (isDark ? Colors.red[300]! : Colors.red[700]!);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isDuplicate
              ? Colors.amber.withOpacity(0.5)
              : (item.isSelected
                  ? AppTheme.primary.withOpacity(0.4)
                  : (isDark ? const Color(0xFF2C3233) : AppTheme.outlineVariant.withOpacity(0.2))),
          width: item.isSelected ? 1.5 : 1.0,
        ),
      ),
      color: isDark ? AppTheme.darkSurfaceContainer : AppTheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Checkbox, Date, Amount, Type
            Row(
              children: [
                Checkbox(
                  value: item.isSelected,
                  activeColor: AppTheme.primary,
                  onChanged: (val) {
                    setState(() => item.isSelected = val ?? false);
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.rawDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isIncome ? Colors.green : Colors.red).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.type,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isIncome ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        style: const TextStyle(fontSize: 11, color: AppTheme.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}₹${item.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                  ),
                ),
              ],
            ),

            // Duplicate Alert Badge if duplicate
            if (item.isDuplicate) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber[800]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.duplicateReason ?? 'Duplicate: same date & amount already in database',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber[200] : Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Middle: Category Selector & Add Note Option
            Row(
              children: [
                // Category Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF374041) : AppTheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categories.contains(item.category) ? item.category : 'General',
                      isDense: true,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => item.category = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Add Note text field (Editable note per row)
                Expanded(
                  child: TextField(
                    controller: item.noteController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Add note for this transaction...',
                      hintStyle: const TextStyle(fontSize: 11, color: AppTheme.outline),
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF374041) : AppTheme.outlineVariant.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF374041) : AppTheme.outlineVariant.withOpacity(0.3),
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      item.note = val;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
