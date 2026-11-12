import 'package:flutter_test/flutter_test.dart';
import 'package:manikutti_flutter/models/home_loan_model.dart';
import 'package:manikutti_flutter/utils/home_loan_calculator.dart';

void main() {
  group('HomeLoanCalculator', () {
    final sampleHistory = [
      HomeLoanEntry(
        id: 1,
        date: '2026-08-05',
        totalPayment: 12000,
        principal: 5000,
        interest: 7000,
        balance: 995000,
      ),
      HomeLoanEntry(
        id: 2,
        date: '2026-09-05',
        totalPayment: 12000,
        principal: 4824,
        interest: 7176,
        balance: 990176,
      ),
    ];

    test(
      'estimates annual rate from chronological entries using day difference',
      () {
        final rate = HomeLoanCalculator.estimateAnnualRate(sampleHistory);
        // 7176 interest over 31 days on 995000 => ~8.49%
        expect(rate, closeTo(8.49, 0.05));
      },
    );

    test('recalculates interest and principal when date changes', () {
      final calc30Days = HomeLoanCalculator.calculateBreakdown(
        sortedHistory: sampleHistory,
        selectedDate: DateTime(2026, 10, 5),
        annualRatePercent: 8.5,
        plannedTotalPayment: 12000,
      );
      expect(calc30Days.daysElapsed, 30);
      expect(calc30Days.interest, 6918);
      expect(calc30Days.principal, 5082);
      expect(calc30Days.remainingBalance, 985094);

      final calc45Days = HomeLoanCalculator.calculateBreakdown(
        sortedHistory: sampleHistory,
        selectedDate: DateTime(2026, 10, 20),
        annualRatePercent: 8.5,
        plannedTotalPayment: 12000,
      );
      expect(calc45Days.daysElapsed, 45);
      expect(calc45Days.interest, greaterThan(calc30Days.interest));
      expect(calc45Days.principal, lessThan(calc30Days.principal));
    });

    test('recalculates interest and principal when annual rate changes', () {
      final lowRate = HomeLoanCalculator.calculateBreakdown(
        sortedHistory: sampleHistory,
        selectedDate: DateTime(2026, 10, 5),
        annualRatePercent: 8.0,
        plannedTotalPayment: 12000,
      );
      final highRate = HomeLoanCalculator.calculateBreakdown(
        sortedHistory: sampleHistory,
        selectedDate: DateTime(2026, 10, 5),
        annualRatePercent: 10.0,
        plannedTotalPayment: 12000,
      );
      expect(highRate.interest, greaterThan(lowRate.interest));
      expect(highRate.principal, lessThan(lowRate.principal));
      expect(highRate.totalPayment, 12000);
    });
  });
}
