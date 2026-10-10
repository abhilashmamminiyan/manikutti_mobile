import 'package:flutter_test/flutter_test.dart';
import 'package:manikutti_flutter/models/emi_model.dart';
import 'package:manikutti_flutter/models/loan_model.dart';

void main() {
  group('EmiBill Model Tests', () {
    test('fromJson correctly parses fields and calculates progress', () {
      final json = {
        'id': 1,
        'title': 'Car Loan EMI',
        'amount': 500000.0,
        'dueDate': '2026-11-05',
        'status': 'Unpaid',
        'familyCode': 'FAM123',
        'adminEmail': 'test@example.com',
        'tenure': 24,
        'monthlyPayment': 25000.0,
        'startDate': '2024-11-05',
        'paidMonths': 6,
        'type': 'EMI',
        'owner': 'Family',
      };

      final emi = EmiBill.fromJson(json);

      expect(emi.id, 1);
      expect(emi.title, 'Car Loan EMI');
      expect(emi.amount, 500000.0);
      expect(emi.monthlyPayment, 25000.0);
      expect(emi.tenure, 24);
      expect(emi.paidMonths, 6);
      expect(emi.progressPercentage, 0.25);
      expect(emi.isCompleted, false);
    });

    test(
      'isCompleted returns true when paidMonths equals or exceeds tenure',
      () {
        final emi = EmiBill(
          id: 2,
          title: 'Appliance EMI',
          amount: 30000,
          dueDate: '2026-10-01',
          familyCode: 'FAM123',
          tenure: 12,
          monthlyPayment: 2500,
          startDate: '2025-10-01',
          paidMonths: 12,
        );

        expect(emi.isCompleted, true);
        expect(emi.progressPercentage, 1.0);
      },
    );
  });

  group('Loan Model Tests', () {
    test('Loan, LoanExpense, and LoanRepayment parse json properly', () {
      final loanJson = {
        'id': 1,
        'name': 'Home Renovation',
        'amount': 200000.0,
        'monthlyEMI': 10000.0,
        'assignedTo': 'Abhilash',
        'familyCode': 'FAM123',
        'status': 'Active',
      };

      final loan = Loan.fromJson(loanJson);
      expect(loan.name, 'Home Renovation');
      expect(loan.amount, 200000.0);
      expect(loan.assignedTo, 'Abhilash');

      final expenseJson = {
        'date': '2026-10-01',
        'amount': 5000.0,
        'category': 'Materials',
        'note': 'Cement and paint',
        'loanName': 'Home Renovation',
        'addedBy': 'Abhilash',
        'familyCode': 'FAM123',
      };
      final expense = LoanExpense.fromJson(expenseJson);
      expect(expense.amount, 5000.0);
      expect(expense.loanName, 'Home Renovation');

      final repaymentJson = {
        'date': '2026-10-05',
        'amount': 10000.0,
        'loanName': 'Home Renovation',
        'paidBy': 'Abhilash',
        'familyCode': 'FAM123',
      };
      final repayment = LoanRepayment.fromJson(repaymentJson);
      expect(repayment.amount, 10000.0);
      expect(repayment.loanName, 'Home Renovation');
    });
  });
}
