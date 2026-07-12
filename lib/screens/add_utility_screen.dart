import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AddUtilityScreen extends StatefulWidget {
  const AddUtilityScreen({super.key});

  @override
  State<AddUtilityScreen> createState() => _AddUtilityScreenState();
}

class _AddUtilityScreenState extends State<AddUtilityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _validityAmountController = TextEditingController();
  final _noteController = TextEditingController();

  String _validityUnit = 'Months';
  DateTime _selectedDate = DateTime.now();
  bool _logExpense = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _validityAmountController.dispose();
    _noteController.dispose();
    super.dispose();
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

    setState(() => _isLoading = true);

    try {
      final validity = '${_validityAmountController.text} $_validityUnit';
      
      final utility = {
        'title': _titleController.text.trim(),
        'amount': double.parse(_amountController.text),
        'validity': validity,
        'status': 'Active',
        'lastPaidDate': _selectedDate.toIso8601String(),
        'note': _noteController.text.trim(),
        'logExpense': _logExpense,
      };

      final success = await ApiService.instance.addUtility(utility);

      if (success) {
        if (mounted) Navigator.pop(context, true);
      } else {
        throw Exception('Failed to save utility');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Utility / Subscription')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Utility Name (e.g. Home WiFi, Mobile)',
                    prefixIcon: Icon(Icons.wifi),
                  ),
                  validator: (value) => value!.isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: (value) => value!.isEmpty ? 'Enter amount' : null,
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _validityAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Validity Duration',
                          prefixIcon: Icon(Icons.timer),
                        ),
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _validityUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: ['Days', 'Months', 'Years'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _validityUnit = newValue!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, color: theme.primaryColor),
                            const SizedBox(width: 12),
                            const Text('Paid On Date', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                CheckboxListTile(
                  title: const Text('Mark as Expense in Personal Sheet'),
                  subtitle: const Text('Automatically logs this payment to your expenses.'),
                  value: _logExpense,
                  onChanged: (val) {
                    setState(() => _logExpense = val ?? false);
                  },
                  activeColor: theme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 20),
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                ),
                
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Utility'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
