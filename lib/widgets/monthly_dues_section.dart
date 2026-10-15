import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class MonthlyDuesSection extends StatelessWidget {
  final List<dynamic> monthlyExpenses;
  final String? userEmail;
  final Function(int id) onMarkPaid;
  final VoidCallback onAddMonthlyDues;
  final Function(dynamic item)? onEditItem;
  final Function(int id)? onDeleteItem;

  const MonthlyDuesSection({
    super.key,
    required this.monthlyExpenses,
    required this.userEmail,
    required this.onMarkPaid,
    required this.onAddMonthlyDues,
    this.onEditItem,
    this.onDeleteItem,
  });

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  bool _isItemPaidThisMonth(dynamic item) {
    final lastPaidDateStr = item['lastPaidDate'] as String?;
    if (lastPaidDateStr == null || lastPaidDateStr.isEmpty) return false;
    try {
      final lastPaid = DateTime.parse(lastPaidDateStr);
      final today = DateTime.now();
      return lastPaid.month == today.month && lastPaid.year == today.year;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (monthlyExpenses.isEmpty) {
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Utilities & Dues',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005953),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onAddMonthlyDues,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add Monthly Dues',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'No regular commitments or utilities registered yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppTheme.darkOnSurfaceVariant
                    : AppTheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    double totalAmount = 0.0;
    double paidAmount = 0.0;
    for (final item in monthlyExpenses) {
      final amt = (item['amount'] as num).toDouble();
      totalAmount += amt;
      if (_isItemPaidThisMonth(item)) {
        paidAmount += amt;
      }
    }
    final pendingAmount = totalAmount - paidAmount;

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
          // Header matching screenshot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Utilities & Dues',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Fixed Dues: ${_currencyFormat.format(totalAmount)} • Pending: ${_currencyFormat.format(pendingAmount)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pendingAmount > 0
                            ? const Color(0xFFE65100)
                            : const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005953),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onAddMonthlyDues,
                child: const Text(
                  'Add Monthly Dues',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Table Header (Bill Title, Due Day, Status, Amount, Actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Bill Title',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkOnSurface
                          : AppTheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Due Day',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkOnSurface
                          : AppTheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      'Status',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.darkOnSurface
                            : AppTheme.onSurface,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Amount',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.darkOnSurface
                            : AppTheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Actions',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppTheme.darkOnSurface
                            : AppTheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: isDark
                ? const Color(0xFF2C3233)
                : AppTheme.outlineVariant.withValues(alpha: 0.25),
            thickness: 1,
            height: 16,
          ),

          // List of Rows (Exact replica of screenshot items)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthlyExpenses.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark
                  ? const Color(0xFF242A2B)
                  : AppTheme.outlineVariant.withValues(alpha: 0.15),
              thickness: 0.8,
              height: 20,
            ),
            itemBuilder: (context, index) {
              final item = monthlyExpenses[index];
              final id = item['id'] as int;
              final title = item['title'] as String;
              final amount = (item['amount'] as num).toDouble();
              final dueDay = item['dueDay'] as int;
              final isPaid = _isItemPaidThisMonth(item);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 4.0,
                ),
                child: Row(
                  children: [
                    // 1. Bill Title
                    Expanded(
                      flex: 5,
                      child: Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkOnSurface
                              : AppTheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 2. Due Day
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Day $dueDay',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // 3. Status Pill (Orange for Unpaid, Green for Paid)
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE65100),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            isPaid ? 'Paid' : 'Unpaid',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 4. Amount
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _currencyFormat.format(amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTheme.darkOnSurface
                                : AppTheme.onSurface,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // 5. Actions (Pencil / Trash / Check)
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isPaid)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => onMarkPaid(id),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 19,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          if (onEditItem != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => onEditItem!(item),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Color(0xFF0D9488),
                                ),
                              ),
                            ),
                          if (onDeleteItem != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => onDeleteItem!(id),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
