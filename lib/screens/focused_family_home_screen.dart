import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/repayment_schedules_data.dart';
import '../models/emi_model.dart';
import '../models/home_loan_model.dart';
import '../models/loan_model.dart';
import '../services/emi_reminder_service.dart';
import '../services/feature_flag_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

class FocusedFamilyHomeScreen extends StatefulWidget {
  final String displayName;
  final String userEmail;
  final String? familyCode;
  final List<Loan> loans;
  final List<EmiBill> emiBills;
  final HomeLoanConfig? homeLoanConfig;
  final List<HomeLoanEntry> homeLoanHistory;
  final List<MandatoryEmiCheckItem> mandatoryEmiChecks;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onLogout;

  const FocusedFamilyHomeScreen({
    super.key,
    required this.displayName,
    required this.userEmail,
    required this.familyCode,
    required this.loans,
    required this.emiBills,
    this.homeLoanConfig,
    required this.homeLoanHistory,
    required this.mandatoryEmiChecks,
    required this.isLoading,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<FocusedFamilyHomeScreen> createState() =>
      _FocusedFamilyHomeScreenState();
}

class _FocusedFamilyHomeScreenState extends State<FocusedFamilyHomeScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  bool _isProcessingAction = false;
  final Set<String> _locallyPaidKeys = {};

  String get _currentMonthKey => DateFormat('yyyy-MM').format(DateTime.now());

  Future<void> _handleFallbackMarkPaid(MandatoryEmiCheckItem item) async {
    if (widget.familyCode == null || widget.familyCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Family Code missing. Please sync first.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark EMI as Paid?'),
        content: Text(
          'Mark "${item.title}" (₹${_currencyFormat.format(item.emiAmount)}) as paid for this month?\n\n'
          'Use this fallback if the bank debit SMS was not received or delayed. '
          'Confirming will update the ledger and notify Mom and Abhilash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final success = await EmiReminderService.instance.confirmStatus(
        familyCode: widget.familyCode!,
        item: item,
        paidToPayer: true,
      );

      if (success) {
        setState(() {
          _locallyPaidKeys.add(item.loanKey);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Marked "${item.title}" as paid! Notification sent to Mom & Abhilash.',
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
        await widget.onRefresh();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to confirm payment. Please check network connection.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _showScheduleModal(LoanRepaymentSchedule schedule, int paidMonths) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceContainerLowest
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.loanName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Agreement: ${schedule.agreementNo} • ${schedule.interestRate}% p.a.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? AppTheme.darkOnSurfaceVariant
                                    : AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Summary Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceContainer
                          : AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricColumn(
                          label: 'Remaining Principal',
                          value: _currencyFormat.format(
                            schedule.getRemainingPrincipal(paidMonths),
                          ),
                          color: AppTheme.primary,
                        ),
                        _buildMetricColumn(
                          label: 'Paid Principal',
                          value: _currencyFormat.format(
                            schedule.getPaidPrincipal(paidMonths),
                          ),
                          color: Colors.green.shade700,
                        ),
                        _buildMetricColumn(
                          label: 'Paid Interest',
                          value: _currencyFormat.format(
                            schedule.getPaidInterest(paidMonths),
                          ),
                          color: Colors.orange.shade800,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Full Repayment Schedule (${schedule.installments.length} Months):',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: schedule.installments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final inst = schedule.installments[index];
                        final isPaid = inst.instNo <= paidMonths;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          color: isPaid
                              ? (isDark
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.green.shade50)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isPaid
                                    ? Colors.green.shade700
                                    : (isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200),
                                child: Text(
                                  '#${inst.instNo}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isPaid
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inst.dueDate,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Bal: ${_currencyFormat.format(inst.closingPrincipal)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currencyFormat.format(
                                        inst.installmentAmount,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'P: ${_currencyFormat.format(inst.principal)} • I: ${_currencyFormat.format(inst.interest)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isPaid) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final flags = FeatureFlagService.instance;

    final showSmsAuto = flags.isEnabled(FeatureKeys.smsAutoTracking);
    final showLoans = flags.isEnabled(FeatureKeys.loansEmiLedger);
    final showSchedules = flags.isEnabled(FeatureKeys.repaymentSchedules);
    final showHomeLoan = flags.isEnabled(FeatureKeys.homeLoan);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manikutti Family Hub',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.displayName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AppTheme.darkOnSurfaceVariant
                    : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: widget.isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading family finances...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Live SMS Zero-Confirmation Status (if sms_auto_tracking enabled)
                    if (showSmsAuto) ...[
                      _buildZeroConfirmationSmsCard(context, isDark),
                      const SizedBox(height: 18),
                    ],

                    // 2. Mark Assigned Loan as Paid Section with Fallback 1-Tap (if loans_emi_ledger or home_loan enabled)
                    if (showLoans || showHomeLoan) ...[
                      _buildLoansPaymentSection(context, isDark),
                      const SizedBox(height: 20),
                    ],

                    // 3. Repayment Schedule Breakdown (if repayment_schedules enabled)
                    if (showSchedules) ...[
                      _buildRepaymentScheduleSection(context, isDark),
                      const SizedBox(height: 24),
                    ],

                    // 4. Safe Empty State Card if no capability sections are active
                    if (!showSmsAuto &&
                        !showLoans &&
                        !showHomeLoan &&
                        !showSchedules) ...[
                      _buildCapabilityFallbackCard(context, isDark),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildZeroConfirmationSmsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, color: AppTheme.primary, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'SMS Auto-Pay Active',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Zero User Action Needed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceContainer
                  : AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 20,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'When an incoming bank SMS matches a configured EMI payment amount, the app auto-marks the EMI as paid immediately in the background without any confirmation prompts or user acceptance. Push notifications are automatically dispatched to Mom and Abhilash.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
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

  Widget _buildLoansPaymentSection(BuildContext context, bool isDark) {
    final checks = widget.mandatoryEmiChecks.isNotEmpty
        ? widget.mandatoryEmiChecks
        : _buildFallbackChecks();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Assigned Loans & Fallback Payment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Text(
                _currentMonthKey,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'If the bank SMS failed or was delayed, use the 1-tap button below to mark the installment paid manually.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          if (checks.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No active assigned loans for this month.'),
              ),
            ),
          ] else ...[
            ...checks.map((item) => _buildLoanCard(item, isDark)),
          ],
        ],
      ),
    );
  }

  List<MandatoryEmiCheckItem> _buildFallbackChecks() {
    final list = <MandatoryEmiCheckItem>[];
    if (widget.homeLoanConfig != null &&
        widget.homeLoanConfig!.monthlyEMI > 0) {
      list.add(
        MandatoryEmiCheckItem(
          loanKey: 'Home Loan',
          title: 'Home Loan EMI',
          emiAmount: widget.homeLoanConfig!.monthlyEMI,
          payerName: widget.homeLoanConfig!.payerName,
          shareRecipient: widget.homeLoanConfig!.shareRecipient,
          dueDay: widget.homeLoanConfig!.dueDay,
          paidToPayer: false,
          sharedWithRecipient: false,
          autoSmsDetected: false,
          isResponsibleUser: true,
        ),
      );
    }
    for (final loan in widget.loans.where(
      (l) => l.status.toLowerCase() == 'active',
    )) {
      list.add(
        MandatoryEmiCheckItem(
          loanKey: loan.name,
          title: loan.name,
          emiAmount: loan.monthlyEMI,
          payerName: loan.payerName,
          shareRecipient: loan.shareRecipient,
          dueDay: 10,
          paidToPayer: false,
          sharedWithRecipient: false,
          autoSmsDetected: false,
          isResponsibleUser: true,
        ),
      );
    }
    if (list.isEmpty) {
      for (final s in RepaymentSchedulesData.allSchedules) {
        list.add(
          MandatoryEmiCheckItem(
            loanKey: s.loanName,
            title: s.loanName,
            emiAmount: s.monthlyEmi,
            payerName: s.payer.isNotEmpty ? s.payer : 'Ajesh',
            shareRecipient: s.shareRecipient.isNotEmpty
                ? s.shareRecipient
                : 'Abhilash',
            dueDay: 5,
            paidToPayer: false,
            sharedWithRecipient: false,
            autoSmsDetected: false,
            isResponsibleUser: true,
          ),
        );
      }
    }
    return list;
  }

  Widget _buildCapabilityFallbackCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.family_restroom_rounded,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to Manikutti Family Hub',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'No active loans, SMS auto-pay, or dues pending for your current role view. You can test role views or customize theme colors in Settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open Settings & Role Switcher'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(MandatoryEmiCheckItem item, bool isDark) {
    final isPaid = item.paidToPayer || _locallyPaidKeys.contains(item.loanKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPaid
            ? (isDark
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.green.shade50)
            : (isDark
                  ? AppTheme.darkSurfaceContainer
                  : AppTheme.surfaceContainerLow),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? Colors.green.shade400
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _currencyFormat.format(item.emiAmount),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: isPaid ? Colors.green.shade700 : AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Payer: ${item.payerName} → Share: ${item.shareRecipient}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isPaid) ...[
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.autoSmsDetected
                          ? 'Auto-Marked via SMS ✓'
                          : 'Marked as Paid ✓',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Due: ${item.dueDay}th of month',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessingAction
                      ? null
                      : () => _handleFallbackMarkPaid(item),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    'Mark Paid (₹${item.emiAmount.toStringAsFixed(0)})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentScheduleSection(BuildContext context, bool isDark) {
    final schedules = RepaymentSchedulesData.allSchedules;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Repayment Schedules (PDF Linked)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Track remaining principal, paid principal, remaining interest, and contractual interest rates.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          ...schedules.map((s) => _buildScheduleCard(s, isDark)),
          if (widget.homeLoanHistory.isNotEmpty ||
              widget.homeLoanConfig != null)
            _buildHomeLoanScheduleCard(isDark),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(LoanRepaymentSchedule schedule, bool isDark) {
    final matchedLoan = widget.loans.cast<Loan?>().firstWhere(
      (l) =>
          l != null &&
          (l.name.toLowerCase().contains(schedule.agreementNo.toLowerCase()) ||
              schedule.loanName.toLowerCase().contains(l.name.toLowerCase())),
      orElse: () => null,
    );

    final paidMonths = matchedLoan?.paidMonths ?? 0;
    final remainingPrincipal = schedule.getRemainingPrincipal(paidMonths);
    final paidPrincipal = schedule.getPaidPrincipal(paidMonths);
    final paidInterest = schedule.getPaidInterest(paidMonths);
    final progress = schedule.tenureMonths > 0
        ? (paidMonths / schedule.tenureMonths).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainer
            : AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
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
                      schedule.loanName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Rate: ${schedule.interestRate}% p.a. • Customer: ${schedule.customer}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(schedule.monthlyEmi),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Text('Monthly EMI', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Remaining Principal',
                  value: _currencyFormat.format(remainingPrincipal),
                  color: AppTheme.primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Paid Principal',
                  value: _currencyFormat.format(paidPrincipal),
                  color: Colors.green.shade700,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Paid Interest',
                  value: _currencyFormat.format(paidInterest),
                  color: Colors.orange.shade800,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Installments: $paidMonths / ${schedule.tenureMonths} Months',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}% Paid',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showScheduleModal(schedule, paidMonths),
              icon: const Icon(Icons.table_chart_outlined, size: 16),
              label: const Text('View Repayment Schedule'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeLoanScheduleCard(bool isDark) {
    final cfg = widget.homeLoanConfig;
    final history = widget.homeLoanHistory;

    final principal =
        cfg?.principalAmount ??
        (history.isNotEmpty ? history.first.balance : 0.0);
    final balance =
        cfg?.balanceRemaining ??
        (history.isNotEmpty ? history.last.balance : 0.0);
    final emi = cfg?.monthlyEMI ?? 12000.0;
    final rate = cfg?.interestRate ?? 8.5;

    final paidPrincipal = (principal - balance).clamp(0.0, principal);
    final paidInterest = history.fold(0.0, (sum, item) => sum + item.interest);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainer
            : AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Family Home Loan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Rate: $rate% p.a. • Reducing Balance',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(emi),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Text('Monthly EMI', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Remaining Balance',
                  value: _currencyFormat.format(balance),
                  color: AppTheme.primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Paid Principal',
                  value: _currencyFormat.format(paidPrincipal),
                  color: Colors.green.shade700,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Paid Interest',
                  value: _currencyFormat.format(paidInterest),
                  color: Colors.orange.shade800,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceContainerLowest : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white60 : Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
