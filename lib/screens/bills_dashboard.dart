import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/utility_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_drawer.dart';
import 'add_utility_screen.dart';
import '../theme/app_theme.dart';

class BillsDashboard extends StatefulWidget {
  const BillsDashboard({super.key});

  @override
  State<BillsDashboard> createState() => _BillsDashboardState();
}

class _BillsDashboardState extends State<BillsDashboard> {
  List<UtilityBill> _utilities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUtilities();
  }

  Future<void> _loadUtilities() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.instance.fetchUtilities();
      setState(() {
        _utilities = data.map((json) => UtilityBill.fromJson(json)).toList();
      });
      _scheduleNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading utilities: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int? _calculateDaysLeft(String nextDueDate) {
    if (nextDueDate.isEmpty) return null;
    final due = DateTime.tryParse(nextDueDate);
    if (due == null) return null;
    final today = DateTime.now();
    final diff = due.difference(today).inDays;
    return diff;
  }

  void _scheduleNotifications() {
    final isMalayalam = Localizations.localeOf(context).languageCode == 'ml';
    final bodyStr = isMalayalam
        ? 'റീചാർജ് ചെയ്തോ?'
        : 'Have you paid the recharge?';

    for (var util in _utilities) {
      if (util.nextDueDate.isNotEmpty && util.id != null) {
        final due = DateTime.tryParse(util.nextDueDate);
        if (due != null) {
          // Schedule at 9 AM on the due date
          final scheduledDate = DateTime(due.year, due.month, due.day, 9, 0);
          NotificationService.instance.scheduleUtilityReminder(
            id: 20000 + util.id!, // offset to avoid conflicts
            title: util.title,
            body: bodyStr,
            nextDueDate: scheduledDate,
          );
        }
      }
    }
  }

  void _showPayDialog(UtilityBill util) {
    DateTime selectedDate = DateTime.now();
    bool logExpense = util.logExpense;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text('Pay ${util.title}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Amount: ₹${util.amount} / ${util.validity}'),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Paid On'),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(selectedDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null)
                        setStateSB(() => selectedDate = picked);
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Log as Expense'),
                    value: logExpense,
                    onChanged: (val) =>
                        setStateSB(() => logExpense = val ?? false),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Call API to mark as paid
                    if (util.id != null) {
                      final success = await ApiService.instance.markUtilityPaid(
                        util.id!,
                        selectedDate.toIso8601String(),
                        logExpense,
                      );
                      if (success) {
                        _loadUtilities();
                      }
                    }
                  },
                  child: const Text('Mark as Paid'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Utilities & Bills',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _utilities.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceContainer : AppTheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 48,
                      color: AppTheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No utilities or recurring bills found.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.outline,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _utilities.length,
              itemBuilder: (context, index) {
                final util = _utilities[index];
                final daysLeft = _calculateDaysLeft(util.nextDueDate);
                final isOverdue = daysLeft != null && daysLeft < 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceContainerLowest : AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.ambientCardShadow,
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C3233) : AppTheme.outlineVariant.withOpacity(0.18),
                    ),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              util.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkOnSurface : AppTheme.onSurface,
                              ),
                            ),
                          ),
                          if (daysLeft != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? AppTheme.error.withOpacity(0.1)
                                    : const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isOverdue
                                    ? '${daysLeft.abs()} Days Overdue'
                                    : '$daysLeft Days Left',
                                style: TextStyle(
                                  color: isOverdue
                                      ? AppTheme.error
                                      : const Color(0xFF10B981),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${util.amount} • ${util.validity}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next Due: ${util.nextDueDate.isNotEmpty ? DateFormat('MMM dd, yyyy').format(DateTime.parse(util.nextDueDate)) : 'Unknown'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton.icon(
                              onPressed: () => _showPayDialog(util),
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppTheme.primary,
                              ),
                              label: Text(
                                'Mark Paid',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddUtilityScreen()),
            );
            if (result == true) {
              _loadUtilities();
            }
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Add Utility',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
