import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class WidgetDataService {
  static const String appGroupId = 'group.com.abhilash.manikutti';
  static const String androidWidgetProvider = 'ManikuttiHomeWidgetProvider';

  /// Updates the home screen widget data (Month total + pending recharge/utility alert)
  static Future<void> updateWidgetData() async {
    try {
      final now = DateTime.now();
      final currentMonthStr = DateFormat('MMMM').format(now);
      final currentMonthYearKey = DateFormat('yyyy-MM').format(now);

      // 1. Calculate this month's total expense from SQLite
      final transactions = await DbHelper.instance.getAllTransactions();
      double monthTotal = 0;

      for (final tx in transactions) {
        if (tx.type.toLowerCase() == 'expense' ||
            tx.type.toLowerCase() == 'family') {
          final txDate = DateTime.tryParse(tx.date);
          if (txDate != null) {
            final txMonthKey = DateFormat('yyyy-MM').format(txDate.toLocal());
            if (txMonthKey == currentMonthYearKey) {
              monthTotal += tx.amount;
            }
          }
        }
      }

      final currencyFormatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );
      final formattedTotal = currencyFormatter.format(monthTotal);

      // 2. Determine nearest pending recharge or utility bill
      String pendingText = 'No pending bills';
      bool hasAlert = false;

      final recharges = await DbHelper.instance.getAllMobileRecharges();
      for (final r in recharges) {
        final valDate = DateTime.tryParse(r.validityTill);
        if (valDate != null) {
          final daysLeft = valDate.difference(now).inDays;
          if (daysLeft < 0) {
            pendingText = '🔴 ${r.name}: Expired ${-daysLeft}d ago';
            hasAlert = true;
            break;
          } else if (daysLeft <= 3) {
            pendingText =
                '⚡ ${r.name}: Expires in ${daysLeft == 0 ? "today" : "$daysLeft days"}';
            hasAlert = true;
            break;
          }
        }
      }

      // 3. Save data into HomeWidget storage
      await HomeWidget.saveWidgetData<String>('total_expense', formattedTotal);
      await HomeWidget.saveWidgetData<String>('pending_bill', pendingText);
      await HomeWidget.saveWidgetData<String>(
        'month_name',
        'Manikutti • $currentMonthStr',
      );
      await HomeWidget.saveWidgetData<bool>('has_alert', hasAlert);

      // 4. Request Widget Update
      await HomeWidget.updateWidget(androidName: androidWidgetProvider);
      if (kDebugMode) {
        print(
          'Widget updated successfully: Total=$formattedTotal, Alert=$pendingText',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating home screen widget: $e');
      }
    }
  }
}
