import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/home_loan_model.dart';
import '../models/loan_model.dart';
import 'api_service.dart';
import 'notification_service.dart';

class MandatoryEmiCheckItem {
  final String loanKey;
  final String title;
  final double emiAmount;
  final String payerName;
  final String shareRecipient;
  final int dueDay;
  final bool paidToPayer;
  final bool sharedWithRecipient;
  final bool autoSmsDetected;
  final bool isResponsibleUser;

  MandatoryEmiCheckItem({
    required this.loanKey,
    required this.title,
    required this.emiAmount,
    required this.payerName,
    required this.shareRecipient,
    required this.dueDay,
    required this.paidToPayer,
    required this.sharedWithRecipient,
    required this.autoSmsDetected,
    required this.isResponsibleUser,
  });

  bool get isComplete => paidToPayer && sharedWithRecipient;
}

class EmiReminderService {
  static final EmiReminderService instance = EmiReminderService._internal();
  EmiReminderService._internal();

  static const int _notifBaseId = 9101;

  String currentMonthKey([DateTime? now]) {
    return DateFormat('yyyy-MM').format(now ?? DateTime.now());
  }

  /// Evaluates mandatory before-10th monthly EMI & Share checks, auto-absorbs
  /// any EMI SMS confirmation from native Android, and updates local reminders.
  Future<List<MandatoryEmiCheckItem>> evaluateMonthlyChecks({
    required String familyCode,
    required String userEmail,
    required List<Loan> loans,
    HomeLoanConfig? homeLoanConfig,
    required List<EmiMonthlyTracking> trackingList,
  }) async {
    final monthKey = currentMonthKey();
    final prefs = await SharedPreferences.getInstance();

    // Sync any native SMS EMI confirmation that occurred while app was closed
    final pendingSyncMonth = prefs.getString('pending_emi_sms_sync_month');
    final localSmsConfirmed = prefs.getBool('emi_sms_confirmed_$monthKey') ?? false;
    final smsSyncAmount = double.tryParse(prefs.getString('pending_emi_sms_sync_amount') ?? '') ?? 0.0;
    final smsSyncNote = prefs.getString('pending_emi_sms_sync_note') ?? 'Confirmed via EMI SMS';

    final items = <MandatoryEmiCheckItem>[];

    // 1. Home Loan config (if configured)
    if (homeLoanConfig != null && homeLoanConfig.monthlyEMI > 0) {
      const key = 'Home Loan';
      final tracked = _findTracking(trackingList, key);
      final paidLocal = prefs.getBool('emi_paid_${monthKey}_$key') ?? false;
      final sharedLocal = prefs.getBool('emi_shared_${monthKey}_$key') ?? false;

      bool paid = (tracked?.paidToPayer ?? false) || paidLocal;
      if (!paid && (localSmsConfirmed || pendingSyncMonth == monthKey) && (smsSyncAmount == 0 || (smsSyncAmount - homeLoanConfig.monthlyEMI).abs() <= 5)) {
        paid = true;
        await _pushAutoSmsTracking(familyCode, monthKey, key, homeLoanConfig.monthlyEMI, smsSyncNote);
      }

      items.add(
        MandatoryEmiCheckItem(
          loanKey: key,
          title: 'Home Loan EMI',
          emiAmount: homeLoanConfig.monthlyEMI,
          payerName: homeLoanConfig.payerName,
          shareRecipient: homeLoanConfig.shareRecipient,
          dueDay: homeLoanConfig.dueDay,
          paidToPayer: paid,
          sharedWithRecipient: (tracked?.sharedWithRecipient ?? false) || sharedLocal,
          autoSmsDetected: tracked?.autoSmsDetected ?? localSmsConfirmed,
          isResponsibleUser: true,
        ),
      );
    }

    // 2. Active Loans from Loans tab
    for (final loan in loans.where((l) => l.status.toLowerCase() == 'active' && l.monthlyEMI > 0)) {
      final key = loan.name.trim();
      final tracked = _findTracking(trackingList, key);
      final paidLocal = prefs.getBool('emi_paid_${monthKey}_$key') ?? false;
      final sharedLocal = prefs.getBool('emi_shared_${monthKey}_$key') ?? false;

      bool paid = (tracked?.paidToPayer ?? false) || paidLocal;
      if (!paid && (localSmsConfirmed || pendingSyncMonth == monthKey) && (smsSyncAmount == 0 || (smsSyncAmount - loan.monthlyEMI).abs() <= 5)) {
        paid = true;
        await _pushAutoSmsTracking(familyCode, monthKey, key, loan.monthlyEMI, smsSyncNote);
      }

      final assignedLower = loan.assignedTo.trim().toLowerCase();
      final emailLower = userEmail.trim().toLowerCase();
      final isResponsible = assignedLower.isEmpty ||
          assignedLower == 'family' ||
          assignedLower == emailLower ||
          emailLower.contains(loan.payerName.toLowerCase()) ||
          emailLower.contains(loan.shareRecipient.toLowerCase());

      items.add(
        MandatoryEmiCheckItem(
          loanKey: key,
          title: loan.name,
          emiAmount: loan.monthlyEMI,
          payerName: loan.payerName,
          shareRecipient: loan.shareRecipient,
          dueDay: 10,
          paidToPayer: paid,
          sharedWithRecipient: (tracked?.sharedWithRecipient ?? false) || sharedLocal,
          autoSmsDetected: tracked?.autoSmsDetected ?? localSmsConfirmed,
          isResponsibleUser: isResponsible,
        ),
      );
    }

    if (pendingSyncMonth == monthKey) {
      await prefs.remove('pending_emi_sms_sync_month');
      await prefs.remove('pending_emi_sms_sync_amount');
      await prefs.remove('pending_emi_sms_sync_note');
    }

    await _syncMonthlyNotifications(items);
    return items;
  }

