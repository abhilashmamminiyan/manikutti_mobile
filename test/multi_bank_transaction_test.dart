import 'package:flutter_test/flutter_test.dart';
import 'package:manikutti_flutter/models/transaction_model.dart';

void main() {
  group('Multi-Bank Account TransactionModel Tests', () {
    test(
      'TransactionModel defaults to SBI when bankAccount is not provided',
      () {
        final tx = TransactionModel(
          date: '2026-10-15T10:00:00.000Z',
          amount: 500.0,
          category: 'Food',
          note: 'Lunch at Cafe',
          type: 'Expense',
        );

        expect(tx.bankAccount, equals(TransactionModel.bankSbi));
        expect(tx.bankAccount, equals('SBI'));
      },
    );

    test('TransactionModel stores Canara Bank properly', () {
      final tx = TransactionModel(
        date: '2026-10-15T11:00:00.000Z',
        amount: 1500.0,
        category: 'Shopping',
        note: 'Groceries',
        type: 'Expense',
        bankAccount: TransactionModel.bankCanara,
      );

      expect(tx.bankAccount, equals('Canara Bank'));
      expect(tx.bankAccount, equals(TransactionModel.bankCanara));
    });

    test('toMap and fromMap preserve bankAccount correctly', () {
      final original = TransactionModel(
        id: 42,
        date: '2026-10-15T12:00:00.000Z',
        amount: 2500.0,
        category: 'Salary',
        note: 'Client Payment',
        type: 'Income',
        bankAccount: TransactionModel.bankCanara,
      );

      final map = original.toMap();
      expect(map['bankAccount'], equals('Canara Bank'));

      final restored = TransactionModel.fromMap(map);
      expect(restored.id, equals(42));
      expect(restored.amount, equals(2500.0));
      expect(restored.bankAccount, equals(TransactionModel.bankCanara));
    });

    test(
      'fromMap falls back to SBI if bankAccount column is null or omitted',
      () {
        final legacyMap = {
          'id': 10,
          'date': '2026-10-01T00:00:00.000Z',
          'amount': 300.0,
          'category': 'Transport',
          'note': 'Metro card',
          'isPaid': 1,
          'type': 'Expense',
          'addedBy': 'user@example.com',
          'synced': 1,
          // no 'bankAccount' key
        };

        final restored = TransactionModel.fromMap(legacyMap);
        expect(restored.bankAccount, equals('SBI'));
      },
    );

    test('copyWith properly updates bankAccount', () {
      final sbiTx = TransactionModel(
        date: '2026-10-15T10:00:00.000Z',
        amount: 100.0,
        category: 'Tea',
        note: 'Chai',
        type: 'Expense',
        bankAccount: TransactionModel.bankSbi,
      );

      final canaraTx = sbiTx.copyWith(bankAccount: TransactionModel.bankCanara);
      expect(canaraTx.bankAccount, equals('Canara Bank'));
      expect(canaraTx.amount, equals(100.0));
      expect(canaraTx.note, equals('Chai'));
    });

    test('Supported banks list contains SBI and Canara Bank', () {
      expect(TransactionModel.supportedBanks, contains('SBI'));
      expect(TransactionModel.supportedBanks, contains('Canara Bank'));
      expect(TransactionModel.supportedBanks.length, equals(2));
    });
  });
}
