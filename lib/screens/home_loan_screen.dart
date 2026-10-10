import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/home_loan_model.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class HomeLoanScreen extends StatefulWidget {
  const HomeLoanScreen({super.key});

  @override
  State<HomeLoanScreen> createState() => _HomeLoanScreenState();
}

class _HomeLoanScreenState extends State<HomeLoanScreen> {
  bool _isLoading = true;
  String? _familyCode;
  List<HomeLoanEntry> _history = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadHomeLoanData();
  }

  Future<void> _loadHomeLoanData() async {
    setState(() => _isLoading = true);
    try {
      final familyInfo = await ApiService.instance.getFamilyInfo();
      _familyCode =
          familyInfo?['familyCode'] ??
          await ApiService.instance.getCachedFamilyCode();

      if (_familyCode != null && _familyCode!.isNotEmpty) {
        final rawItems = await ApiService.instance.fetchHomeLoanHistory(
          _familyCode!,
        );
        final list = rawItems.map((j) => HomeLoanEntry.fromJson(j)).toList();
        list.sort((a, b) {
          final da = DateTime.tryParse(a.date) ?? DateTime(1970);
          final db = DateTime.tryParse(b.date) ?? DateTime(1970);
          return da.compareTo(db);
        });
        _history = list;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading home loan data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _latestBalance {
    if (_history.isEmpty) return 0.0;
    return _history.last.balance;
  }

  double get _initialBalance {
    if (_history.isEmpty) return 0.0;
    return _history.first.balance + _history.first.principal;
  }

  double get _totalPaidPrincipal {
    return _history.fold(0.0, (sum, item) => sum + item.principal);
  }

  double get _totalPaidInterest {
    return _history.fold(0.0, (sum, item) => sum + item.interest);
  }

  double get _progressPercent {
    if (_initialBalance <= 0) return 0.0;
    final progress = (_initialBalance - _latestBalance) / _initialBalance;
    return progress.clamp(0.0, 1.0);
  }

  double get _effectiveAnnualRate {
    if (_history.isEmpty) return 8.5;
    final lastPayment = _history.last;
    double prevBalance = lastPayment.balance + lastPayment.principal;
    if (_history.length > 1) {
      prevBalance = _history[_history.length - 2].balance;
    }
    if (prevBalance <= 0) return 8.5;
    final monthlyRate = lastPayment.interest / prevBalance;
    final annualRate = monthlyRate * 12 * 100;
    if (annualRate <= 0 || annualRate > 30) return 8.5;
    return double.parse(annualRate.toStringAsFixed(2));
  }

  void _showAddRepaymentDialog() {
    final principalController = TextEditingController();
    final interestController = TextEditingController();
    final totalPaymentController = TextEditingController();
    final balanceController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;

    final prevBal = _latestBalance;
    if (prevBal > 0) {
      // Suggest reasonable defaults based on previous payment
      if (_history.isNotEmpty) {
        final last = _history.last;
        interestController.text = last.interest.toStringAsFixed(0);
        principalController.text = last.principal.toStringAsFixed(0);
        totalPaymentController.text = last.totalPayment.toStringAsFixed(0);
        balanceController.text = (prevBal - last.principal).toStringAsFixed(0);
      }
    }

    void recalculateTotals() {
      final p = double.tryParse(principalController.text.trim()) ?? 0.0;
      final i = double.tryParse(interestController.text.trim()) ?? 0.0;
      totalPaymentController.text = (p + i).toStringAsFixed(0);
      if (prevBal > 0) {
        balanceController.text = (prevBal - p).toStringAsFixed(0);
      }
    }

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
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.home_work_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Log Home Loan Repayment',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: modalCtx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat(
                                    'MMMM dd, yyyy',
                                  ).format(selectedDate),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.edit_calendar_rounded,
                              size: 18,
                              color: AppTheme.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: principalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Principal (₹)',
                              prefixIcon: Icon(Icons.currency_rupee_rounded),
                            ),
                            onChanged: (_) {
                              setModalState(() {
                                recalculateTotals();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: interestController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Interest (₹)',
                              prefixIcon: Icon(Icons.percent_rounded),
                            ),
                            onChanged: (_) {
                              setModalState(() {
                                recalculateTotals();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: totalPaymentController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Payment (₹)',
                              prefixIcon: Icon(Icons.payment_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: balanceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Remaining Balance (₹)',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_rounded,
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
                              final p =
                                  double.tryParse(
                                    principalController.text.trim(),
                                  ) ??
                                  0.0;
                              final i =
                                  double.tryParse(
                                    interestController.text.trim(),
                                  ) ??
                                  0.0;
                              final total =
                                  double.tryParse(
                                    totalPaymentController.text.trim(),
                                  ) ??
                                  (p + i);
                              final bal =
                                  double.tryParse(
                                    balanceController.text.trim(),
                                  ) ??
                                  (prevBal - p);

                              if (total <= 0) {
                                ScaffoldMessenger.of(modalCtx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter valid payment'),
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final dateStr = DateFormat(
                                'yyyy-MM-dd',
                              ).format(selectedDate);

                              final success = await ApiService.instance
                                  .addHomeLoanRepayment(
                                    date: dateStr,
                                    totalPayment: total,
                                    principal: p,
                                    interest: i,
                                    balance: bal,
                                    familyCode: _familyCode ?? '',
                                  );

                              if (modalCtx.mounted) {
                                Navigator.pop(modalCtx);
                              }
                              if (success) {
                                _loadHomeLoanData();
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
                              'Save Repayment',
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

  Future<void> _handleDelete(HomeLoanEntry entry) async {
    if (entry.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'Remove repayment of ${_currencyFormat.format(entry.totalPayment)} on ${entry.date}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.instance.deleteHomeLoanRepayment(
        entry.id!,
      );
      if (success) {
        _loadHomeLoanData();
      }
    }
  }

  Widget _buildHeroSummary(ThemeData theme, bool isDark) {
    final percentInt = (_progressPercent * 100).toInt();

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
                  'SANCTUARY MORTGAGE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_effectiveAnnualRate.toStringAsFixed(1)}% p.a.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Remaining Principal Balance',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(_latestBalance),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Principal Cleared: ${_currencyFormat.format(_totalPaidPrincipal)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$percentInt%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progressPercent,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.secondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Sub-metrics row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Total Paid',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currencyFormat.format(
                        _totalPaidPrincipal + _totalPaidInterest,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Column(
                  children: [
                    Text(
                      'Interest Paid',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currencyFormat.format(_totalPaidInterest),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Column(
                  children: [
                    Text(
                      'Installments',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_history.length}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
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
  }

  Widget _buildHistoryList(
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    if (_history.isEmpty) {
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
                Icons.history_rounded,
                size: 44,
                color: AppTheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noRepaymentsYet,
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add repayment records to track amortization and principal payoff.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.outlineVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Display history with newest entries first
    final reversedList = _history.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: reversedList.length,
      itemBuilder: (context, index) {
        final entry = reversedList[index];

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        entry.date.isNotEmpty ? entry.date : 'Recent',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _currencyFormat.format(entry.totalPayment),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      if (entry.id != null)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (val) {
                            if (val == 'delete') {
                              _handleDelete(entry);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: AppTheme.error),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                          'Principal',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.outline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(entry.principal),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Interest',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.outline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(entry.interest),
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
                          'Balance',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.outline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(entry.balance),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
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
          l10n.homeLoan,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadHomeLoanData,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _loadHomeLoanData,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSummary(theme, isDark),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.repaymentHistory,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceContainer
                                : AppTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_history.length} Entries',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildHistoryList(theme, isDark, l10n)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          l10n.addRepayment,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        onPressed: _showAddRepaymentDialog,
      ),
    );
  }
}
