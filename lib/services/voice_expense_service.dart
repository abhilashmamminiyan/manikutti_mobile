import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'sync_service.dart';
import 'widget_data_service.dart';

class VoiceActionResult {
  final String action; // 'create' | 'delete' | 'error'
  final TransactionModel? transaction;
  final int deletedCount;
  final String message;
  final bool success;

  const VoiceActionResult({
    required this.action,
    this.transaction,
    this.deletedCount = 0,
    required this.message,
    required this.success,
  });

  bool get isDelete => action == 'delete';
  bool get isCreate => action == 'create';
}

class VoiceExpenseService {
  static final VoiceExpenseService instance = VoiceExpenseService._init();

  VoiceExpenseService._init();

  /// Intelligent client-side rule-based fallback parser for Manglish, Malayalam & English
  /// Guaranteed to work 100% offline without any internet connection.
  Map<String, dynamic> parseLocally(String text, {String defaultBank = 'SBI'}) {
    final lower = text.toLowerCase().trim();

    // 1. Detect Delete / Undo Intent
    final isDeleteKeyword =
        lower.contains('delete') ||
        lower.contains('remove') ||
        lower.contains('undo') ||
        lower.contains('cancel') ||
        lower.contains('clear') ||
        lower.contains('ഡിലീറ്റ്') ||
        lower.contains('കളയുക') ||
        lower.contains('ഒഴിവാക്കുക') ||
        lower.contains('മാറ്റുക');

    final hasDeleteTarget =
        lower.contains('transaction') ||
        lower.contains('transactions') ||
        lower.contains('expense') ||
        lower.contains('expenses') ||
        lower.contains('record') ||
        lower.contains('entry') ||
        lower.contains('entries') ||
        lower.contains('last') ||
        lower.contains('recent') ||
        lower.contains('avasaana') ||
        lower.contains('avasaanathe') ||
        lower.contains('kazhinja') ||
        lower.contains('ഇടപാട്') ||
        lower.contains('അവസാന');

    if (isDeleteKeyword && hasDeleteTarget) {
      int count = 1;
      if (RegExp(
            r'\b(two|randu|rendu|രണ്ട്)\b',
            caseSensitive: false,
          ).hasMatch(lower) ||
          lower.contains('2')) {
        count = 2;
      } else if (RegExp(
            r'\b(three|moonnu|മൂന്ന്)\b',
            caseSensitive: false,
          ).hasMatch(lower) ||
          lower.contains('3')) {
        count = 3;
      } else if (RegExp(
            r'\b(four|naalu|നാല്)\b',
            caseSensitive: false,
          ).hasMatch(lower) ||
          lower.contains('4')) {
        count = 4;
      } else if (RegExp(
            r'\b(five|anchu|അഞ്ച്)\b',
            caseSensitive: false,
          ).hasMatch(lower) ||
          lower.contains('5')) {
        count = 5;
      } else {
        final match = RegExp(r'\b(\d+)\b').firstMatch(lower);
        if (match != null && match.group(1) != null) {
          count = int.tryParse(match.group(1)!) ?? 1;
        }
      }
      if (count > 10) count = 10;

      return {
        'action': 'delete',
        'count': count,
        'amount': 0.0,
        'category': 'Other',
        'note': text,
        'type': 'Expense',
        'bankAccount': defaultBank,
      };
    }

    // 2. Amount Extraction
    double amount = 0;
    final numMatch = RegExp(
      r'(?:₹|rs\.?|inr|roopa|rupa|roopakku|rupakku|രൂപ)?\s*(\d+(?:\.\d+)?)\s*(?:₹|rs\.?|inr|roopa|rupa|roopakku|rupakku|രൂപ)?',
      caseSensitive: false,
    ).firstMatch(lower);

    if (numMatch != null && numMatch.group(1) != null) {
      amount = double.tryParse(numMatch.group(1)!) ?? 0;
    }

    // 3. Type Detection
    String type = 'Expense';
    if (lower.contains('family') ||
        lower.contains('കുടുംബം') ||
        lower.contains('veettil') ||
        lower.contains('വീട്ടിൽ')) {
      type = 'Family';
    } else if (lower.contains('salary') ||
        lower.contains('income') ||
        lower.contains('kittiyathu') ||
        lower.contains('കിട്ടി') ||
        lower.contains('വരുമാനം') ||
        lower.contains('credited') ||
        lower.contains('thannu') ||
        lower.contains('thanu') ||
        lower.contains('thannathu') ||
        lower.contains('തന്നു') ||
        lower.contains('തന്നത്') ||
        lower.contains('കിട്ടിയത്') ||
        lower.contains('ലഭിച്ചു') ||
        lower.contains('ലഭിച്ച') ||
        lower.contains('വരവ്') ||
        lower.contains('received') ||
        lower.contains('got') ||
        lower.contains('cashback') ||
        lower.contains('refund') ||
        lower.contains('repaid') ||
        lower.contains('returned') ||
        lower.contains('deposit')) {
      type = 'Income';
    }

    // 4. Category & Note Detection
    String category = 'Other';
    String note = text;

    if (type == 'Income') {
      if (lower.contains('salary') || lower.contains('ശമ്പളം')) {
        category = 'Investment';
        note = 'Salary';
      } else if (lower.contains('cashback') || lower.contains('refund')) {
        category = 'Other';
        note = 'Cashback / Refund';
      } else {
        category = 'Other';
        final nameMatch = RegExp(
          r'^([a-zA-Z]+)\s+.*(?:thannu|thanu|thannathu|തന്നു)',
          caseSensitive: false,
        ).firstMatch(text.trim());
        if (nameMatch != null && nameMatch.group(1) != null) {
          note = 'Received from ${nameMatch.group(1)}';
        } else {
          note = text;
        }
      }
    } else if (lower.contains('petrol') ||
        lower.contains('diesel') ||
        lower.contains('auto') ||
        lower.contains('taxi') ||
        lower.contains('bus') ||
        lower.contains('train') ||
        lower.contains('fuel') ||
        lower.contains('യാത്ര') ||
        lower.contains('പെട്രോൾ')) {
      category = 'Transport';
      note = lower.contains('petrol') || lower.contains('പെട്രോൾ')
          ? 'Petrol'
          : 'Travel / Transport';
    } else if (lower.contains('chaya') ||
        lower.contains('tea') ||
        lower.contains('coffee') ||
        lower.contains('kadi') ||
        lower.contains('snack') ||
        lower.contains('food') ||
        lower.contains('meals') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('meen') ||
        lower.contains('fish') ||
        lower.contains('pachakkari') ||
        lower.contains('vegetable') ||
        lower.contains('swiggy') ||
        lower.contains('zomato') ||
        lower.contains('hotel') ||
        lower.contains('ഭക്ഷണം') ||
        lower.contains('ചായ')) {
      category = 'Food';
      if (lower.contains('chaya') || lower.contains('tea')) {
        note = 'Tea & Snacks';
      } else if (lower.contains('meen') || lower.contains('fish')) {
        note = 'Fish purchase';
      } else if (lower.contains('pachakkari') || lower.contains('vegetable')) {
        note = 'Vegetables';
      } else {
        note = 'Food & Dining';
      }
    } else if (lower.contains('wifi') ||
        lower.contains('recharge') ||
        lower.contains('current') ||
        lower.contains('kseb') ||
        lower.contains('electricity') ||
        lower.contains('water') ||
        lower.contains('rent') ||
        lower.contains('വാടക') ||
        lower.contains('കറണ്ട്')) {
      category = 'Housing';
      if (lower.contains('wifi')) {
        note = 'Wi-Fi Recharge';
      } else if (lower.contains('kseb') || lower.contains('current')) {
        note = 'Electricity (KSEB)';
      } else if (lower.contains('recharge')) {
        note = 'Mobile Recharge';
      } else {
        note = 'House & Utilities';
      }
    } else if (lower.contains('movie') ||
        lower.contains('cinema') ||
        lower.contains('theatre') ||
        lower.contains('film') ||
        lower.contains('hotstar') ||
        lower.contains('netflix') ||
        lower.contains('സിനിമ')) {
      category = 'Leisure';
      note = 'Movie & Entertainment';
    } else if (lower.contains('medicine') ||
        lower.contains('hospital') ||
        lower.contains('doctor') ||
        lower.contains('clinic') ||
        lower.contains('ഗുളിക') ||
        lower.contains('മരുന്ന്')) {
      category = 'Health';
      note = 'Medical & Pharmacy';
    } else if (lower.contains('dress') ||
        lower.contains('clothes') ||
        lower.contains('shopping') ||
        lower.contains('amazon') ||
        lower.contains('flipkart')) {
      category = 'Shopping';
      note = 'Shopping';
    }

    String bankAccount = defaultBank;
    if (lower.contains('canara') || lower.contains('കാനറ')) {
      bankAccount = TransactionModel.bankCanara;
    } else if (lower.contains('sbi') || lower.contains('എസ്.ബി.ഐ')) {
      bankAccount = TransactionModel.bankSbi;
    }

    return {
      'action': 'create',
      'amount': amount,
      'category': category,
      'note': note,
      'type': type,
      'bankAccount': bankAccount,
    };
  }