  Future<bool> confirmStatus({
    required String familyCode,
    required MandatoryEmiCheckItem item,
    bool? paidToPayer,
    bool? sharedWithRecipient,
  }) async {
    final monthKey = currentMonthKey();
    final prefs = await SharedPreferences.getInstance();
    if (paidToPayer == true) {
      await prefs.setBool('emi_paid_${monthKey}_${item.loanKey}', true);
    }
    if (sharedWithRecipient == true) {
      await prefs.setBool('emi_shared_${monthKey}_${item.loanKey}', true);
    }

    final ok = await ApiService.instance.confirmEmiMonthlyTracking(
      familyCode: familyCode,
      monthKey: monthKey,
      loanKey: item.loanKey,
      paidToPayer: paidToPayer,
      sharedWithRecipient: sharedWithRecipient,
      logAmount: paidToPayer == true ? item.emiAmount : null,
      note: 'Confirmed in mobile app ($monthKey)',
    );
    return ok;
  }

  Future<void> _pushAutoSmsTracking(
    String familyCode,
    String monthKey,
    String loanKey,
    double amount,
    String note,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('emi_paid_${monthKey}_$loanKey', true);
      await ApiService.instance.confirmEmiMonthlyTracking(
        familyCode: familyCode,
        monthKey: monthKey,
        loanKey: loanKey,
        paidToPayer: true,
        autoSmsDetected: true,
        logAmount: amount,
        note: note,
      );
    } catch (e) {
      debugPrint('[EmiReminderService] _pushAutoSmsTracking error: $e');
    }
  }

  EmiMonthlyTracking? _findTracking(List<EmiMonthlyTracking> list, String loanKey) {
    final target = loanKey.trim().toLowerCase();
    for (final item in list) {
      if (item.loanKey.trim().toLowerCase() == target) return item;
    }
    return null;
  }

  Future<void> _syncMonthlyNotifications(List<MandatoryEmiCheckItem> items) async {
    final now = DateTime.now();
    final pending = items.where((i) => i.isResponsibleUser && !i.isComplete).toList();
    if (pending.isEmpty) {
      for (int i = 0; i < 4; i++) {
        await NotificationService.instance.cancelNotification(_notifBaseId + i);
      }
      return;
    }

    // Schedule reminder notifications on days 2, 5, 8, 9 before the 10th if unpaid
    final first = pending.first;
    final questions = <String>[];
    if (!first.paidToPayer) {
      questions.add('Have you paid the EMI to ${first.payerName}?');
    }
    if (!first.sharedWithRecipient) {
      questions.add('Have you shared the amount to ${first.shareRecipient}?');
    }
    final message = '${first.title}: ${questions.join(' ')}';

    final reminderDays = [2, 5, 8, 9];
    for (int i = 0; i < reminderDays.length; i++) {
      final day = reminderDays[i];
      if (now.day <= day) {
        await NotificationService.instance.scheduleMonthlyReminder(
          id: _notifBaseId + i,
          title: 'Mandatory EMI Check (Before 10th)',
          body: message,
          dueDay: day,
          channelId: 'emi_mandatory_channel',
          channelName: 'Monthly EMI & Share Check',
          payload: 'emi_mandatory_check',
        );
      }
    }
  }
}
