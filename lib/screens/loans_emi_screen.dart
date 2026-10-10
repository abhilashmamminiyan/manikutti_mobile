import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/emi_model.dart';
import '../models/loan_model.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class LoansEmiScreen extends StatefulWidget {
  const LoansEmiScreen({super.key});

  @override
  State<LoansEmiScreen> createState() => _LoansEmiScreenState();
}

class _LoansEmiScreenState extends State<LoansEmiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _familyCode;

  List<EmiBill> _emiList = [];
  List<Loan> _loansList = [];
  List<LoanExpense> _loanExpenses = [];
  List<LoanRepayment> _loanRepayments = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final familyInfo = await ApiService.instance.getFamilyInfo();
      _familyCode =
          familyInfo?['familyCode'] ??
          await ApiService.instance.getCachedFamilyCode();

      if (_familyCode != null && _familyCode!.isNotEmpty) {
        // Fetch EMIs
        try {
          final emiRaw = await ApiService.instance.fetchEmiBills(_familyCode!);
          _emiList = emiRaw.map((item) => EmiBill.fromJson(item)).toList();
        } catch (e) {
          debugPrint('Error fetching EMIs: $e');
        }

        // Fetch Loans
        try {
          final loansData = await ApiService.instance.fetchLoansData(
            _familyCode!,
          );
          final rawLoans = (loansData['loans'] as List?) ?? [];
          final rawExpenses = (loansData['expenses'] as List?) ?? [];
          final rawRepayments = (loansData['repayments'] as List?) ?? [];

          _loansList = rawLoans.map((l) => Loan.fromJson(l)).toList();
          _loanExpenses = rawExpenses
              .map((e) => LoanExpense.fromJson(e))
              .toList();
          _loanRepayments = rawRepayments
              .map((r) => LoanRepayment.fromJson(r))
              .toList();
        } catch (e) {
          debugPrint('Error fetching loans: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalMonthlyEmiCommitment {
    return _emiList
        .where((e) => !e.isCompleted)
        .fold(0.0, (sum, item) => sum + item.monthlyPayment);
  }

  double get _totalLoanLiability {
    return _loansList
        .where((l) => l.status.toLowerCase() == 'active')
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> _handleMarkEmiPaid(EmiBill emi) async {
    if (emi.id == null) return;

    try {
      final newPaidMonths = emi.paidMonths + 1;
      final isCompleted = newPaidMonths >= emi.tenure;
      final newStatus = isCompleted ? 'Completed' : 'Paid';

      DateTime nextDate = DateTime.now();
      if (emi.dueDate.isNotEmpty) {
        final parsed = DateTime.tryParse(emi.dueDate);
        if (parsed != null) {
          nextDate = DateTime(parsed.year, parsed.month + 1, parsed.day);
        }
      } else {
        nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
      }
      final nextDueDateStr = DateFormat('yyyy-MM-dd').format(nextDate);

      final success = await ApiService.instance.updateEmiBillStatus(
        id: emi.id!,
        status: newStatus,
        paidMonths: newPaidMonths,
        dueDate: nextDueDateStr,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCompleted
                    ? '${emi.title} fully completed!'
                    : '${emi.title} marked paid! ($newPaidMonths/${emi.tenure} months)',
              ),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
        _loadAllData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update EMI on server'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddEmiDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final monthlyController = TextEditingController();
    final tenureController = TextEditingController();
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 30));
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Add New EMI Commitment',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title / Commitment Name',
                        hintText: 'e.g. Car Loan EMI, iPhone EMI',
                        prefixIcon: Icon(Icons.bookmark_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Loan Amount',
                              prefixIcon: Icon(Icons.currency_rupee_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: monthlyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Monthly EMI',
                              prefixIcon: Icon(Icons.calendar_month_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tenureController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tenure (Months)',
                              prefixIcon: Icon(Icons.timelapse_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: modalCtx,
                                initialDate: selectedDueDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDueDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppTheme.outlineVariant.withOpacity(
                                    0.5,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Due Date',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(selectedDueDate),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              final total =
                                  double.tryParse(
                                    amountController.text.trim(),
                                  ) ??
                                  0.0;
                              final monthly =
                                  double.tryParse(
                                    monthlyController.text.trim(),
                                  ) ??
                                  0.0;
                              final tenure =
                                  int.tryParse(tenureController.text.trim()) ??
                                  0;

                              if (title.isEmpty ||
                                  monthly <= 0 ||
                                  tenure <= 0) {
                                ScaffoldMessenger.of(modalCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill valid details'),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final payload = {
                                'title': title,
                                'amount': total,
                                'monthlyPayment': monthly,
                                'tenure': tenure,
                                'dueDate': DateFormat(
                                  'yyyy-MM-dd',
                                ).format(selectedDueDate),
                                'startDate': DateFormat(
                                  'yyyy-MM-dd',
                                ).format(DateTime.now()),
                                'familyCode': _familyCode ?? '',
                                'type': 'EMI',
                                'owner': 'Family',
                              };

                              final success = await ApiService.instance
                                  .createEmiBill(payload);
                              if (modalCtx.mounted) {
                                Navigator.pop(modalCtx);
                              }
                              if (success) {
                                _loadAllData();
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save EMI Commitment',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddLoanDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final emiController = TextEditingController();
    final assignedToController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.handshake_rounded,
                            color: AppTheme.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Add Family Loan',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Loan Name',
                        hintText: 'e.g. Home Renovation, Emergency Loan',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Principal Amount',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emiController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly EMI Contribution',
                        prefixIcon: Icon(Icons.event_repeat_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: assignedToController,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Member / Borrower',
                        hintText: 'e.g. Self, Brother, Family',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final amount =
                                  double.tryParse(
                                    amountController.text.trim(),
                                  ) ??
                                  0.0;
                              final monthlyEMI =
                                  double.tryParse(emiController.text.trim()) ??
                                  0.0;
                              final assigned = assignedToController.text.trim();

                              if (name.isEmpty || amount <= 0) {
                                ScaffoldMessenger.of(modalCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter valid details'),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final success = await ApiService.instance
                                  .createLoan(
                                    loanName: name,
                                    amount: amount,
                                    monthlyEMI: monthlyEMI,
                                    assignedTo: assigned.isEmpty
                                        ? 'Family'
                                        : assigned,
                                    familyCode: _familyCode ?? '',
                                  );

                              if (modalCtx.mounted) {
                                Navigator.pop(modalCtx);
                              }
                              if (success) {
                                _loadAllData();
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Family Loan',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSummary(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.heroCardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'COMMITMENTS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Icon(
                Icons.account_balance_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Monthly EMI Outflow',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(_totalMonthlyEmiCommitment),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total Loan Liabilities:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(_totalLoanLiability),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmiTab(ThemeData theme, bool isDark) {
    if (_emiList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceContainer
                    : AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                size: 44,
                color: AppTheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No active EMIs tracked yet.',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add loan commitments to track monthly payoffs.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.outlineVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: _emiList.length,
      itemBuilder: (context, index) {
        final emi = _emiList[index];
        final progress = emi.progressPercentage;
        final isCompleted = emi.isCompleted;

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
                  : AppTheme.outlineVariant.withOpacity(0.18),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emi.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: AppTheme.outline,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              emi.dueDate.isNotEmpty
                                  ? 'Due: ${emi.dueDate}'
                                  : 'Ongoing',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.outline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                          color: AppTheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${emi.paidMonths} / ${emi.tenure} Months',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isCompleted ? Colors.green : AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.outline,
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
                    isCompleted ? Colors.green : AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Mark Paid Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isCompleted
                        ? Colors.green
                        : AppTheme.primary,
                    side: BorderSide(
                      color: isCompleted
                          ? Colors.green.withOpacity(0.4)
                          : AppTheme.primary.withOpacity(0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isCompleted ? null : () => _handleMarkEmiPaid(emi),
                  icon: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isCompleted
                        ? 'Completed'
                        : 'Mark ${DateFormat('MMMM').format(DateTime.now())} Paid',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoansTab(ThemeData theme, bool isDark) {
    if (_loansList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceContainer
                    : AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.handshake_outlined,
                size: 44,
                color: AppTheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No family loans registered.',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log loans to manage liability across members.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.outlineVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: _loansList.length,
      itemBuilder: (context, index) {
        final loan = _loansList[index];
        final relatedRepayments = _loanRepayments
            .where((r) => r.loanName.toLowerCase() == loan.name.toLowerCase())
            .fold(0.0, (sum, r) => sum + r.amount);
        final relatedExpenses = _loanExpenses
            .where((e) => e.loanName.toLowerCase() == loan.name.toLowerCase())
            .fold(0.0, (sum, e) => sum + e.amount);

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
                  : AppTheme.outlineVariant.withOpacity(0.18),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceContainer
                                : AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Assigned: ${loan.assignedTo}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(loan.amount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.error,
                        ),
                      ),
                      Text(
                        'Principal',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceContainer
                      : AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly EMI',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.outline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(loan.monthlyEMI),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (relatedExpenses > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Disbursed',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.outline,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormat.format(relatedExpenses),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Repaid',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.outline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(relatedRepayments),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.loansAndEmi,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: isDark ? AppTheme.darkOnSurface : AppTheme.primary,
          unselectedLabelColor: AppTheme.outline,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: l10n.emis),
            Tab(text: l10n.loans),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _loadAllData,
              child: Column(
                children: [
                  _buildHeroSummary(theme, isDark),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEmiTab(theme, isDark),
                        _buildLoansTab(theme, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? l10n.addEmi : l10n.addLoan,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddEmiDialog();
          } else {
            _showAddLoanDialog();
          }
        },
      ),
    );
  }
}
