import 'dart:math' as math;
import '../models/home_loan_model.dart';

class HomeLoanRepaymentCalculation {
  final int daysElapsed;
  final double previousBalance;
  final String? previousDate;
  final double interest;
  final double principal;
  final double totalPayment;
  final double remainingBalance;

  const HomeLoanRepaymentCalculation({
    required this.daysElapsed,
    required this.previousBalance,
    required this.previousDate,
    required this.interest,
    required this.principal,
    required this.totalPayment,
    required this.remainingBalance,
  });
}

class HomeLoanCalculator {
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Estimates the annual interest rate (%) from chronological repayment history.
  static double estimateAnnualRate(List<HomeLoanEntry> sortedHistory) {
    if (sortedHistory.isEmpty) return 8.5;

    final last = sortedHistory.last;
    if (sortedHistory.length >= 2) {
      final prev = sortedHistory[sortedHistory.length - 2];
      final dLast = DateTime.tryParse(last.date);
      final dPrev = DateTime.tryParse(prev.date);
      if (dLast != null && dPrev != null && prev.balance > 0) {
        final daysBetween = _dateOnly(
          dLast,
        ).difference(_dateOnly(dPrev)).inDays;
        if (daysBetween > 0) {
          final annualized =
              (last.interest * 365.0) / (prev.balance * daysBetween) * 100.0;
          if (annualized > 0 && annualized <= 30) {
            return double.parse(annualized.toStringAsFixed(2));
          }
        }
      }
    }

    final inferredPrevBalance = last.balance + last.principal;
    if (inferredPrevBalance > 0) {
      final monthlyRate = last.interest / inferredPrevBalance;
      final annualRate = monthlyRate * 12.0 * 100.0;
      if (annualRate > 0 && annualRate <= 30) {
        return double.parse(annualRate.toStringAsFixed(2));
      }
    }

    return 8.5;
  }

  /// Calculates interest, principal, total payment, and balance for [selectedDate]
  /// using the daily reducing-balance formula against the nearest prior entry.
  static HomeLoanRepaymentCalculation calculateBreakdown({
    required List<HomeLoanEntry> sortedHistory,
    required DateTime selectedDate,
    required double annualRatePercent,
    required double plannedTotalPayment,
  }) {
    if (sortedHistory.isEmpty) {
      final safeTotal = math.max(0.0, plannedTotalPayment);
      return HomeLoanRepaymentCalculation(
        daysElapsed: 0,
        previousBalance: 0.0,
        previousDate: null,
        interest: 0.0,
        principal: safeTotal,
        totalPayment: safeTotal,
        remainingBalance: 0.0,
      );
    }

    final targetDate = _dateOnly(selectedDate);
    HomeLoanEntry? baseEntry;
    for (final item in sortedHistory) {
      final parsed = DateTime.tryParse(item.date);
      if (parsed != null && _dateOnly(parsed).isBefore(targetDate)) {
        baseEntry = item;
      }
    }
    baseEntry ??= sortedHistory.last;

    final prevBal = baseEntry.balance;
    final baseDateParsed = DateTime.tryParse(baseEntry.date);
    final days = baseDateParsed != null
        ? targetDate.difference(_dateOnly(baseDateParsed)).inDays
        : 0;

    final calculatedInterest =
        (days > 0 && prevBal > 0 && annualRatePercent > 0)
        ? (prevBal * (annualRatePercent / 100.0) * (days / 365.0))
              .roundToDouble()
        : 0.0;

    final targetTotal = plannedTotalPayment > 0
        ? plannedTotalPayment
        : (baseEntry.totalPayment > 0 ? baseEntry.totalPayment : 12000.0);

    final calculatedPrincipal = math
        .max(0.0, math.min(prevBal, targetTotal - calculatedInterest))
        .roundToDouble();

    final adjustedTotal = calculatedPrincipal + calculatedInterest;
    final remaining = math
        .max(0.0, prevBal - calculatedPrincipal)
        .roundToDouble();

    return HomeLoanRepaymentCalculation(
      daysElapsed: days,
      previousBalance: prevBal,
      previousDate: baseEntry.date,
      interest: calculatedInterest,
      principal: calculatedPrincipal,
      totalPayment: adjustedTotal,
      remainingBalance: remaining,
    );
  }
}
