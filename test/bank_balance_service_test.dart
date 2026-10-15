import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manikutti_flutter/models/transaction_model.dart';
import 'package:manikutti_flutter/services/bank_balance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BankBalanceService.instance.init();
    await BankBalanceService.instance.clearVerifiedBalance(
      TransactionModel.bankSbi,
    );
    await BankBalanceService.instance.clearVerifiedBalance(
      TransactionModel.bankCanara,
    );
  });

  group('BankBalanceService Tests', () {
    test('calculateBankBalance without baseline calculates all-time net', () {
      final transactions = [
        TransactionModel(
          date: '2026-10-01T10:00:00Z',
          amount: 50000.0,
          category: 'Salary',
          note: 'Salary credit',
          type: TransactionModel.typeIncome,
          bankAccount: TransactionModel.bankSbi,
        ),
        TransactionModel(
          date: '2026-10-05T12:00:00Z',
          amount: 12000.0,
          category: 'Rent',
          note: 'Apartment rent',
          type: TransactionModel.typeExpense,
          bankAccount: TransactionModel.bankSbi,
        ),
        TransactionModel(
          date: '2026-10-06T15:00:00Z',
          amount: 5000.0,
          category: 'Shopping',
          note: 'Canara expense',
          type: TransactionModel.typeExpense,
          bankAccount: TransactionModel.bankCanara,
        ),
      ];

      final sbiBalance = BankBalanceService.instance.calculateBankBalance(
        bank: TransactionModel.bankSbi,
        transactions: transactions,
      );
      final canaraBalance = BankBalanceService.instance.calculateBankBalance(
        bank: TransactionModel.bankCanara,
        transactions: transactions,
      );

      expect(sbiBalance, equals(38000.0));
      expect(canaraBalance, equals(-5000.0));
    });

    test(
      'calculateBankBalance with verified baseline only adjusts for subsequent transactions',
      () async {
        final baselineDate = DateTime.utc(2026, 10, 10, 23, 59, 59);
        final baselineBalance = 45000.0;

        final transactions = [
          // Transaction BEFORE baseline date (should be ignored as it is already included in baseline)
          TransactionModel(
            date: '2026-10-08T10:00:00Z',
            amount: 10000.0,
            category: 'Old Expense',
            note: 'Already in baseline',
            type: TransactionModel.typeExpense,
            bankAccount: TransactionModel.bankSbi,
          ),
          // Transaction AFTER baseline date (should adjust baseline)
          TransactionModel(
            date: '2026-10-12T10:00:00Z',
            amount: 2500.0,
            category: 'Dining',
            note: 'Weekend dinner',
            type: TransactionModel.typeExpense,
            bankAccount: TransactionModel.bankSbi,
          ),
          TransactionModel(
            date: '2026-10-14T10:00:00Z',
            amount: 5000.0,
            category: 'Freelance',
            note: 'Extra income',
            type: TransactionModel.typeIncome,
            bankAccount: TransactionModel.bankSbi,
          ),
        ];

        final balance = BankBalanceService.instance.calculateBankBalance(
          bank: TransactionModel.bankSbi,
          transactions: transactions,
          verifiedBalance: baselineBalance,
          verifiedDate: baselineDate,
        );

        // 45,000 baseline - 2,500 (expense after baseline) + 5,000 (income after baseline) = 47,500
        expect(balance, equals(47500.0));
      },
    );

    test(
      'Self-transfers adjust bank balance correctly and are recognized as isTransfer',
      () {
        final transferOut = TransactionModel(
          date: '2026-10-12T10:00:00Z',
          amount: 7000.0,
          category: 'Transfer',
          note: 'Transfer to SBI',
          type: TransactionModel.typeExpense,
          bankAccount: TransactionModel.bankCanara,
        );

        final transferIn = TransactionModel(
          date: '2026-10-12T10:00:00Z',
          amount: 7000.0,
          category: 'Transfer',
          note: 'Transfer from Canara Bank',
          type: TransactionModel.typeIncome,
          bankAccount: TransactionModel.bankSbi,
        );

        expect(transferOut.isTransfer, isTrue);
        expect(transferIn.isTransfer, isTrue);

        final sbiBalance = BankBalanceService.instance.calculateBankBalance(
          bank: TransactionModel.bankSbi,
          transactions: [transferIn],
        );

        final canaraBalance = BankBalanceService.instance.calculateBankBalance(
          bank: TransactionModel.bankCanara,
          transactions: [transferOut],
        );

        expect(sbiBalance, equals(7000.0));
        expect(canaraBalance, equals(-7000.0));
        // Net across both accounts is perfectly neutral (zero)
        expect(sbiBalance + canaraBalance, equals(0.0));
      },
    );

    test(
      'setVerifiedBalance and getVerifiedBalance persist properly',
      () async {
        final asOf = DateTime.utc(2026, 10, 15, 12, 0, 0);
        await BankBalanceService.instance.setVerifiedBalance(
          TransactionModel.bankSbi,
          18542.50,
          asOf,
        );

        final saved = await BankBalanceService.instance.getVerifiedBalance(
          TransactionModel.bankSbi,
        );
        final savedDate = await BankBalanceService.instance.getVerifiedDate(
          TransactionModel.bankSbi,
        );

        expect(saved, equals(18542.50));
        expect(savedDate, isNotNull);
        expect(
          BankBalanceService.instance.getCachedBalance(
            TransactionModel.bankSbi,
          ),
          equals(18542.50),
        );
      },
    );
  });
}
