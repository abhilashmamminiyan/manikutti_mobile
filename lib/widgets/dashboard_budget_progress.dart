import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class DashboardBudgetProgressBar extends StatelessWidget {
  final double totalPersonalExpenses;
  final double totalPersonalIncome;
  final double baseSalary;
  final VoidCallback? onAdjustBudget;

  const DashboardBudgetProgressBar({
    super.key,
    required this.totalPersonalExpenses,
    required this.totalPersonalIncome,
    required this.baseSalary,
    this.onAdjustBudget,
  });

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day;
    final daysRemaining = (daysInMonth - daysPassed).clamp(0, 31);

    // Effective budget reference is salary if configured, or total income, or fallback
    final effectiveBudget = baseSalary > 0
        ? baseSalary
        : (totalPersonalIncome > 0 ? totalPersonalIncome : 50000.0);

    final progress = effectiveBudget > 0
        ? (totalPersonalExpenses / effectiveBudget).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (progress * 100).toInt();

    final remainingBudget = (effectiveBudget - totalPersonalExpenses).clamp(
      0.0,
      double.infinity,
    );
    final dailyAverageSpend = daysPassed > 0
        ? (totalPersonalExpenses / daysPassed)
        : 0.0;

    Color progressColor;
    String statusMessage;
    IconData statusIcon;

    if (percentage < 60) {
      progressColor = const Color(0xFF10B981); // Emerald
      statusMessage = 'Healthy pace! You are within your monthly budget.';
      statusIcon = Icons.sentiment_very_satisfied_rounded;
    } else if (percentage < 85) {
      progressColor = const Color(0xFFF59E0B); // Amber
      statusMessage = 'Moderate burn rate. Watch discretionary expenses.';
      statusIcon = Icons.sentiment_neutral_rounded;
    } else {
      progressColor = const Color(0xFFEF4444); // Red
      statusMessage = 'High burn rate! Approaching monthly budget threshold.';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Header & Adjust
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.speed_rounded,
                      size: 20,
                      color: progressColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Budget & Pace',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '$daysRemaining days remaining in ${DateFormat('MMMM').format(now)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentage% Used',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: progressColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: Spend vs Budget Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _currencyFormat.format(totalPersonalExpenses),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? AppTheme.darkOnSurface
                          : AppTheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'of ${_currencyFormat.format(effectiveBudget)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '${_currencyFormat.format(remainingBudget)} left',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: isDark
                  ? const Color(0xFF2C3233)
                  : AppTheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 14),

          // Row 4: Daily Burn Rate & Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceContainer
                  : AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 18, color: progressColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$statusMessage (Avg ${_currencyFormat.format(dailyAverageSpend)}/day)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkOnSurface
                          : AppTheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
