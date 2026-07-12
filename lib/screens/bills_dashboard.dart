import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/utility_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_drawer.dart';
import 'add_utility_screen.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading utilities: $e')),
        );
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
    final bodyStr = isMalayalam ? 'റീചാർജ് ചെയ്തോ?' : 'Have you paid the recharge?';

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
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setStateSB(() => selectedDate = picked);
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Log as Expense'),
                    value: logExpense,
                    onChanged: (val) => setStateSB(() => logExpense = val ?? false),
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
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Utilities & Bills')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _utilities.isEmpty
              ? const Center(child: Text('No utilities found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _utilities.length,
                  itemBuilder: (context, index) {
                    final util = _utilities[index];
                    final daysLeft = _calculateDaysLeft(util.nextDueDate);
                    final isOverdue = daysLeft != null && daysLeft < 0;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    util.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                                if (daysLeft != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isOverdue ? '${daysLeft.abs()} Days Overdue' : '$daysLeft Days Left',
                                      style: TextStyle(
                                        color: isOverdue ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('₹${util.amount} / ${util.validity}'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Next Due: ${util.nextDueDate.isNotEmpty ? DateFormat('MMM dd, yyyy').format(DateTime.parse(util.nextDueDate)) : 'Unknown'}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showPayDialog(util),
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Mark Paid'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                                    foregroundColor: theme.primaryColor,
                                    elevation: 0,
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddUtilityScreen()),
          );
          if (result == true) {
            _loadUtilities();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Utility'),
      ),
    );
  }
}
