import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/home_loan_model.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';
import '../widgets/family_pool_transfers_card.dart';
import 'payee_rules_screen.dart';
import 'screenshots_screen.dart';
import 'settings_screen.dart';

class SimpleFamilyHomeScreen extends StatelessWidget {
  final String displayName;
  final String userEmail;
  final String? familyCode;
  final List<dynamic> monthlyExpenses;
  final List<dynamic> familyMembers;
  final List<dynamic> familyTransfers;
  final List<HomeLoanEntry> homeLoanHistory;
  final List<TransactionModel> transactions;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int id) onMarkDuePaid;
  final VoidCallback onRecordTransfer;
  final Function(int id)? onDeleteTransfer;
  final VoidCallback onLogout;

  const SimpleFamilyHomeScreen({
    super.key,
    required this.displayName,
    required this.userEmail,
    required this.familyCode,
    required this.monthlyExpenses,
    required this.familyMembers,
    required this.familyTransfers,
    required this.homeLoanHistory,
    required this.transactions,
    required this.isLoading,
    required this.onRefresh,
    required this.onMarkDuePaid,
    required this.onRecordTransfer,
    this.onDeleteTransfer,
    required this.onLogout,
  });

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  bool _isPaidThisMonth(dynamic item) {
    final lastPaidDateStr = (item['lastPaidDate'] ?? '').toString();
    if (lastPaidDateStr.isEmpty) return false;
    final parsed = DateTime.tryParse(lastPaidDateStr)?.toLocal();
    if (parsed == null) return false;
    final now = DateTime.now();
    return parsed.month == now.month && parsed.year == now.year;
  }

  bool _isAssignedToMe(dynamic item) {
    final assigned = (item['assignedTo'] ?? 'Family')
        .toString()
        .trim()
        .toLowerCase();
    if (assigned == 'family' || assigned.isEmpty) return true;
    final emailLow = userEmail.trim().toLowerCase();
    final nameLow = displayName.trim().toLowerCase();
    return assigned == emailLow ||
        assigned == nameLow ||
        (emailLow.isNotEmpty && assigned == emailLow.split('@').first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final todayDay = DateTime.now().day;

    final myDues = monthlyExpenses.where(_isAssignedToMe).toList();
    final otherDues = monthlyExpenses
        .where((d) => !_isAssignedToMe(d))
        .toList();

    final dueReminders = myDues.where((item) {
      if (_isPaidThisMonth(item)) return false;
      final dueDay = (item['dueDay'] as num?)?.toInt() ?? 1;
      return dueDay <= todayDay + 3;
    }).toList();

    final familyHistory = transactions.where((t) => t.type == 'Family').toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final latestHomeLoanBal = homeLoanHistory.isNotEmpty
        ? homeLoanHistory.last.balance
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, $displayName',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (familyCode != null && familyCode!.isNotEmpty)
              Text(
                'Family Pool • $familyCode',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Payee Rules',
            icon: const Icon(Icons.rule_folder_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PayeeRulesScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: onLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Quick 1-Tap Actions for Mom & Ajesh
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScreenshotsScreen(),
                        ),
                      ).then((_) => onRefresh());
                    },
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Log Screenshot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRecordTransfer,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Pay to Member'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reminder Banner: "Have you paid the loan?"
            if (dueReminders.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFFE65100),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Have you paid your loan?',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFFBF360C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...dueReminders.map((item) {
                      final id = item['id'] as int;
                      final title = (item['title'] ?? '').toString();
                      final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$title • ${_currency.format(amt)} (Day ${item['dueDay']})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => onMarkDuePaid(id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Mark Paid'),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Assigned Loans & Monthly EMIs Card
            _buildDueGroupCard(
              context: context,
              title: 'My Assigned Loans & EMIs',
              subtitle: 'Tap Paid to log as paid by $displayName today',
              items: myDues,
              isDark: isDark,
              allowMarkPaid: true,
            ),

            if (otherDues.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildDueGroupCard(
                context: context,
                title: 'Other Family EMIs',
                subtitle: 'Status across all household loans',
                items: otherDues,
                isDark: isDark,
                allowMarkPaid: false,
              ),
            ],

            if (homeLoanHistory.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.heroCardGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Home Loan Remaining Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currency.format(latestHomeLoanBal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
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
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${homeLoanHistory.length} EMIs logged',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Family Pool & Inter-Payments (Ajesh -> Nisha, Abhilash -> Nisha)
            FamilyPoolTransfersCard(
              familyMembers: familyMembers,
              monthlyExpenses: monthlyExpenses,
              transfers: familyTransfers,
              onRecordTransfer: onRecordTransfer,
              onDeleteTransfer: onDeleteTransfer,
            ),

            const SizedBox(height: 16),

            // Shared Family Payment History
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceContainerLowest
                    : AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C3233)
                      : AppTheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Family Payment History',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (familyHistory.isEmpty)
                    const Text(
                      'No shared family payments logged yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    )
                  else
                    ...familyHistory.take(15).map((tx) {
                      final dt = DateTime.tryParse(tx.date)?.toLocal();
                      final dateText = dt != null
                          ? DateFormat('MMM d, y').format(dt)
                          : '';
                      final by = (tx.addedBy ?? '').split('@').first;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: const Icon(
                            Icons.receipt_outlined,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                        title: Text(
                          tx.note.isNotEmpty ? tx.note : tx.category,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${tx.category} • $dateText${by.isNotEmpty ? ' • By $by' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          _currency.format(tx.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueGroupCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<dynamic> items,
    required bool isDark,
    required bool allowMarkPaid,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              'No loans assigned yet.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          else
            ...items.map((item) {
              final id = item['id'] as int;
              final itemTitle = (item['title'] ?? '').toString();
              final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
              final dueDay = (item['dueDay'] as num?)?.toInt() ?? 1;
              final paid = _isPaidThisMonth(item);
              final paidBy = (item['lastPaidBy'] ?? '').toString();
              final paidDate = DateTime.tryParse(
                (item['lastPaidDate'] ?? '').toString(),
              )?.toLocal();
              final totalMonths = (item['totalMonths'] as num?)?.toInt() ?? 0;
              final paidMonths = (item['paidMonths'] as num?)?.toInt() ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              '${_currency.format(amt)} • Day $dueDay',
                              if (totalMonths > 0)
                                '$paidMonths/$totalMonths mos (${(totalMonths - paidMonths).clamp(0, totalMonths)} left)',
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey,
                            ),
                          ),
                          if (paid && paidBy.isNotEmpty)
                            Text(
                              'Paid by $paidBy${paidDate != null ? ' on ${DateFormat('MMM d').format(paidDate)}' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (paid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Paid',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else if (allowMarkPaid)
                      ElevatedButton(
                        onPressed: isLoading ? null : () => onMarkDuePaid(id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Paid',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFE65100,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Unpaid',
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
