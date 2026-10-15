import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../models/loan_model.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'add_transaction_screen.dart';
import 'bills_dashboard.dart';
import 'loans_emi_screen.dart';
import 'home_loan_screen.dart';
import 'mobile_recharges_screen.dart';
import 'transactions_log_screen.dart';
import 'bank_statement_screen.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ai_advisor_card.dart';
import '../widgets/sidebar_pulse_handle.dart';
import '../widgets/voice_logging_sheet.dart';
import '../services/widget_data_service.dart';
import '../services/whats_new_service.dart';
import 'settings_screen.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String _filter = 'All'; // 'All' | 'Personal' | 'Family'

  double _totalIncome = 0;
  double _totalPersonalExpenses = 0;
  double _totalFamilyExpenses = 0;

  // Individual bank balances & monthly totals
  double _sbiIncome = 0;
  double _sbiExpenses = 0;
  double _sbiBalance = 0;
  double _canaraIncome = 0;
  double _canaraExpenses = 0;
  double _canaraBalance = 0;

  List<dynamic> _monthlyExpenses = [];
  List<dynamic> _notifications = [];
  List<dynamic> _familyMembers = [];
  List<Loan> _loans = [];
  double _constantEmiDues = 0;
  double _familySalaryIncome = 0;
  double _familyBaseSalary = 0;
  double _totalPaidRegularExpenses = 0;
  String? _familyCode;
  String? _userEmail;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkFamilyMembership();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${info.version} (Build ${info.buildNumber})';
    });
  }

  Future<void> _checkFamilyMembership() async {
    // Refresh family info in background
    final info = await ApiService.instance.getFamilyInfo();
    if (info == null || info['familyCode'] == null) {
      if (mounted) {
        _showJoinFamilyDialog();
      }
    }
  }

  void _showJoinFamilyDialog() {
    final tokenController = TextEditingController();
    bool loading = false;
    String error = '';

    showDialog(
      context: context,
      barrierDismissible: false, // Must join to use family features
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: Text(
                'Join Family Sanctuary',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter the invitation code sent to your email by your admin to join your family ledger:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tokenController,
                    decoration: const InputDecoration(
                      hintText: 'Paste invitation token here',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    maxLines: 3,
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await _handleLogout();
                  },
                  child: const Text('Logout'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final token = tokenController.text.trim();
                          if (token.isEmpty) return;
                          setState(() {
                            loading = true;
                            error = '';
                          });
                          try {
                            final success = await ApiService.instance
                                .acceptInvitation(token);
                            if (success) {
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Successfully joined family group!',
                                    ),
                                  ),
                                );
                                _loadData();
                              }
                            } else {
                              setState(
                                () => error =
                                    'Failed to join. Invalid or expired token.',
                              );
                            }
                          } catch (e) {
                            setState(
                              () => error = e.toString().replaceAll(
                                'Exception: ',
                                '',
                              ),
                            );
                          } finally {
                            setState(() => loading = false);
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await DbHelper.instance.getAllTransactions();
      setState(() {
        _transactions = list;
      });
      _recalculateFamilyTotals();

      await _fetchFamilyDuesAndNotifications();
      WidgetDataService.updateWidgetData();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFamilyDuesAndNotifications() async {
    try {
      _userEmail = await ApiService.instance.getUserEmail();
      final familyInfo = await ApiService.instance.getFamilyInfo();
      if (familyInfo != null && familyInfo['familyCode'] != null) {
        _familyCode = familyInfo['familyCode'];

        final expenses = await ApiService.instance.fetchMonthlyExpenses(
          _familyCode!,
        );
        final notifs = await ApiService.instance.fetchNotifications(
          _familyCode!,
        );
        final membersList = familyInfo['members'] as List<dynamic>? ?? [];

        List<Loan> fetchedLoans = [];
        try {
          final loansData = await ApiService.instance.fetchLoansData(
            _familyCode!,
          );
          final rawLoans = (loansData['loans'] as List?) ?? [];
          fetchedLoans = rawLoans.map((l) => Loan.fromJson(l)).toList();
        } catch (e) {
          debugPrint('Error fetching loans in dashboard: $e');
        }

        setState(() {
          _monthlyExpenses = expenses;
          _notifications = notifs;
          _familyMembers = membersList;
          _loans = fetchedLoans;
        });

        _recalculateFamilyTotals();
        await _syncLocalNotifications(expenses);
      }
    } catch (e) {
      print('Error fetching family dues/notifications: $e');
    }
  }

  Future<void> _syncLocalNotifications(List<dynamic> expenses) async {
    final today = DateTime.now();
    for (final item in expenses) {
      final id = item['id'] as int;
      final title = item['title'] as String;
      final amount = (item['amount'] as num).toDouble();
      final dueDay = item['dueDay'] as int;
      final assignedTo = item['assignedTo'] as String?;
      final lastPaidDateStr = item['lastPaidDate'] as String?;

      final isAssignedToMe =
          assignedTo?.toLowerCase() == _userEmail?.toLowerCase();

      bool isPaidThisMonth = false;
      if (lastPaidDateStr != null && lastPaidDateStr.isNotEmpty) {
        try {
          final lastPaid = DateTime.parse(lastPaidDateStr);
          isPaidThisMonth =
              lastPaid.month == today.month && lastPaid.year == today.year;
        } catch (_) {}
      }

      if (isAssignedToMe && !isPaidThisMonth) {
        await NotificationService.instance.scheduleMonthlyReminder(
          id: id,
          title: 'Payment Due: $title',
          body:
              'Your commitment for $title (₹${amount.toStringAsFixed(0)}) is due today.',
          dueDay: dueDay,
        );
      } else {
        await NotificationService.instance.cancelNotification(id);
      }
    }
  }

  Future<void> _markPaid(int id) async {
    setState(() => _isLoading = true);
    try {
      final paidDate = DateTime.now().toUtc().toIso8601String();
      final success = await ApiService.instance.markMonthlyExpensePaid(
        id,
        paidDate,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment registered successfully!')),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update payment status.')),
        );
      }
    } catch (e) {
      print('Error marking paid: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool get _hasUnreadNotifications {
    final today = DateTime.now();
    return _monthlyExpenses.any((item) {
      final assignedTo = item['assignedTo'] as String?;
      final isAssignedToMe =
          assignedTo?.toLowerCase() == _userEmail?.toLowerCase();
      final lastPaidDateStr = item['lastPaidDate'] as String?;
      bool isPaidThisMonth = false;
      if (lastPaidDateStr != null && lastPaidDateStr.isNotEmpty) {
        try {
          final lastPaid = DateTime.parse(lastPaidDateStr);
          isPaidThisMonth =
              lastPaid.month == today.month && lastPaid.year == today.year;
        } catch (_) {}
      }
      return isAssignedToMe && !isPaidThisMonth;
    });
  }

  void _showNotificationsFeed() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.all(24),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Family Activity Feed',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              await NotificationService.instance
                                  .showImmediateNotification(
                                    id: 999,
                                    title: 'System Notification Test',
                                    body:
                                        'This is a test notification in your drawer!',
                                  );
                            },
                            child: Text(
                              'Tap here to test drawer notification',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.primaryContainer
                                    : AppTheme.primary,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Expanded(
                    child: _notifications.isEmpty
                        ? const Center(
                            child: Text(
                              'No recent activity recorded.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              final dateStr = notif['date'] as String;
                              String timeAgo = '';
                              try {
                                final date = DateTime.parse(dateStr).toLocal();
                                final diff = DateTime.now().difference(date);
                                if (diff.inMinutes < 60) {
                                  timeAgo = '${diff.inMinutes}m ago';
                                } else if (diff.inHours < 24) {
                                  timeAgo = '${diff.inHours}h ago';
                                } else {
                                  timeAgo = '${diff.inDays}d ago';
                                }
                              } catch (_) {}

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                title: Text(
                                  notif['message'] ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  '$timeAgo${notif['createdBy'] != null ? ' • By ${_getMemberNickname(notif['createdBy'])}' : ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppTheme.darkOnSurfaceVariant
                                        : Colors.grey,
                                  ),
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

  void _showProfileBottomSheet() {
    final myNickname = _getMemberNickname(_userEmail ?? '');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(28),
          height: 320,
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3E484A) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.primary,
                child: Text(
                  myNickname.isNotEmpty ? myNickname[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                myNickname,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userEmail ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppTheme.darkOnSurfaceVariant
                      : Colors.grey[600],
                ),
              ),
              if (_appVersion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'App Version: $_appVersion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkOnSurfaceVariant.withOpacity(0.7)
                        : Colors.grey[500],
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleLogout();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

  Widget _buildPersonalCard(ThemeData theme) {
    final netBalance = _totalIncome - _totalPersonalExpenses;
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroCardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.editorialShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PERSONAL SANCTUARY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'SBI: ₹${_sbiBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Canara: ₹${_canaraBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AVAILABLE BALANCE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${netBalance.toStringAsFixed(2)}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontSize: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        color: AppTheme.secondaryContainer,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Income',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '₹${_totalIncome.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withOpacity(0.15),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Color(0xFFFF8A80),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spent',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '₹${_totalPersonalExpenses.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

  Widget _buildBankAccountsSummaryCard(ThemeData theme, bool isDark) {
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
              : AppTheme.outlineVariant.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    'BANK ACCOUNTS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BankStatementScreen(),
                    ),
                  ).then((_) {
                    _loadData();
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.upload_file_rounded,
                        size: 13,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Upload Statement',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // SBI Account Card
              Expanded(
                child: _buildSingleBankCard(
                  name: 'SBI',
                  balance: _sbiBalance,
                  income: _sbiIncome,
                  expense: _sbiExpenses,
                  color: const Color(0xFF1E88E5),
                  icon: Icons.account_balance_rounded,
                  theme: theme,
                  isDark: isDark,
                  bankValue: TransactionModel.bankSbi,
                ),
              ),
              const SizedBox(width: 12),
              // Canara Bank Card
              Expanded(
                child: _buildSingleBankCard(
                  name: 'Canara Bank',
                  balance: _canaraBalance,
                  income: _canaraIncome,
                  expense: _canaraExpenses,
                  color: const Color(0xFF0284C7),
                  icon: Icons.account_balance_outlined,
                  theme: theme,
                  isDark: isDark,
                  bankValue: TransactionModel.bankCanara,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleBankCard({
    required String name,
    required double balance,
    required double income,
    required double expense,
    required Color color,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
    required String bankValue,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const TransactionsLogScreen(initialFilter: 'Personal'),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(isDark ? 0.35 : 0.22),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₹${balance.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.onSurface,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '+₹${income.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
                Text(
                  ' • ',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.outline.withOpacity(0.5),
                  ),
                ),
                Text(
                  '-₹${expense.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSalaryDialog() {
    if (_familyMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No family members found to edit salary.'),
        ),
      );
      return;
    }

    final myMember = _familyMembers.firstWhere(
      (m) =>
          (m['email'] as String?)?.toLowerCase() == _userEmail?.toLowerCase(),
      orElse: () => _familyMembers.first,
    );

    String selectedEmail = myMember['email'] ?? '';
    double baseSalary =
        (myMember['baseSalary'] as num?)?.toDouble() ??
        (myMember['monthlyIncome'] as num?)?.toDouble() ??
        0.0;
    double currentSalary =
        (myMember['currentSalary'] as num?)?.toDouble() ??
        (myMember['monthlyIncome'] as num?)?.toDouble() ??
        baseSalary;

    final salaryController = TextEditingController(
      text: currentSalary > 0 ? currentSalary.toStringAsFixed(0) : '',
    );
    bool alsoUpdateBase = false;
    bool saving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E282A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Salary Income',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Base salary is your contractual baseline. Adjust your actual income for this month if changed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_familyMembers.length > 1) ...[
                      DropdownButtonFormField<String>(
                        value: selectedEmail,
                        decoration: InputDecoration(
                          labelText: 'Family Member',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _familyMembers.map<DropdownMenuItem<String>>((
                          m,
                        ) {
                          final email = m['email'] as String? ?? '';
                          final nickname =
                              m['nickname'] as String? ??
                              email.split('@').first;
                          return DropdownMenuItem<String>(
                            value: email,
                            child: Text('$nickname ($email)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final found = _familyMembers.firstWhere(
                              (m) => m['email'] == val,
                              orElse: () => _familyMembers.first,
                            );
                            final bSal =
                                (found['baseSalary'] as num?)?.toDouble() ??
                                (found['monthlyIncome'] as num?)?.toDouble() ??
                                0.0;
                            final cSal =
                                (found['currentSalary'] as num?)?.toDouble() ??
                                (found['monthlyIncome'] as num?)?.toDouble() ??
                                bSal;
                            setModalState(() {
                              selectedEmail = val;
                              baseSalary = bSal;
                              currentSalary = cSal;
                              salaryController.text = cSal > 0
                                  ? cSal.toStringAsFixed(0)
                                  : '';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BASE SALARY REFERENCE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${baseSalary.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: salaryController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: "This Month's Salary Income (₹)",
                        hintText: "Enter amount",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: alsoUpdateBase,
                      onChanged: (val) {
                        setModalState(() {
                          alsoUpdateBase = val ?? false;
                        });
                      },
                      title: const Text(
                        'Also update standard Base Salary to this amount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final amt = double.tryParse(
                                salaryController.text.trim(),
                              );
                              if (amt == null || amt < 0) {
                                setModalState(() {
                                  errorText =
                                      'Please enter a valid salary amount';
                                });
                                return;
                              }
                              setModalState(() {
                                saving = true;
                                errorText = null;
                              });

                              final success = await ApiService.instance
                                  .updateMember(
                                    targetEmail: selectedEmail,
                                    currentSalary: amt,
                                    baseSalary: alsoUpdateBase ? amt : null,
                                    monthlyIncome: amt,
                                  );

                              if (mounted) {
                                Navigator.pop(context);
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Salary income updated successfully!',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                  await _loadData();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to update salary income.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Salary Income',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
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

  Widget _buildFamilyCard(ThemeData theme, bool isDark) {
    final totalPoolSpent = _totalFamilyExpenses + _totalPaidRegularExpenses;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E282A), const Color(0xFF131A1B)]
              : [const Color(0xFF1E2A38), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.editorialShadow,
        border: Border.all(
          color: AppTheme.secondaryContainer.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  color: AppTheme.secondaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FAMILY LEDGER POOL',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.secondaryContainer,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _showEditSalaryDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        color: AppTheme.secondaryContainer,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Edit Salary',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL POOL OUTFLOW',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${totalPoolSpent.toStringAsFixed(2)}',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontSize: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _familyBaseSalary > 0 &&
                              _familyBaseSalary != _familySalaryIncome
                          ? 'Salary (Base: ₹${_familyBaseSalary.toStringAsFixed(0)})'
                          : 'Salary',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      '₹${_familySalaryIncome.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withOpacity(0.15),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Constant EMI',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      '₹${_constantEmiDues.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.secondaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withOpacity(0.15),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared Pool',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      '₹${_totalFamilyExpenses.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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

  void _recalculateFamilyTotals() {
    double income = 0;
    double personalEx = 0;
    double familyEx = 0;

    double sbiIn = 0;
    double sbiOut = 0;
    double canaraIn = 0;
    double canaraOut = 0;

    // 1. Calculate regular sums for current month
    double regularSum = 0;
    double paidRegularSum = 0;
    final today = DateTime.now();
    for (final item in _monthlyExpenses) {
      final amt = (item['amount'] as num).toDouble();
      regularSum += amt;
      final lastPaidDateStr = item['lastPaidDate'] as String?;
      bool isPaidThisMonth = false;
      if (lastPaidDateStr != null && lastPaidDateStr.isNotEmpty) {
        try {
          final lastPaid = DateTime.parse(lastPaidDateStr).toLocal();
          isPaidThisMonth =
              lastPaid.month == today.month && lastPaid.year == today.year;
        } catch (_) {}
      }
      if (isPaidThisMonth) {
        paidRegularSum += amt;
      }
    }

    // 2. Helper to check if a transaction represents a regular commitment payment
    bool isRegularCommitmentPayment(TransactionModel t) {
      final noteLower = t.note.toLowerCase().trim();
      if (noteLower.isEmpty) return false;

      for (final item in _monthlyExpenses) {
        final title = (item['title'] as String).toLowerCase().trim();
        final cleanTitle = title.replaceAll('emi:', '').trim();
        final linkedLoan =
            (item['linkedLoan'] as String?)?.toLowerCase().trim() ?? '';

        if (noteLower == title ||
            noteLower == cleanTitle ||
            (linkedLoan.isNotEmpty && noteLower == linkedLoan) ||
            noteLower.contains(cleanTitle) ||
            (linkedLoan.isNotEmpty && noteLower.contains(linkedLoan))) {
          return true;
        }
      }
      return false;
    }

    // 3. Sum up transactions for the current calendar month
    for (final t in _transactions) {
      final tDate = DateTime.tryParse(t.date)?.toLocal();
      if (tDate != null &&
          tDate.year == today.year &&
          tDate.month == today.month) {
        final bank = (t.bankAccount != null && t.bankAccount!.isNotEmpty)
            ? t.bankAccount!
            : TransactionModel.bankSbi;
        final isCanara = bank == TransactionModel.bankCanara;

        if (t.type == 'Income') {
          income += t.amount;
          if (isCanara) {
            canaraIn += t.amount;
          } else {
            sbiIn += t.amount;
          }
        } else if (t.type == 'Expense') {
          personalEx += t.amount;
          if (isCanara) {
            canaraOut += t.amount;
          } else {
            sbiOut += t.amount;
          }
        } else if (t.type == 'Family') {
          if (!isRegularCommitmentPayment(t)) {
            familyEx += t.amount;
          }
          if (isCanara) {
            canaraOut += t.amount;
          } else {
            sbiOut += t.amount;
          }
        }
      }
    }

    // 4. Calculate Constant Family EMI Dues (active loans + standalone EMI commitments)
    double loanEmiSum = _loans
        .where((l) => l.status.toLowerCase() == 'active')
        .fold(0.0, (sum, l) => sum + l.monthlyEMI);

    final loanNames = _loans.map((l) => l.name.toLowerCase()).toSet();
    double standaloneEmiSum = 0;
    for (final item in _monthlyExpenses) {
      final title = (item['title'] as String? ?? '').toLowerCase();
      final cleanTitle = title.replaceAll('emi:', '').trim();
      final linkedLoan = (item['linkedLoan'] as String? ?? '')
          .toLowerCase()
          .trim();
      final isEmi = title.contains('emi') || linkedLoan.isNotEmpty;
      final isCounted =
          loanNames.contains(title) ||
          loanNames.contains(cleanTitle) ||
          (linkedLoan.isNotEmpty && loanNames.contains(linkedLoan));
      if (isEmi && !isCounted) {
        standaloneEmiSum += (item['amount'] as num? ?? 0).toDouble();
      }
    }
    final emiDuesTotal = loanEmiSum + standaloneEmiSum;

    // 5. Calculate Family Salary Income and Base Salary
    double salarySum = 0;
    double baseSalarySum = 0;
    for (final m in _familyMembers) {
      final mIncome =
          (m['currentSalary'] as num?)?.toDouble() ??
          (m['monthlyIncome'] as num?)?.toDouble() ??
          0.0;
      final mBase =
          (m['baseSalary'] as num?)?.toDouble() ??
          (m['monthlyIncome'] as num?)?.toDouble() ??
          mIncome;
      salarySum += mIncome;
      baseSalarySum += mBase;
    }

    setState(() {
      _totalIncome = income;
      _totalPersonalExpenses = personalEx;
      _totalFamilyExpenses = familyEx;
      _totalPaidRegularExpenses = paidRegularSum;
      _constantEmiDues = emiDuesTotal;
      _familySalaryIncome = salarySum;
      _familyBaseSalary = baseSalarySum;
      _sbiIncome = sbiIn;
      _sbiExpenses = sbiOut;
      _sbiBalance = sbiIn - sbiOut;
      _canaraIncome = canaraIn;
      _canaraExpenses = canaraOut;
      _canaraBalance = canaraIn - canaraOut;
    });
  }

  String _getMemberNickname(String email) {
    final emailLower = email.trim().toLowerCase();
    for (final m in _familyMembers) {
      final mEmail = (m['email'] as String?)?.trim().toLowerCase() ?? '';
      if (mEmail == emailLower) {
        final nick = (m['nickname'] as String?)?.trim() ?? '';
        if (nick.isNotEmpty) return nick;
      }
    }
    return email.split('@').first;
  }

  Future<void> _triggerSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Syncing changes with Cloud Vault...'),
        duration: Duration(seconds: 1),
      ),
    );
    await SyncService.instance.syncData();
    await _loadData();
  }

  Future<void> _handleLogout() async {
    await ApiService.instance.clearAuth();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  List<TransactionModel> get _currentMonthTransactions {
    final now = DateTime.now();
    return _transactions.where((t) {
      final d = DateTime.tryParse(t.date)?.toLocal();
      return d != null && d.year == now.year && d.month == now.month;
    }).toList();
  }

  List<TransactionModel> get _filteredTransactions {
    final list = _currentMonthTransactions;
    if (_filter == 'All') return list;
    if (_filter == 'Personal') {
      return list
          .where((t) => t.type == 'Expense' || t.type == 'Income')
          .toList();
    }
    return list.where((t) => t.type == 'Family').toList();
  }

  List<TransactionModel> get _dashboardTransactions {
    return _filteredTransactions.take(5).toList();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'housing':
        return Icons.home;
      case 'transport':
        return Icons.directions_car;
      case 'leisure':
        return Icons.sports_esports;
      case 'health':
        return Icons.medical_services;
      case 'shopping':
        return Icons.shopping_bag;
      case 'investment':
        return Icons.trending_up;
      case 'salary':
        return Icons.payments;
      default:
        return Icons.attach_money;
    }
  }

  Color _getCategoryColor(String type) {
    if (type == 'Income') return Colors.green;
    if (type == 'Family') return Colors.blue;
    return Colors.amber[700]!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) => PulsingArrowButton(
            onTap: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(l10n.dashboard),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _showNotificationsFeed,
                tooltip: 'Activity Logs',
              ),
              if (_hasUnreadNotifications)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: AppTheme.primary),
            onPressed: () {
              VoiceLoggingSheet.show(
                context,
                onExpenseAdded: () {
                  _loadData();
                  _triggerSync();
                },
              );
            },
            tooltip: 'Voice Expense (AI)',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _triggerSync,
            tooltip: 'Sync with Cloud',
          ),
          ValueListenableBuilder<bool>(
            valueListenable: WhatsNewService.instance.hasUnreadNotifier,
            builder: (context, hasUnread, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    tooltip: l10n.settings,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: _showProfileBottomSheet,
            tooltip: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
          if (result == true) {
            _loadData();
            WidgetDataService.updateWidgetData();
            // Try to sync in background
            _triggerSync();
          }
        },
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (ctx) => SidebarIconRail(
              activeRoute: 'dashboard',
              onOpenDrawer: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _triggerSync,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 8.0, right: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  const SizedBox(height: 12),
                  // Swipeable Card PageView
                  SizedBox(
                    height: 200,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      children: [
                        _buildPersonalCard(theme),
                        _buildFamilyCard(theme, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: _currentPage == index ? 16.0 : 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? theme.primaryColor
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Bank Accounts Summary Breakdown
                  _buildBankAccountsSummaryCard(theme, isDark),
                  const SizedBox(height: 16),

                  // Quick Access Hub
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BillsDashboard(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurfaceContainerLowest
                                  : AppTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: AppTheme.ambientCardShadow,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2C3233)
                                    : AppTheme.outlineVariant.withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.bills,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoansEmiScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurfaceContainerLowest
                                  : AppTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: AppTheme.ambientCardShadow,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2C3233)
                                    : AppTheme.outlineVariant.withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_rounded,
                                    size: 18,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.loansAndEmi,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeLoanScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurfaceContainerLowest
                                  : AppTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: AppTheme.ambientCardShadow,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2C3233)
                                    : AppTheme.outlineVariant.withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.home_work_rounded,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.homeLoan,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MobileRechargesScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurfaceContainerLowest
                                  : AppTheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: AppTheme.ambientCardShadow,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2C3233)
                                    : AppTheme.outlineVariant.withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.phone_android_rounded,
                                    size: 18,
                                    color: Colors.indigo,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.mobileRecharges,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const AiAdvisorCard(),
                  // Regular Commitments Section
                  if (_monthlyExpenses.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Regular Commitments',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _monthlyExpenses.length,
                      itemBuilder: (context, index) {
                        final item = _monthlyExpenses[index];
                        final title = item['title'] as String;
                        final amount = (item['amount'] as num).toDouble();
                        final dueDay = item['dueDay'] as int;
                        final assignedTo = item['assignedTo'] as String?;
                        final lastPaidDateStr = item['lastPaidDate'] as String?;
                        final linkedLoan = item['linkedLoan'] as String?;
                        final isEmi =
                            title.toLowerCase().contains('emi') ||
                            (linkedLoan != null &&
                                linkedLoan.trim().isNotEmpty);

                        final isAssignedToMe =
                            assignedTo?.toLowerCase() ==
                            _userEmail?.toLowerCase();

                        final today = DateTime.now();
                        bool isPaidThisMonth = false;
                        if (lastPaidDateStr != null &&
                            lastPaidDateStr.isNotEmpty) {
                          try {
                            final lastPaid = DateTime.parse(lastPaidDateStr);
                            isPaidThisMonth =
                                lastPaid.month == today.month &&
                                lastPaid.year == today.year;
                          } catch (_) {}
                        }

                        final paid = isPaidThisMonth;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceContainerLowest
                                : AppTheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppTheme.ambientCardShadow,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2C3233)
                                  : AppTheme.outlineVariant.withOpacity(0.18),
                            ),
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      (isEmi
                                              ? const Color(0xFFF59E0B)
                                              : AppTheme.secondaryContainer)
                                          .withOpacity(0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isEmi
                                      ? Icons.account_balance_wallet_rounded
                                      : Icons.calendar_today_rounded,
                                  color: isEmi
                                      ? const Color(0xFFF59E0B)
                                      : AppTheme.secondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          title,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? AppTheme.darkOnSurface
                                                    : AppTheme.onSurface,
                                              ),
                                        ),
                                        if (isEmi)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFF59E0B,
                                              ).withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFF59E0B,
                                                ).withOpacity(0.5),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: const Text(
                                              'EMI • FIXED',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFF59E0B),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Due on day $dueDay • ${isAssignedToMe ? "Assigned to You" : "Assigned to ${assignedTo?.split('@')[0] ?? 'Family'}"}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isDark
                                                ? AppTheme.darkOnSurfaceVariant
                                                : AppTheme.onSurfaceVariant
                                                      .withOpacity(0.7),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${amount.toStringAsFixed(0)}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? AppTheme.darkOnSurface
                                              : AppTheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (paid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'PAID',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    )
                                  else if (isAssignedToMe)
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _markPaid(item['id'] as int),
                                        child: const Text(
                                          'Pay',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF584400)
                                            : AppTheme.secondaryContainer
                                                  .withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'PENDING',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFFFE087)
                                              : AppTheme.secondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
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
                  ],
                  const SizedBox(height: 24),

                  // Stitch Editorial Segmented Pill Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceContainer
                          : AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: ['All', 'Personal', 'Family'].map((name) {
                        final isSelected = _filter == name;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                          ? AppTheme.primaryContainer
                                          : AppTheme.primary)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isSelected
                                    ? AppTheme.subtleFloatShadow
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  name,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: isSelected
                                        ? (isDark
                                              ? AppTheme.onPrimaryContainer
                                              : Colors.white)
                                        : (isDark
                                              ? AppTheme.darkOnSurfaceVariant
                                              : AppTheme.onSurfaceVariant),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Transactions Headline
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Transactions Log',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (_isLoading) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransactionsLogScreen(initialFilter: _filter),
                            ),
                          );
                          if (mounted) {
                            _loadData();
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppTheme.primary,
                        ),
                        label: const Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        iconAlignment: IconAlignment.end,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Transactions List (Latest 5 of Current Month)
                  _dashboardTransactions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkSurfaceContainer
                                      : AppTheme.surfaceContainerLow,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 40,
                                  color: AppTheme.outline,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions recorded for ${DateFormat('MMMM').format(DateTime.now())} yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.outline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(
                                    color: AppTheme.primary.withOpacity(0.3),
                                  ),
                                ),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TransactionsLogScreen(
                                        initialFilter: _filter,
                                      ),
                                    ),
                                  );
                                  if (mounted) _loadData();
                                },
                                icon: const Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'View All Past Transactions',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _dashboardTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _dashboardTransactions[index];
                            final formattedDate = DateFormat(
                              'MMM dd, yyyy',
                            ).format(DateTime.parse(t.date));

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkSurfaceContainerLowest
                                    : AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: AppTheme.ambientCardShadow,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF2C3233)
                                      : AppTheme.outlineVariant.withOpacity(
                                          0.18,
                                        ),
                                ),
                              ),
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(
                                        t.type,
                                      ).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(t.category),
                                      color: _getCategoryColor(t.type),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.note.isNotEmpty
                                              ? t.note
                                              : t.category,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? AppTheme.darkOnSurface
                                                    : AppTheme.onSurface,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '$formattedDate • ${t.type}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: isDark
                                                        ? AppTheme
                                                              .darkOnSurfaceVariant
                                                        : AppTheme
                                                              .onSurfaceVariant
                                                              .withOpacity(0.7),
                                                    fontSize: 11,
                                                  ),
                                            ),
                                            if (t.type == 'Family' &&
                                                t.addedBy != null) ...[
                                              Text(
                                                ' • ${_getMemberNickname(t.addedBy!)}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: AppTheme.primary,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${t.type == 'Income' ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: t.type == 'Income'
                                                  ? const Color(0xFF10B981)
                                                  : (t.type == 'Family'
                                                        ? AppTheme.primary
                                                        : AppTheme.error),
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Icon(
                                        t.synced
                                            ? Icons.cloud_done_rounded
                                            : Icons.cloud_off_rounded,
                                        size: 14,
                                        color: t.synced
                                            ? const Color(0xFF10B981)
                                            : AppTheme.secondary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 80), // bottom spacing for FAB
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }
}
