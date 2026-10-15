import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _transactionType = 'Expense'; // 'Expense' | 'Income' | 'Family'
  String _selectedCategory = 'Food';
  String _selectedBankAccount = TransactionModel.bankSbi;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _expenseCategories = [
    'Food',
    'Housing',
    'Transport',
    'Leisure',
    'Health',
    'Shopping',
    'Investment',
  ];

  final List<String> _incomeCategories = [
    'Salary',
    'Kadam',
    'Investment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = _expenseCategories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Choose correct categories list based on type
  List<String> get _categories {
    if (_transactionType == 'Income') return _incomeCategories;
    return _expenseCategories;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = await ApiService.instance.getUserEmail();

      final transaction = TransactionModel(
        date: _selectedDate.toIso8601String(),
        amount: amount,
        category: _selectedCategory,
        note: _noteController.text.trim(),
        type: _transactionType,
        isPaid: true,
        addedBy: email,
        synced: false, // Initial state is unsynced, trigger sync after save
        bankAccount: _selectedBankAccount,
      );

      await DbHelper.instance.insertTransaction(transaction);

      if (mounted) {
        Navigator.pop(context, true); // Returns true to trigger refresh
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Record Transaction',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stitch Segmented Type Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          'Expense',
                          'Personal Exp',
                          Icons.arrow_upward_rounded,
                          AppTheme.error,
                        ),
                      ),
                      Expanded(
                        child: _buildTypeButton(
                          'Income',
                          'Personal Inc',
                          Icons.arrow_downward_rounded,
                          const Color(0xFF10B981),
                        ),
                      ),
                      Expanded(
                        child: _buildTypeButton(
                          'Family',
                          'Family Pool',
                          Icons.diversity_3_rounded,
                          AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Amount Card (Editorial Scale)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainerLowest
                        : AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.ambientCardShadow,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2C3233)
                          : AppTheme.outlineVariant.withOpacity(0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AMOUNT (INR)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          prefixStyle: theme.textTheme.headlineLarge?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                          hintText: '0.00',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Note Input
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description / Note',
                    hintText: 'e.g., Grocery shopping, Electricity bill...',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: 16),

                // Bank Account Selector Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainerLowest
                        : AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2C3233)
                          : AppTheme.outlineVariant.withOpacity(0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'BANK ACCOUNT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: isDark
                                  ? AppTheme.darkOnSurfaceVariant
                                  : AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBankOption(
                              name: 'SBI',
                              bankValue: TransactionModel.bankSbi,
                              color: const Color(0xFF1E88E5),
                              icon: Icons.account_balance_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBankOption(
                              name: 'Canara Bank',
                              bankValue: TransactionModel.bankCanara,
                              color: const Color(0xFF0284C7),
                              icon: Icons.account_balance_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Date Picker Card
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceContainerLowest
                          : AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C3233)
                            : AppTheme.outlineVariant.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: AppTheme.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Date of Record',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceContainer
                                : AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_selectedDate),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Category Title
                Text(
                  'Select Category',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Categories Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : (isDark
                                    ? AppTheme.darkSurfaceContainerLowest
                                    : AppTheme.surfaceContainerLowest),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected
                              ? AppTheme.subtleFloatShadow
                              : null,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : (isDark
                                      ? const Color(0xFF2C3233)
                                      : AppTheme.outlineVariant.withOpacity(
                                          0.2,
                                        )),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? AppTheme.darkOnSurface
                                        : AppTheme.onSurface),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 36),

                // Save Button
                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Save to Ledger',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    String type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _transactionType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _transactionType = type;
          _selectedCategory = _categories.first;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkSurfaceContainerLowest : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected ? AppTheme.subtleFloatShadow : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.outline, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : AppTheme.onSurface)
                    : AppTheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankOption({
    required String name,
    required String bankValue,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedBankAccount == bankValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBankAccount = bankValue;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.22 : 0.12)
              : (isDark
                    ? AppTheme.darkSurfaceContainer.withOpacity(0.6)
                    : AppTheme.surfaceContainerHigh.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark
                      ? const Color(0xFF374151)
                      : AppTheme.outlineVariant.withOpacity(0.3)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : AppTheme.outline),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : color)
                    : (isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
