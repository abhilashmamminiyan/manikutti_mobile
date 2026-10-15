import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manikutti_flutter/models/transaction_model.dart';
import 'package:manikutti_flutter/models/emi_model.dart';
import 'package:manikutti_flutter/models/home_loan_model.dart';
import 'package:manikutti_flutter/widgets/expense_pie_chart.dart';
import 'package:manikutti_flutter/widgets/family_loan_emi_card.dart';
import 'package:manikutti_flutter/widgets/monthly_dues_section.dart';
import 'package:manikutti_flutter/widgets/dashboard_budget_progress.dart';

void main() {
  group('Dashboard Budget Progress Tests', () {
    testWidgets('renders monthly budget progress, spend, and burn rate', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardBudgetProgressBar(
              totalPersonalExpenses: 20000,
              totalPersonalIncome: 50000,
              baseSalary: 60000,
            ),
          ),
        ),
      );

      expect(find.text('Monthly Budget & Pace'), findsOneWidget);
      expect(find.text('₹20,000'), findsOneWidget);
      expect(find.text('of ₹60,000'), findsOneWidget);
      expect(find.text('₹40,000 left'), findsOneWidget);
      expect(find.text('33% Used'), findsOneWidget);
    });
  });

  group('Expense Pie Chart Tests', () {
    testWidgets('renders empty state when no transactions exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExpensePieChart(transactions: [])),
        ),
      );

      expect(find.text('Spending Breakdown'), findsOneWidget);
      expect(
        find.text('No expense records found for this month'),
        findsOneWidget,
      );
    });

    testWidgets('renders category breakdown and center total for expenses', (
      tester,
    ) async {
      final now = DateTime.now().toIso8601String();
      final transactions = [
        TransactionModel(
          date: now,
          amount: 2500,
          category: 'Food',
          note: 'Groceries',
          type: 'Personal',
        ),
        TransactionModel(
          date: now,
          amount: 1500,
          category: 'Shopping',
          note: 'Clothes',
          type: 'Personal',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExpensePieChart(transactions: transactions)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spending Breakdown'), findsOneWidget);
      expect(find.text('Total Spent'), findsOneWidget);
      expect(find.text('₹4,000'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('63%'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
    });
  });

  group('Monthly Dues Section Tests', () {
    testWidgets('renders monthly dues rows matching screenshot', (
      tester,
    ) async {
      final items = [
        {
          'id': 1,
          'title': 'Home loan',
          'amount': 12000,
          'dueDay': 5,
          'lastPaidDate': '',
        },
        {
          'id': 2,
          'title': 'Bajaj Personal Loan',
          'amount': 7755,
          'dueDay': 2,
          'lastPaidDate': '',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthlyDuesSection(
              monthlyExpenses: items,
              userEmail: 'test@example.com',
              onMarkPaid: (_) {},
              onAddMonthlyDues: () {},
            ),
          ),
        ),
      );

      expect(find.text('Monthly Utilities & Dues'), findsOneWidget);
      expect(find.text('Add Monthly Dues'), findsOneWidget);
      expect(find.text('Home loan'), findsOneWidget);
      expect(find.text('Day 5'), findsOneWidget);
      expect(find.text('₹12,000'), findsOneWidget);
      expect(find.text('Bajaj Personal Loan'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.text('₹7,755'), findsOneWidget);
      expect(find.text('Unpaid'), findsNWidgets(2));
    });
  });

  group('Family Loan EMI Section Tests', () {
    testWidgets(
      'renders home loan and active EMI cards with progress and balance',
      (tester) async {
        final List<EmiBill> emiBills = [
          EmiBill(
            id: 1,
            title: 'Bajaj Personal Loan',
            amount: 279180,
            monthlyPayment: 7755,
            tenure: 36,
            paidMonths: 14,
            startDate: '2024-01-01',
            dueDate: '2026-11-02',
            familyCode: 'FAM123',
          ),
        ];

        final homeLoanHistory = [
          HomeLoanEntry(
            date: '2026-10-05',
            totalPayment: 12000,
            principal: 7500,
            interest: 4500,
            balance: 850000,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FamilyLoanEmiSection(
                  emiBills: emiBills,
                  loans: const [],
                  homeLoanHistory: homeLoanHistory,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Family Loans & EMI Ledger'), findsOneWidget);
        expect(find.text('Home Loan (SBI)'), findsOneWidget);
        expect(find.text('MORTGAGE • ACTIVE'), findsOneWidget);
        expect(find.text('Bajaj Personal Loan'), findsOneWidget);
        expect(find.text('Installment: 14 / 36 Months'), findsOneWidget);
        expect(find.text('38% Done'), findsOneWidget);
        expect(find.text('Balance to Pay'), findsNWidgets(2));
      },
    );
  });
}
