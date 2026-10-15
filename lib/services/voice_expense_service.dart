import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'sync_service.dart';
import 'widget_data_service.dart';

class VoiceExpenseService {
  static final VoiceExpenseService instance = VoiceExpenseService._init();

  VoiceExpenseService._init();

  /// Intelligent client-side rule-based fallback parser for Manglish, Malayalam & English
  /// Guaranteed to work 100% offline without any internet connection.
  Map<String, dynamic> parseLocally(String text, {String defaultBank = 'SBI'}) {
    final lower = text.toLowerCase().trim();

    // 1. Amount Extraction
    double amount = 0;
    final numMatch = RegExp(
      r'(?:₹|rs\.?|inr|roopa|rupa|roopakku|rupakku|രൂപ)?\s*(\d+(?:\.\d+)?)\s*(?:₹|rs\.?|inr|roopa|rupa|roopakku|rupakku|രൂപ)?',
      caseSensitive: false,
    ).firstMatch(lower);

    if (numMatch != null && numMatch.group(1) != null) {
      amount = double.tryParse(numMatch.group(1)!) ?? 0;
    }

    // 2. Type Detection
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
        lower.contains('വരുമാനം')) {
      type = 'Income';
    }

    // 3. Category & Note Detection
    String category = 'Other';
    String note = text;

    if (lower.contains('petrol') ||
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
      'amount': amount,
      'category': category,
      'note': note,
      'type': type,
      'bankAccount': bankAccount,
    };
  }

  /// Parses voice input via Gemini AI API (or local fallback) and commits it to SQLite
  Future<TransactionModel> processAndSaveVoiceExpense(String transcript) async {
    final cleanText = transcript.trim();
    if (cleanText.isEmpty) {
      throw Exception('Transcript is empty');
    }

    Map<String, dynamic> parsedData;
    try {
      final apiRes = await ApiService.instance.parseVoiceExpense(query: cleanText);
      if (apiRes != null && apiRes['success'] == true && apiRes['data'] != null) {
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

    final double amount = (parsedData['amount'] is num)
        ? (parsedData['amount'] as num).toDouble()
        : double.tryParse(parsedData['amount'].toString()) ?? 0.0;

    final String category = parsedData['category']?.toString() ?? 'Other';
    final String note = parsedData['note']?.toString() ?? cleanText;
    final String type = parsedData['type']?.toString() ?? 'Expense';
    final String bankAccount = parsedData['bankAccount']?.toString() ?? TransactionModel.bankSbi;

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
      unawaited(
        NotificationService.instance.showImmediateNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Manikutti: Record Saved',
          body: 'Saved ₹${savedTx.amount.toStringAsFixed(0)} for ${savedTx.note} (${savedTx.category})',
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error posting voice notification: $e');
      }
    }

    return savedTx;
  }
}
