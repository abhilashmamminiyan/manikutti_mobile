import 'package:flutter_test/flutter_test.dart';
import 'package:manikutti_flutter/models/home_loan_model.dart';

void main() {
  group('HomeLoanEntry Model Tests', () {
    test('fromJson correctly parses home loan entry', () {
      final json = {
        'id': 1,
        'date': '2026-05-10',
        'totalPayment': 25000.0,
        'principal': 15000.0,
        'interest': 10000.0,
        'balance': 2450000.0,
        'familyCode': 'FAM123',
        'addedBy': 'abhilash@example.com',
      };

      final entry = HomeLoanEntry.fromJson(json);

      expect(entry.id, 1);
      expect(entry.date, '2026-05-10');
      expect(entry.totalPayment, 25000.0);
      expect(entry.principal, 15000.0);
      expect(entry.interest, 10000.0);
      expect(entry.balance, 2450000.0);
      expect(entry.familyCode, 'FAM123');
      expect(entry.addedBy, 'abhilash@example.com');
    });

    test('toJson generates matching payload', () {
      final entry = HomeLoanEntry(
        id: 2,
        date: '2026-06-10',
        totalPayment: 25000.0,
        principal: 15200.0,
        interest: 9800.0,
        balance: 2434800.0,
        familyCode: 'FAM123',
        addedBy: 'abhilash@example.com',
      );

      final map = entry.toJson();

      expect(map['id'], 2);
      expect(map['date'], '2026-06-10');
      expect(map['principal'], 15200.0);
      expect(map['interest'], 9800.0);
      expect(map['balance'], 2434800.0);
    });

    test('copyWith updates specified fields correctly', () {
      final entry = HomeLoanEntry(
        id: 1,
        date: '2026-05-10',
        totalPayment: 25000.0,
        principal: 15000.0,
        interest: 10000.0,
        balance: 2450000.0,
      );

      final updated = entry.copyWith(balance: 2435000.0);

      expect(updated.id, 1);
      expect(updated.balance, 2435000.0);
      expect(updated.principal, 15000.0);
    });
  });
}