  /// Parses voice input via Gemini AI API (or local fallback), executes create/delete,
  /// updates SQLite, widgets, and returns a structured VoiceActionResult.
  Future<VoiceActionResult> processAndSaveVoiceExpense(
    String transcript,
  ) async {
    final cleanText = transcript.trim();
    if (cleanText.isEmpty) {
      throw Exception('Transcript is empty');
    }

    Map<String, dynamic> parsedData;
    try {
      final apiRes = await ApiService.instance.parseVoiceExpense(
        query: cleanText,
      );
      if (apiRes != null &&
          apiRes['success'] == true &&
          apiRes['data'] != null) {
        parsedData = apiRes['data'] as Map<String, dynamic>;
      } else {
        parsedData = parseLocally(cleanText);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Voice API call failed, falling back to local parser: $e');
      }
      parsedData = parseLocally(cleanText);
    }

    final String action = parsedData['action']?.toString() ?? 'create';

    // 1. Handle Deletion Intent
    if (action == 'delete') {
      int count = 1;
      if (parsedData['count'] != null) {
        if (parsedData['count'] is num) {
          count = (parsedData['count'] as num).toInt();
        } else {
          count = int.tryParse(parsedData['count'].toString()) ?? 1;
        }
      }
      if (count <= 0) count = 1;

      // Clean up any zero/negative amount transactions first
      await DbHelper.instance.deleteZeroOrNegativeTransactions();

      // Retrieve last N transactions from SQLite
      final lastTransactions = await DbHelper.instance.getLastTransactions(
        count,
      );

      int actuallyDeleted = 0;
      if (lastTransactions.isNotEmpty) {
        final syncedCount = lastTransactions.where((t) => t.synced).length;

        for (final t in lastTransactions) {
          if (t.id != null) {
            await DbHelper.instance.deleteTransaction(t.id!);
            actuallyDeleted++;
          }
        }

        // If any of the deleted transactions were already synced to Google Sheets, delete from Sheets too
        if (syncedCount > 0) {
          try {
            await ApiService.instance.deleteLastTransactions(
              count: syncedCount,
            );
          } catch (e) {
            if (kDebugMode) {
              print('Error calling deleteLastTransactions in API: $e');
            }
          }
        }
      } else {
        // If local DB had no transactions, attempt deleting from Google Sheets directly
        try {
          actuallyDeleted = await ApiService.instance.deleteLastTransactions(
            count: count,
          );
        } catch (_) {}
      }

      // Re-align with cloud and refresh widget
      unawaited(SyncService.instance.syncData());
      unawaited(WidgetDataService.updateWidgetData());

      final deleteMessage = actuallyDeleted > 0
          ? 'Deleted last $actuallyDeleted transaction${actuallyDeleted > 1 ? "s" : ""}'
          : 'No transactions found to delete';

      try {
        final prefs = await SharedPreferences.getInstance();
        final isVoiceNotifEnabled =
            prefs.getBool('key_voice_notifications_enabled') ?? true;

        if (isVoiceNotifEnabled) {
          await NotificationService.instance.showImmediateNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: 'Manikutti: Transaction Deleted',
            body: deleteMessage,
            channelId: 'voice_expense_channel_v2',
            channelName: 'Voice & Widget Expenses',
            channelDescription:
                'Instant confirmation alerts for expenses and income logged via voice or widget',
            icon: 'ic_tile_mic',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error posting voice notification: $e');
        }
      }

      return VoiceActionResult(
        action: 'delete',
        deletedCount: actuallyDeleted,
        message: deleteMessage,
        success: actuallyDeleted > 0,
      );
    }

    // 2. Handle Creation Intent
    final double amount = (parsedData['amount'] is num)
        ? (parsedData['amount'] as num).toDouble()
        : double.tryParse(parsedData['amount'].toString()) ?? 0.0;

    // Safety guard: NEVER save transactions with amount <= 0!
    if (amount <= 0.0) {
      const errorMsg =
          'Could not detect an amount. Please specify an amount (e.g., "100 roopa petrol").';
      return const VoiceActionResult(
        action: 'create',
        success: false,
        message: errorMsg,
      );
    }

    final String category = parsedData['category']?.toString() ?? 'Other';
    final String note = parsedData['note']?.toString() ?? cleanText;
    final String type = parsedData['type']?.toString() ?? 'Expense';
    final String bankAccount =
        parsedData['bankAccount']?.toString() ?? TransactionModel.bankSbi;

    // Normalizing timestamp to UTC as per architectural contract
    final utcTimestamp = DateTime.now().toUtc().toIso8601String();

    final tx = TransactionModel(
      date: utcTimestamp,
      amount: amount,
      category: category,
      note: note,
      isPaid: true,
      type: type,
      synced: false,
      bankAccount: bankAccount,
    );

    // Save directly to SQLite
    final insertedId = await DbHelper.instance.insertTransaction(tx);
    final savedTx = TransactionModel(
      id: insertedId,
      date: tx.date,
      amount: tx.amount,
      category: tx.category,
      note: tx.note,
      isPaid: tx.isPaid,
      type: tx.type,
      synced: false,
      bankAccount: tx.bankAccount,
    );

    // Update Home Screen Widget immediately
    unawaited(WidgetDataService.updateWidgetData());

    // Trigger background sync to Google Sheets
    unawaited(SyncService.instance.syncData());

    // Post immediate confirmation notification
    try {
      final prefs = await SharedPreferences.getInstance();
      final isVoiceNotifEnabled =
          prefs.getBool('key_voice_notifications_enabled') ?? true;

      if (isVoiceNotifEnabled) {
        final notifTitle = savedTx.type == 'Income'
            ? 'Manikutti: Income Recorded'
            : 'Manikutti: Expense Saved';
        final notifBody = savedTx.type == 'Income'
            ? 'Recorded +₹${savedTx.amount.toStringAsFixed(0)} for ${savedTx.note} (${savedTx.category})'
            : 'Saved ₹${savedTx.amount.toStringAsFixed(0)} for ${savedTx.note} (${savedTx.category})';

        await NotificationService.instance.showImmediateNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: notifTitle,
          body: notifBody,
          channelId: 'voice_expense_channel_v2',
          channelName: 'Voice & Widget Expenses',
          channelDescription:
              'Instant confirmation alerts for expenses and income logged via voice or widget',
          icon: 'ic_tile_mic',
        );
      } else {
        if (kDebugMode) {
          print(
            '[VoiceExpenseService] Voice notification skipped: disabled in preferences',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error posting voice notification: $e');
      }
    }

    return VoiceActionResult(
      action: 'create',
      transaction: savedTx,
      message:
          'Saved ₹${savedTx.amount.toStringAsFixed(0)} for ${savedTx.note}',
      success: true,
    );
  }
}
