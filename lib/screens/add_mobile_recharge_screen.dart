import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mobile_recharge_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../database/db_helper.dart';
import '../theme/app_theme.dart';

class AddMobileRechargeScreen extends StatefulWidget {
  final MobileRecharge? initialRecharge;

  const AddMobileRechargeScreen({super.key, this.initialRecharge});

  @override
  State<AddMobileRechargeScreen> createState() => _AddMobileRechargeScreenState();
}

class _AddMobileRechargeScreenState extends State<AddMobileRechargeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _planDescController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedOperator = 'Jio';
  DateTime _lastRechargedDate = DateTime.now();
  DateTime _validityTillDate = DateTime.now().add(const Duration(days: 28));
  int _reminderDaysBefore = 1;
  bool _notifyExpiry = true;
  bool _logExpense = false;
  bool _isSaving = false;

  final List<String> _operators = const ['Jio', 'Airtel', 'Vi', 'BSNL', 'Other'];

  static Color getOperatorColor(String operator) {
    switch (operator.toLowerCase()) {
      case 'jio':
        return const Color(0xFF0F52BA);
      case 'airtel':
        return const Color(0xFFE40000);
      case 'vi':
        return const Color(0xFFC70039);
      case 'bsnl':
        return const Color(0xFF008542);
      default:
        return const Color(0xFF5C6F84);
    }
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialRecharge;
    if (init != null) {
      _nameController.text = init.name;
      _phoneController.text = init.phoneNumber;
      _amountController.text =
          init.planLastRecharged > 0 ? init.planLastRecharged.toStringAsFixed(0) : '';
      _planDescController.text = init.planDescription;
      _noteController.text = init.note;
      _selectedOperator = _operators.contains(init.operator) ? init.operator : 'Other';
      _reminderDaysBefore = init.reminderDaysBefore;
      _notifyExpiry = init.notifyExpiry;
      _logExpense = init.logExpense;
      if (init.validityTill.isNotEmpty) {
        _validityTillDate = DateTime.tryParse(init.validityTill) ?? _validityTillDate;
      }
      if (init.lastRechargedDate.isNotEmpty) {
        _lastRechargedDate =
            DateTime.tryParse(init.lastRechargedDate) ?? _lastRechargedDate;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _planDescController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyValidityPreset(int days) {
    setState(() {
      _validityTillDate = _lastRechargedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickValidityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validityTillDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1000)),
    );
    if (picked != null) {
      setState(() => _validityTillDate = picked);
    }
  }

  Future<void> _pickLastRechargedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastRechargedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _lastRechargedDate = picked);
    }
  }

  Future<void> _saveRecharge() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final recharge = MobileRecharge(
        id: widget.initialRecharge?.id,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        operator: _selectedOperator,
        planLastRecharged: amount,
        planDescription: _planDescController.text.trim(),
        validityTill: DateFormat('yyyy-MM-dd').format(_validityTillDate),
        lastRechargedDate: DateFormat('yyyy-MM-dd').format(_lastRechargedDate),
        reminderDaysBefore: _reminderDaysBefore,
        notifyExpiry: _notifyExpiry,
        note: _noteController.text.trim(),
        logExpense: _logExpense,
      );

      int rechargeId = recharge.id ?? 0;
      if (widget.initialRecharge == null) {
        // Insert to SQLite first for offline availability
        rechargeId = await DbHelper.instance.insertMobileRecharge(recharge);
      } else {
        await DbHelper.instance.updateMobileRecharge(recharge);
      }

      // Schedule or cancel notification
      final notificationId = 30000 + (rechargeId % 10000);
      if (_notifyExpiry) {
        await NotificationService.instance.scheduleRechargeExpiryReminder(
          id: notificationId,
          name: recharge.name,
          operatorName: recharge.operator,
          phoneNumber: recharge.phoneNumber,
          amount: recharge.planLastRecharged,
          expiryDate: _validityTillDate,
          daysBefore: _reminderDaysBefore,
        );
      } else {
        await NotificationService.instance.cancelRechargeReminder(notificationId);
      }

      // Sync with Cloud Sheets in background
      final syncPayload = recharge.copyWith(id: rechargeId).toJson();
      if (widget.initialRecharge == null) {
        ApiService.instance.addMobileRecharge(syncPayload).catchError((_) => false);
      } else {
        ApiService.instance.updateMobileRecharge(syncPayload).catchError((_) => false);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recharge: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.initialRecharge != null;
    final opColor = getOperatorColor(_selectedOperator);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Mobile Recharge' : 'Add Mobile Recharge'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Card with Operator Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        opColor.withOpacity(0.9),
                        opColor.withOpacity(0.65),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.editorialShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_android_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedOperator.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text
                                  : 'Family / Self SIM',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Contact / SIM Name',
                    hintText: 'e.g. My Jio, Dad, Mom, Brother',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),

                // Phone Number Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '10-digit mobile number',
                    prefixIcon: const Icon(Icons.call_outlined),
                    prefixText: '+91 ',
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter phone number';
                    }
                    if (v.replaceAll(RegExp(r'\D'), '').length < 10) {
                      return 'Enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Operator Selector
                Text(
                  'Operator',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _operators.map((op) {
                    final isSelected = _selectedOperator == op;
                    final color = getOperatorColor(op);
                    return ChoiceChip(
                      label: Text(
                        op,
                        style: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: color,
                      backgroundColor: isDark
                          ? AppTheme.darkSurfaceContainer
                          : AppTheme.surfaceContainerLowest,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedOperator = op);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Plan Last Recharged Amount & Description
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Plan Amount',
                          prefixText: '₹ ',
                          hintText: '299',
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkSurfaceContainer
                              : AppTheme.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter amount' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _planDescController,
                        decoration: InputDecoration(
                          labelText: 'Plan Details',
                          hintText: 'e.g. 1.5GB/day, Unlimited',
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkSurfaceContainer
                              : AppTheme.surfaceContainerLowest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Validity Till Date Picker & Presets
                Text(
                  'Validity Till',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickValidityDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceContainer
                          : AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3E484A) : AppTheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expiry Date',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            Text(
                              DateFormat('EEE, MMM dd, yyyy').format(_validityTillDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.calendar_month_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Validity Preset Chips
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('28 Days'),
                      onPressed: () => _applyValidityPreset(28),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('56 Days'),
                      onPressed: () => _applyValidityPreset(56),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('84 Days'),
                      onPressed: () => _applyValidityPreset(84),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('365 Days'),
                      onPressed: () => _applyValidityPreset(365),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Last Recharged Date
                InkWell(
                  onTap: _pickLastRechargedDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceContainer
                          : AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF3E484A) : AppTheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Last Recharged: ${DateFormat('MMM dd, yyyy').format(_lastRechargedDate)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const Spacer(),
                        const Text(
                          'Change',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Reminder Notification Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF3E484A) : AppTheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: _notifyExpiry ? AppTheme.primary : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expiry Reminder Notification',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Alerts you before validity ends',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _notifyExpiry,
                            activeColor: AppTheme.primary,
                            onChanged: (val) => setState(() => _notifyExpiry = val),
                          ),
                        ],
                      ),
                      if (_notifyExpiry) ...[
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Remind me:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            DropdownButton<int>(
                              value: _reminderDaysBefore,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('On expiry day')),
                                DropdownMenuItem(value: 1, child: Text('1 day before')),
                                DropdownMenuItem(value: 2, child: Text('2 days before')),
                                DropdownMenuItem(value: 3, child: Text('3 days before')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _reminderDaysBefore = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Log Expense Switch
                SwitchListTile(
                  title: const Text('Record in Personal Expenses'),
                  subtitle: const Text('Add recharge amount to your expense log'),
                  value: _logExpense,
                  activeColor: AppTheme.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _logExpense = val),
                ),
                const SizedBox(height: 12),

                // Note Field
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'SIM slot 1, Office SIM, etc.',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Save Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveRecharge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Recharge' : 'Save Recharge',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
