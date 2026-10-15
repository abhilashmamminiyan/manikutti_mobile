import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/emi_model.dart';
import '../models/loan_model.dart';
import '../models/home_loan_model.dart';
import '../theme/app_theme.dart';
import '../screens/home_loan_screen.dart';
import '../screens/loans_emi_screen.dart';

class FamilyLoanEmiSection extends StatelessWidget {
  final List<EmiBill> emiBills;
  final List<Loan> loans;
  final List<HomeLoanEntry> homeLoanHistory;
  final Function(EmiBill emi)? onPayEmi;
  final VoidCallback? onRefresh;

  const FamilyLoanEmiSection({
    super.key,
    required this.emiBills,
    required this.loans,
    required this.homeLoanHistory,
    this.onPayEmi,
    this.onRefresh,
  });

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  double get _homeLoanLatestBalance {
    if (homeLoanHistory.isEmpty) return 0.0;
    return homeLoanHistory.last.balance;
  }

  double get _homeLoanTotalPaidPrincipal {
    return homeLoanHistory.fold(0.0, (sum, item) => sum + item.principal);
  }

  double get _homeLoanTotalPaidInterest {
    return homeLoanHistory.fold(0.0, (sum, item) => sum + item.interest);
  }

  double get _homeLoanInitialPrincipal {
    if (homeLoanHistory.isEmpty) return 0.0;
    return homeLoanHistory.first.balance + homeLoanHistory.first.principal;
  }

  double get _homeLoanMonthlyEmi {
    if (homeLoanHistory.isEmpty) return 12000.0;
    return homeLoanHistory.last.totalPayment > 0
        ? homeLoanHistory.last.totalPayment
        : 12000.0;
  }

  double get _totalMonthlyEmiOutflow {
    double total = 0.0;
    for (final emi in emiBills.where((e) => !e.isCompleted)) {
      total += emi.monthlyPayment;
    }
    if (homeLoanHistory.isNotEmpty) {
      total += _homeLoanMonthlyEmi;
    }
    for (final loan in loans.where((l) => l.status.toLowerCase() == 'active')) {
      // If loan not already in emiBills
      final existsInEmi = emiBills.any(
        (e) => e.title.toLowerCase().trim() == loan.name.toLowerCase().trim(),
      );
      if (!existsInEmi) {
        total += loan.monthlyEMI;
      }
    }
    return total;
  }

  double get _totalOutstandingBalance {
    double total = _homeLoanLatestBalance;
    for (final emi in emiBills.where((e) => !e.isCompleted)) {
      final remainingMonths = (emi.tenure - emi.paidMonths).clamp(0, 9999);
      total += remainingMonths * emi.monthlyPayment;
    }
    for (final loan in loans.where((l) => l.status.toLowerCase() == 'active')) {
      final existsInEmi = emiBills.any(
        (e) => e.title.toLowerCase().trim() == loan.name.toLowerCase().trim(),
      );
      if (!existsInEmi) {
        total += loan.amount;
      }
    }
    return total;
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainer
            : AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkOnSurfaceVariant
                        : AppTheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeLoanCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initial = _homeLoanInitialPrincipal;
    final balance = _homeLoanLatestBalance;
    final paidPrincipal = _homeLoanTotalPaidPrincipal;
    final paidInterest = _homeLoanTotalPaidInterest;
    final progress = initial > 0
        ? (paidPrincipal / initial).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Home Loan (SBI)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MORTGAGE • ACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(_homeLoanMonthlyEmi),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    'Monthly EMI',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.outline,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar: Principal Repayment Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Principal Repaid: ${(progress * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkOnSurface : AppTheme.onSurface,
                ),
              ),
              Text(
                'Balance: ${_currencyFormat.format(balance)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? const Color(0xFF2C3233)
                  : AppTheme.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4-Metric Financial Breakdown Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Principal Paid',
                  value: _currencyFormat.format(paidPrincipal),
                  color: const Color(0xFF10B981),
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Interest Paid',
                  value: _currencyFormat.format(paidInterest),
                  color: const Color(0xFFF59E0B),
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Initial Loan',
                  value: _currencyFormat.format(initial),
                  color: isDark ? AppTheme.darkOnSurface : AppTheme.onSurface,
                  icon: Icons.account_balance_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Balance to Pay',
                  value: _currencyFormat.format(balance),
                  color: AppTheme.error,
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tap to see full amortization schedule
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HomeLoanScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Amortization Schedule & Prepayments',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmiCard(BuildContext context, EmiBill emi) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final progress = emi.progressPercentage;
    final isCompleted = emi.isCompleted;
    final paidPrincipalEstimate = emi.paidMonths * emi.monthlyPayment;
    final balanceToPay = ((emi.tenure - emi.paidMonths) * emi.monthlyPayment)
        .clamp(0.0, double.infinity);
    final totalLoanVal = emi.amount > 0
        ? emi.amount
        : (emi.monthlyPayment * emi.tenure);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Title and Monthly EMI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 20,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emi.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  emi.owner == 'Family'
                                      ? 'FAMILY EMI'
                                      : 'PERSONAL EMI',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF59E0B),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              if (emi.dueDate.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'Due: ${emi.dueDate}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isDark
                                        ? AppTheme.darkOnSurfaceVariant
                                        : AppTheme.outline,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(emi.monthlyPayment),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    'Monthly',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.outline,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: EMI Count Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Installment: ${emi.paidMonths} / ${emi.tenure} Months',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isCompleted
                      ? const Color(0xFF10B981)
                      : (isDark ? AppTheme.darkOnSurface : AppTheme.onSurface),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}% Done',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isCompleted
                      ? const Color(0xFF10B981)
                      : AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: isDark
                  ? const Color(0xFF2C3233)
                  : AppTheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted
                    ? const Color(0xFF10B981)
                    : (progress > 0.7
                          ? const Color(0xFF10B981)
                          : AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Row 3: Financial Details Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Principal Paid',
                  value: _currencyFormat.format(paidPrincipalEstimate),
                  color: const Color(0xFF10B981),
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Total Loan',
                  value: _currencyFormat.format(totalLoanVal),
                  color: isDark ? AppTheme.darkOnSurface : AppTheme.onSurface,
                  icon: Icons.account_balance_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Balance to Pay',
                  value: _currencyFormat.format(balanceToPay),
                  color: AppTheme.error,
                  icon: Icons.hourglass_bottom_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action row
          if (!isCompleted && onPayEmi != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => onPayEmi!(emi),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: Text(
                  'Mark Installment #${emi.paidMonths + 1} Paid',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasHomeLoan = homeLoanHistory.isNotEmpty;
    final hasEmis = emiBills.isNotEmpty;

    if (!hasHomeLoan && !hasEmis) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family Loans & EMI Ledger',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Monthly: ${_currencyFormat.format(_totalMonthlyEmiOutflow)} • Liability: ${_currencyFormat.format(_totalOutstandingBalance)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkOnSurfaceVariant
                        : AppTheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoansEmiScreen()),
                );
              },
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: AppTheme.primary,
              ),
              label: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Home Loan Card (if available)
        if (hasHomeLoan) _buildHomeLoanCard(context),

        // 2. Active General EMIs
        ...emiBills
            .where((e) => !e.isCompleted)
            .map((emi) => _buildEmiCard(context, emi)),
      ],
    );
  }
}
