import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../models/loan_model.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import '../services/bank_balance_service.dart';
import '../services/feature_flag_service.dart';
import 'login_screen.dart';
import 'add_transaction_screen.dart';
import 'bills_dashboard.dart';
import 'loans_emi_screen.dart';
import 'home_loan_screen.dart';
import 'mobile_recharges_screen.dart';
import 'screenshots_screen.dart';
import 'transactions_log_screen.dart';
import 'bank_statement_screen.dart';
import '../widgets/app_drawer.dart';
import '../widgets/ai_advisor_card.dart';
import '../widgets/voice_logging_sheet.dart';
import '../widgets/expense_pie_chart.dart';
import '../widgets/family_loan_emi_card.dart';
import '../widgets/family_pool_transfers_card.dart';
import '../widgets/monthly_dues_section.dart';
import '../widgets/dashboard_budget_progress.dart';
import 'simple_family_home_screen.dart';
import 'demo_role_home_screen.dart';
import '../models/emi_model.dart';
import '../models/home_loan_model.dart';
import '../services/widget_data_service.dart';
import '../services/sms_detection_service.dart';
import '../services/emi_reminder_service.dart';
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
  List<dynamic> _familyTransfers = [];
  List<Loan> _loans = [];
  List<EmiBill> _emiList = [];
  List<HomeLoanEntry> _homeLoanHistory = [];
  HomeLoanConfig? _homeLoanConfig;
  List<PendingSmsTransaction> _pendingSmsList = [];
  List<MandatoryEmiCheckItem> _mandatoryEmiChecks = [];
  String _memberNickname = '';
  double _constantEmiDues = 0;
  double _familySalaryIncome = 0;
  double _familyBaseSalary = 0;
  double _myBaseSalary = 0;
  double _myCurrentSalary = 0;
  bool _isSalaryPromptVisible = false;
  double _totalPaidRegularExpenses = 0;
  String? _familyCode;
  String? _userEmail;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    NotificationService.onNotificationPayload.addListener(
      _handleNotificationPayload,
    );
    _loadData();
    _checkFamilyMembership();
    _initPackageInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermission();
    });
  }

  @override
  void dispose() {
    NotificationService.onNotificationPayload.removeListener(
      _handleNotificationPayload,
    );
    _pageController.dispose();
    super.dispose();
  }

  void _handleNotificationPayload() {
    final payload = NotificationService.onNotificationPayload.value;
    if (payload == 'salary_prompt') {
      if (mounted) {
        setState(() {
          _isSalaryPromptVisible = true;
        });
      }
    } else if (payload != null &&
        (payload.startsWith('sms_pending') ||
            payload.startsWith('emi_mandatory'))) {
      _loadData();
    }
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
      await BankBalanceService.instance.init();
      final list = await DbHelper.instance.getAllTransactions();
      setState(() {
        _transactions = list;
      });
      _recalculateFamilyTotals();

      await _fetchFamilyDuesAndNotifications();
      final pendingSms = await SmsDetectionService.instance.getPendingSms();
      if (mounted) {
        setState(() {
          _pendingSmsList = pendingSms;
        });
      }
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
        final membersList = familyInfo['members'] as List<dynamic>? ?? [];

        List<dynamic> expenses = _monthlyExpenses;
        try {
          expenses = await ApiService.instance.fetchMonthlyExpenses(
            _familyCode!,
          );
        } catch (e) {
          debugPrint('Error fetching monthly expenses in dashboard: $e');
        }

        List<dynamic> notifs = _notifications;
        try {
          notifs = await ApiService.instance.fetchNotifications(_familyCode!);
        } catch (e) {
          debugPrint('Error fetching notifications in dashboard: $e');
        }

        List<Loan> fetchedLoans = [];
        HomeLoanConfig? fetchedHomeLoanConfig;
        List<EmiMonthlyTracking> fetchedTracking = [];
        try {
          final monthKey = EmiReminderService.instance.currentMonthKey();
          final loansData = await ApiService.instance.fetchLoansData(
            _familyCode!,
            monthKey: monthKey,
          );
          final rawLoans = (loansData['loans'] as List?) ?? [];
          fetchedLoans = rawLoans.map((l) => Loan.fromJson(l)).toList();
          if (loansData['homeLoanConfig'] is Map) {
            fetchedHomeLoanConfig = HomeLoanConfig.fromJson(
              Map<String, dynamic>.from(loansData['homeLoanConfig'] as Map),
            );
          }
          final rawTracking = (loansData['monthlyTracking'] as List?) ?? [];
          fetchedTracking = rawTracking
              .whereType<Map>()
              .map(
                (t) =>
                    EmiMonthlyTracking.fromJson(Map<String, dynamic>.from(t)),
              )
              .toList();
        } catch (e) {
          debugPrint('Error fetching loans in dashboard: $e');
        }

        List<EmiBill> fetchedEmis = [];
        try {
          final emiRaw = await ApiService.instance.fetchEmiBills(_familyCode!);
          fetchedEmis = emiRaw.map((item) => EmiBill.fromJson(item)).toList();
        } catch (e) {
          debugPrint('Error fetching EMIs in dashboard: $e');
        }

        List<HomeLoanEntry> fetchedHomeLoan = [];
        try {
          final rawHomeLoan = await ApiService.instance.fetchHomeLoanHistory(
            _familyCode!,
          );
          final list = rawHomeLoan
              .map((e) => HomeLoanEntry.fromJson(e))
              .toList();
          list.sort((a, b) {
            final da =
                DateTime.tryParse(a.date) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final db =
                DateTime.tryParse(b.date) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return da.compareTo(db);
          });
          fetchedHomeLoan = list;
        } catch (e) {
          debugPrint('Error fetching home loan history: $e');
        }

        List<dynamic> fetchedTransfers = [];
        try {
          fetchedTransfers = await ApiService.instance.fetchFamilyTransfers(
            _familyCode!,
          );
        } catch (e) {
          debugPrint('Error fetching family transfers: $e');
        }

        final myNick =
            await ApiService.instance.getMemberNickname() ??
            _userEmail?.split('@').first ??
            '';
        for (final m in membersList) {
          if ((m['email'] ?? '').toString().trim().toLowerCase() ==
              (_userEmail ?? '').trim().toLowerCase()) {
            final n = (m['nickname'] ?? '').toString().trim();
            if (n.isNotEmpty) {
              await ApiService.instance.saveMemberNickname(n);
            }
            break;
          }
        }
        final resolvedNick =
            await ApiService.instance.getMemberNickname() ?? myNick;

        final emiAmounts = <double>[
          if (fetchedHomeLoanConfig != null &&
              fetchedHomeLoanConfig.monthlyEMI > 0)
            fetchedHomeLoanConfig.monthlyEMI,
          ...fetchedLoans
              .where(
                (l) => l.status.toLowerCase() == 'active' && l.monthlyEMI > 0,
              )
              .map((l) => l.monthlyEMI),
          ...fetchedEmis
              .where((e) => !e.isCompleted && e.monthlyPayment > 0)
              .map((e) => e.monthlyPayment),
        ];
        await SmsDetectionService.instance.syncConfiguredEmiAmounts(emiAmounts);
        final scannedCount = await SmsDetectionService.instance.scanRecentSms(
          hours: 48,
        );
        if (scannedCount > 0) {
          final refreshedList = await DbHelper.instance.getAllTransactions();
          if (mounted) {
            setState(() => _transactions = refreshedList);
          }
        }
        final pendingSms = await SmsDetectionService.instance.getPendingSms();
        final mandatoryChecks = await EmiReminderService.instance
            .evaluateMonthlyChecks(
              familyCode: _familyCode!,
              userEmail: _userEmail ?? '',
              loans: fetchedLoans,
              homeLoanConfig: fetchedHomeLoanConfig,
              trackingList: fetchedTracking,
            );

        if (mounted) {
          setState(() {
            _monthlyExpenses = expenses;
            _notifications = notifs;
            _familyMembers = membersList;
            _familyTransfers = fetchedTransfers;
            _memberNickname = resolvedNick;
            _loans = fetchedLoans;
            _emiList = fetchedEmis;
            _homeLoanHistory = fetchedHomeLoan;
            _homeLoanConfig = fetchedHomeLoanConfig;
            _pendingSmsList = pendingSms;
            _mandatoryEmiChecks = mandatoryChecks;
          });
        }
        _recalculateFamilyTotals();
        await _syncLocalNotifications(expenses);
        NotificationService.instance.syncFcmTokenWithServer();
      }
    } catch (e) {
      debugPrint('Error fetching family dues/notifications: $e');
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

      final assignedLow = (assignedTo ?? '').trim().toLowerCase();
      final emailLow = (_userEmail ?? '').trim().toLowerCase();
      final nickLow = _memberNickname.trim().toLowerCase();
      final isAssignedToMe =
          assignedLow == 'family' ||
          (emailLow.isNotEmpty && assignedLow == emailLow) ||
          (nickLow.isNotEmpty && assignedLow == nickLow) ||
          (emailLow.isNotEmpty && assignedLow == emailLow.split('@').first);

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
          title: 'Have you paid $title?',
          body:
              'Reminder: $title (₹${amount.toStringAsFixed(0)}) is due on Day $dueDay. Tap to mark paid.',
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
        logToFamily: true,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment registered successfully!')),
        );
        await _triggerSync();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update payment status.')),
        );
      }
    } catch (e) {
      print('Error marking paid: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteTransfer(int id) async {
    final ok = await ApiService.instance.deleteFamilyTransfer(id);
    if (ok) {
      await _fetchFamilyDuesAndNotifications();
    }
  }

  Future<void> _showRecordTransferDialog() async {
    if (_familyCode == null || _familyCode!.isEmpty) return;
    final memberNames = _familyMembers
        .map((m) {
          final nick = (m['nickname'] ?? '').toString().trim();
          if (nick.isNotEmpty) return nick;
          return (m['email'] ?? '').toString().split('@').first;
        })
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final defaultFrom = _memberNickname.isNotEmpty
        ? _memberNickname
        : (memberNames.isNotEmpty ? memberNames.first : 'Me');
    if (!memberNames.contains(defaultFrom)) memberNames.insert(0, defaultFrom);
    if (!memberNames.contains('Nisha')) memberNames.add('Nisha');

    String fromMember = defaultFrom;
    String toMember = memberNames.firstWhere(
      (n) => n.toLowerCase() != fromMember.toLowerCase(),
      orElse: () => 'Nisha',
    );
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Record Family Pool Transfer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: fromMember,
                  decoration: const InputDecoration(labelText: 'From Member'),
                  items: memberNames
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => fromMember = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: toMember,
                  decoration: const InputDecoration(labelText: 'To Member'),
                  items: memberNames
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => toMember = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    hintText: 'e.g. 3750 or 12500',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Home loan pool share',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(modalCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                      if (amt <= 0) return;
                      setModalState(() => submitting = true);
                      final ok = await ApiService.instance.createFamilyTransfer(
                        fromMember: fromMember,
                        toMember: toMember,
                        amount: amt,
                        note: noteCtrl.text.trim(),
                        familyCode: _familyCode!,
                      );
                      if (modalCtx.mounted) Navigator.pop(modalCtx);
                      if (ok) {
                        await _fetchFamilyDuesAndNotifications();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Logged $fromMember → $toMember (₹${amt.toStringAsFixed(0)})',
                              ),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Transfer'),
            ),
          ],
        ),
      ),
    );
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
      }
      final nextDueDateStr = DateFormat('yyyy-MM-dd').format(nextDate);

      final success = await ApiService.instance.updateEmiBillStatus(
        id: emi.id!,
        status: newStatus,
        dueDate: nextDueDateStr,
        paidMonths: newPaidMonths,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Installment #$newPaidMonths for "${emi.title}" recorded as paid!',
              ),
            ),
          );
        }
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update EMI status: $e')),
        );
      }
    }
  }

  void _showAddMonthlyDuesDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController(text: '5');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final theme = Theme.of(modalCtx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Monthly Dues',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Bill / Loan Title',
                        hintText: 'e.g. Home loan, Bajaj Loan, Wi-Fi',
                        prefixIcon: Icon(Icons.receipt_long_rounded),
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
                              labelText: 'Amount (₹)',
                              prefixIcon: Icon(Icons.currency_rupee_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Due Day (1-31)',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005953),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              final amt =
                                  double.tryParse(
                                    amountController.text.trim(),
                                  ) ??
                                  0.0;
                              final day =
                                  int.tryParse(dayController.text.trim()) ?? 5;
                              if (title.isEmpty || amt <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter valid title and amount',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              try {
                                final res = await ApiService.instance
                                    .addMonthlyExpense(
                                      familyCode: _familyCode ?? '',
                                      title: title,
                                      amount: amt,
                                      dueDay: day,
                                      assignedTo: _userEmail ?? '',
                                    );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (res) {
                                  _loadData();
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Commitment',
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

  Future<void> _deleteMonthlyDue(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Commitment?'),
        content: const Text(
          'Are you sure you want to remove this monthly commitment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await ApiService.instance.deleteMonthlyExpense(id);
      if (success) {
        _loadData();
      }
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
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_outlined, size: 20),
                ),
                title: Text(
                  'Settings & Preferences',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
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
    final availableBalance = _sbiBalance + _canaraBalance;
    final netCashflow = _totalIncome - _totalPersonalExpenses;
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
                '₹${availableBalance.toStringAsFixed(2)}',
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
    final verifiedDate = BankBalanceService.instance.getCachedDate(bankValue);

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
                GestureDetector(
                  onTap: () {
                    _showAdjustBankBalanceBottomSheet(
                      bankValue: bankValue,
                      bankName: name,
                      currentBalance: balance,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.tune_rounded, size: 13, color: color),
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
            if (verifiedDate != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 11,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Verified ${DateFormat('dd MMM').format(verifiedDate)}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.green.shade300
                          : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ],
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

  void _showAdjustBankBalanceBottomSheet({
    required String bankValue,
    required String bankName,
    required double currentBalance,
  }) {
    final controller = TextEditingController(
      text: currentBalance.toStringAsFixed(2),
    );
    final verifiedDate = BankBalanceService.instance.getCachedDate(bankValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Verify $bankName Balance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Enter the actual current balance as shown in your $bankName mobile app or netbanking. Subsequent transactions will adjust from this baseline.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.outline,
                  height: 1.4,
                ),
              ),
              if (verifiedDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last verified: ${DateFormat('dd MMM yyyy, hh:mm a').format(verifiedDate)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Current Actual Bank Balance',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final newBal = double.tryParse(controller.text.trim());
                  if (newBal == null) return;
                  await BankBalanceService.instance.setVerifiedBalance(
                    bankValue,
                    newBal,
                    DateTime.now(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _recalculateFamilyTotals();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$bankName balance verified at ₹${newBal.toStringAsFixed(2)}',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Save Verified Balance',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditSalaryDialog({
    bool recordAsIncomeOnSave = false,
  }) async {
    _userEmail ??= await ApiService.instance.getUserEmail();
    if (!mounted) return;

    final effectiveMembers = _familyMembers.isNotEmpty
        ? _familyMembers
        : (_userEmail != null && _userEmail!.isNotEmpty
              ? [
                  {
                    'email': _userEmail,
                    'role': 'Member',
                    'baseSalary': _myBaseSalary,
                    'currentSalary': _myCurrentSalary,
                  },
                ]
              : <dynamic>[]);

    if (effectiveMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No family members found to edit salary.'),
        ),
      );
      return;
    }

    final myMember = effectiveMembers.firstWhere(
      (m) =>
          (m['email'] as String?)?.toLowerCase() == _userEmail?.toLowerCase(),
      orElse: () => effectiveMembers.first,
    );

    final isAdmin = effectiveMembers.any(
      (m) =>
          (m['email'] as String?)?.toLowerCase() == _userEmail?.toLowerCase() &&
          (m['role']?.toString() ?? '') == 'Admin',
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
    bool recordAsIncome = recordAsIncomeOnSave;
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
                    if (isAdmin && _familyMembers.length > 1) ...[
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
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: recordAsIncome,
                      onChanged: (val) {
                        setModalState(() {
                          recordAsIncome = val ?? false;
                        });
                      },
                      title: const Text(
                        'Record as Income in transaction log for this month',
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

                              if (success && recordAsIncome) {
                                await _recordSalaryAsIncome(
                                  amount: amt,
                                  note: 'Monthly Salary Income',
                                );
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final now = DateTime.now();
                                await prefs.setBool(
                                  'salary_confirmed_${now.year}_${now.month}',
                                  true,
                                );
                                await NotificationService.instance
                                    .cancelNotification(9004);
                                await NotificationService.instance
                                    .cancelNotification(9005);
                                await NotificationService.instance
                                    .scheduleSalaryPromptReminders(
                                      isAlreadyConfirmed: true,
                                    );
                                if (mounted) {
                                  setState(() {
                                    _isSalaryPromptVisible = false;
                                  });
                                }
                              }

                              if (mounted) {
                                Navigator.pop(context);
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        recordAsIncome
                                            ? 'Salary income updated and recorded in transaction log!'
                                            : 'Salary income updated successfully!',
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
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

  Future<void> _recordSalaryAsIncome({
    required double amount,
    required String note,
  }) async {
    try {
      final transaction = TransactionModel(
        date: DateTime.now().toUtc().toIso8601String(),
        amount: amount,
        category: 'Salary',
        note: note,
        type: 'Income',
        isPaid: true,
        addedBy: _userEmail ?? '',
        synced: false,
        bankAccount: 'SBI',
      );
      await DbHelper.instance.insertTransaction(transaction);
      SyncService.instance.syncData().ignore();
    } catch (e) {
      debugPrint('[Dashboard] Error recording salary as income: $e');
    }
  }

  Future<void> _handleConfirmSalaryYes() async {
    final amt = _myCurrentSalary > 0 ? _myCurrentSalary : _myBaseSalary;
    if (amt <= 0) {
      _showEditSalaryDialog(recordAsIncomeOnSave: true);
      return;
    }

    await _recordSalaryAsIncome(amount: amt, note: 'Monthly Salary Income');

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setBool('salary_confirmed_${now.year}_${now.month}', true);

    await NotificationService.instance.cancelNotification(9004);
    await NotificationService.instance.cancelNotification(9005);
    await NotificationService.instance.scheduleSalaryPromptReminders(
      isAlreadyConfirmed: true,
    );

    if (mounted) {
      setState(() {
        _isSalaryPromptVisible = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Salary income (₹${amt.toStringAsFixed(0)}) recorded in transaction log!',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      await _loadData();
    }
  }

  Future<void> _handleConfirmSalaryBasic() async {
    final amt = _myBaseSalary > 0 ? _myBaseSalary : _myCurrentSalary;
    if (amt <= 0) {
      _showEditSalaryDialog(recordAsIncomeOnSave: true);
      return;
    }

    if (_userEmail != null && amt != _myCurrentSalary) {
      await ApiService.instance.updateMember(
        targetEmail: _userEmail!,
        currentSalary: amt,
        monthlyIncome: amt,
      );
    }

    await _recordSalaryAsIncome(
      amount: amt,
      note: 'Monthly Salary Income (Base)',
    );

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setBool('salary_confirmed_${now.year}_${now.month}', true);

    await NotificationService.instance.cancelNotification(9004);
    await NotificationService.instance.cancelNotification(9005);
    await NotificationService.instance.scheduleSalaryPromptReminders(
      isAlreadyConfirmed: true,
    );

    if (mounted) {
      setState(() {
        _isSalaryPromptVisible = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Base salary income (₹${amt.toStringAsFixed(0)}) recorded in transaction log!',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      await _loadData();
    }
  }

  Future<void> _checkSalaryPromptStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final confirmed =
        prefs.getBool('salary_confirmed_${now.year}_${now.month}') ?? false;

    final hasSalaryTransaction = _transactions.any((t) {
      if (t.type != 'Income') return false;
      final cat = t.category.toLowerCase();
      final note = t.note.toLowerCase();
      final isSalary = cat.contains('salary') || note.contains('salary');
      if (!isSalary) return false;
      try {
        final dt = DateTime.parse(t.date).toLocal();
        return dt.year == now.year && dt.month == now.month;
      } catch (_) {
        return false;
      }
    });

    if (confirmed || hasSalaryTransaction) {
      if (!confirmed) {
        await prefs.setBool('salary_confirmed_${now.year}_${now.month}', true);
      }
      await NotificationService.instance.cancelNotification(9004);
      await NotificationService.instance.cancelNotification(9005);
      await NotificationService.instance.scheduleSalaryPromptReminders(
        isAlreadyConfirmed: true,
      );
      if (mounted) {
        setState(() {
          _isSalaryPromptVisible = false;
        });
      }
      return;
    }

    await NotificationService.instance.scheduleSalaryPromptReminders(
      isAlreadyConfirmed: false,
    );

    final isSalaryDay = now.day >= 4;
    final isPromptPayload =
        NotificationService.onNotificationPayload.value == 'salary_prompt';

    if (mounted) {
      setState(() {
        _isSalaryPromptVisible = isSalaryDay || isPromptPayload;
      });
    }
  }

  Widget _buildSmsPendingBanner(ThemeData theme, bool isDark) {
    if (_pendingSmsList.isEmpty) return const SizedBox.shrink();
    final sms = _pendingSmsList.first;
    final balText = sms.availableBalance != null
        ? ' • Avl Bal: ₹${sms.availableBalance!.toStringAsFixed(0)}'
        : '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0C4A6E), const Color(0xFF0F172A)]
              : [const Color(0xFFE0F2FE), const Color(0xFFF0F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0EA5E9).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sms_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sms.isEmi
                          ? 'EMI Transaction Detected — Want to log?'
                          : 'Transaction Detected — Want to log?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0C4A6E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${sms.amount.toStringAsFixed(0)} ${sms.type} • ${sms.merchant} (${sms.bankAccount})$balText',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
              ),
              if (_pendingSmsList.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${_pendingSmsList.length - 1} more',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await SmsDetectionService.instance.dismissPendingSms(
                      sms.id,
                    );
                    final updated = await SmsDetectionService.instance
                        .getPendingSms();
                    if (mounted) setState(() => _pendingSmsList = updated);
                  },
                  child: const Text('No, Ignore'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                  ),
                  onPressed: () async {
                    final logged = await SmsDetectionService.instance
                        .confirmPendingSms(sms.id);
                    await _loadData();
                    if (mounted && logged != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Logged ₹${logged.amount.toStringAsFixed(0)} (${logged.merchant}) to Personal sheet',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Yes, Log to Personal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMandatoryEmiBanner(ThemeData theme, bool isDark) {
    final pendingChecks = _mandatoryEmiChecks
        .where((c) => !c.isComplete && c.isResponsibleUser)
        .toList();
    if (pendingChecks.isEmpty) return const SizedBox.shrink();

    final day = DateTime.now().day;
    final headerText = day <= 10
        ? 'Mandatory Before 10th • Monthly EMI Check'
        : 'Overdue Mandatory EMI & Share Check';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF78350F), const Color(0xFF0F172A)]
              : [const Color(0xFFFEF3C7), const Color(0xFFFFFBEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.45),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_repeat_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerText,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      'Confirm EMI payment & share settlement (${pendingChecks.length} pending)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFFB45309),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pendingChecks.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.25)
                    : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(14),
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '₹${item.emiAmount.toStringAsFixed(0)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!item.paidToPayer)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Have you paid the EMI to ${item.payerName}?',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                            ),
                            onPressed: _familyCode == null
                                ? null
                                : () async {
                                    await EmiReminderService.instance
                                        .confirmStatus(
                                          familyCode: _familyCode!,
                                          item: item,
                                          paidToPayer: true,
                                        );
                                    await _loadData();
                                  },
                            child: const Text(
                              'Yes, Paid',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 15,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.autoSmsDetected
                                ? 'EMI to ${item.payerName} auto-logged via SMS'
                                : 'EMI paid to ${item.payerName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!item.sharedWithRecipient)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Have you shared the amount to ${item.shareRecipient}?',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                          ),
                          onPressed: _familyCode == null
                              ? null
                              : () async {
                                  await EmiReminderService.instance
                                      .confirmStatus(
                                        familyCode: _familyCode!,
                                        item: item,
                                        sharedWithRecipient: true,
                                      );
                                  await _loadData();
                                },
                          child: const Text(
                            'Yes, Shared',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSalaryPromptBanner(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final isDay5Followup = now.day == 5;
    final effectiveSalary = _myCurrentSalary > 0
        ? _myCurrentSalary
        : _myBaseSalary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
              : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isDay5Followup
                                ? 'Salary Follow-up: Received Salary?'
                                : 'Have you got your salary?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF065F46),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isSalaryPromptVisible = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: isDark ? Colors.white70 : Colors.black45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDay5Followup
                          ? 'Confirm your salary to record it as income in your transaction log.'
                          : 'Monthly prompt to verify and record this month’s income.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF047857),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.25)
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BASE SALARY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.black54,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '₹${_myBaseSalary.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.1,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'THIS MONTH EXPECTED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white60 : Colors.black54,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '₹${effectiveSalary.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleConfirmSalaryYes,
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: Text(
                  'Yes (₹${effectiveSalary.toStringAsFixed(0)})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.white
                      : const Color(0xFF065F46),
                  side: BorderSide(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleConfirmSalaryBasic,
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                ),
                label: Text(
                  'Basic (₹${_myBaseSalary.toStringAsFixed(0)})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  side: BorderSide(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(
                      0.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    _showEditSalaryDialog(recordAsIncomeOnSave: true),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
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
              if (FeatureFlagService.instance.isEnabled(
                FeatureKeys.salaryTracking,
              ))
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
    double paidRegularSum = 0;
    final today = DateTime.now();
    for (final item in _monthlyExpenses) {
      final amt = (item['amount'] as num).toDouble();
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

        if (t.isTransfer) {
          // Self-transfers are contra transactions: neutral to personal income & expense totals
          final isIncoming =
              t.type == 'Income' ||
              t.category.toLowerCase().contains('income') ||
              t.note.toLowerCase().contains('received') ||
              t.note.toLowerCase().contains('from');
          if (isCanara) {
            if (isIncoming) {
              canaraIn += t.amount;
            } else {
              canaraOut += t.amount;
            }
          } else {
            if (isIncoming) {
              sbiIn += t.amount;
            } else {
              sbiOut += t.amount;
            }
          }
        } else if (t.type == 'Income') {
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
      final isEmi =
          title.contains('emi') ||
          title.contains('loan') ||
          linkedLoan.isNotEmpty;
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

    // 6. Find current user's salary info
    double myBase = 0;
    double myCurrent = 0;
    if (_familyMembers.isNotEmpty) {
      final myMember = _familyMembers.firstWhere(
        (m) =>
            (m['email'] as String?)?.toLowerCase() == _userEmail?.toLowerCase(),
        orElse: () => _familyMembers.first,
      );
      myBase =
          (myMember['baseSalary'] as num?)?.toDouble() ??
          (myMember['monthlyIncome'] as num?)?.toDouble() ??
          0.0;
      myCurrent =
          (myMember['currentSalary'] as num?)?.toDouble() ??
          (myMember['monthlyIncome'] as num?)?.toDouble() ??
          myBase;
    }

    // 7. Calculate accurate live bank balances
    final computedSbiBalance = BankBalanceService.instance.calculateBankBalance(
      bank: TransactionModel.bankSbi,
      transactions: _transactions,
    );
    final computedCanaraBalance = BankBalanceService.instance
        .calculateBankBalance(
          bank: TransactionModel.bankCanara,
          transactions: _transactions,
        );

    setState(() {
      _totalIncome = income;
      _totalPersonalExpenses = personalEx;
      _totalFamilyExpenses = familyEx;
      _totalPaidRegularExpenses = paidRegularSum;
      _constantEmiDues = emiDuesTotal;
      _familySalaryIncome = salarySum;
      _familyBaseSalary = baseSalarySum;
      _myBaseSalary = myBase;
      _myCurrentSalary = myCurrent;
      _sbiIncome = sbiIn;
      _sbiExpenses = sbiOut;
      _sbiBalance = computedSbiBalance;
      _canaraIncome = canaraIn;
      _canaraExpenses = canaraOut;
      _canaraBalance = computedCanaraBalance;
    });

    _checkSalaryPromptStatus();
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
    final showFamily = FeatureFlagService.instance.isEnabled(
      FeatureKeys.familyLedger,
    );
    final activeFilter = (!showFamily && _filter == 'Family') ? 'All' : _filter;
    if (activeFilter == 'All') return list;
    if (activeFilter == 'Personal') {
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

  Widget _buildQuickAccessTile({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuickAccessRows({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required AppLocalizations l10n,
    required FeatureFlagService flags,
  }) {
    final tiles = <Widget>[
      if (flags.isEnabled(FeatureKeys.billsUtilities))
        _buildQuickAccessTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.receipt_long_rounded,
          color: AppTheme.primary,
          label: l10n.bills,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillsDashboard()),
          ),
        ),
      if (flags.isEnabled(FeatureKeys.loansEmiLedger))
        _buildQuickAccessTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.account_balance_rounded,
          color: AppTheme.secondary,
          label: l10n.loansAndEmi,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoansEmiScreen()),
          ),
        ),
      if (flags.isEnabled(FeatureKeys.homeLoan))
        _buildQuickAccessTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.home_work_rounded,
          color: AppTheme.primary,
          label: l10n.homeLoan,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HomeLoanScreen()),
          ),
        ),
      if (flags.isEnabled(FeatureKeys.mobileRecharges))
        _buildQuickAccessTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.phone_android_rounded,
          color: Colors.indigo,
          label: l10n.mobileRecharges,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MobileRechargesScreen()),
          ),
        ),
    ];

    if (tiles.isEmpty) return const [];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(
        Row(
          children: [
            tiles[i],
            const SizedBox(width: 12),
            if (i + 1 < tiles.length)
              tiles[i + 1]
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      if (i + 2 < tiles.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    rows.add(const SizedBox(height: 16));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: FeatureFlagService.instance.permissionsNotifier,
      builder: (context, _, _) {
        final flags = FeatureFlagService.instance;
        if (flags.isDemoRole) {
          final display = _memberNickname.isNotEmpty
              ? _memberNickname
              : (_userEmail?.split('@').first ?? 'Family');
          return DemoRoleHomeScreen(
            displayName: display,
            userEmail: _userEmail ?? '',
            familyCode: _familyCode,
            loans: _loans,
            emiBills: _emiList,
            homeLoanConfig: _homeLoanConfig,
            homeLoanHistory: _homeLoanHistory,
            mandatoryEmiChecks: _mandatoryEmiChecks,
            pendingSmsList: _pendingSmsList,
            isLoading: _isLoading,
            onRefresh: _triggerSync,
            onLogout: _handleLogout,
          );
        }

        if (flags.roleName.trim().toLowerCase() == 'basic') {
          final display = _memberNickname.isNotEmpty
              ? _memberNickname
              : (_userEmail?.split('@').first ?? 'Family');
          return SimpleFamilyHomeScreen(
            displayName: display,
            userEmail: _userEmail ?? '',
            familyCode: _familyCode,
            monthlyExpenses: _monthlyExpenses,
            familyMembers: _familyMembers,
            familyTransfers: _familyTransfers,
            homeLoanHistory: _homeLoanHistory,
            transactions: _transactions,
            isLoading: _isLoading,
            onRefresh: _triggerSync,
            onMarkDuePaid: _markPaid,
            onRecordTransfer: _showRecordTransferDialog,
            onDeleteTransfer: _handleDeleteTransfer,
            onLogout: _handleLogout,
          );
        }

        final showFamily = flags.isEnabled(FeatureKeys.familyLedger);
        final ledgerCards = <Widget>[
          _buildPersonalCard(theme),
          if (showFamily) _buildFamilyCard(theme, isDark),
        ];
        final activePage = _currentPage >= ledgerCards.length
            ? 0
            : _currentPage;
        final filterOptions = <String>[
          'All',
          'Personal',
          if (showFamily) 'Family',
        ];
        final effectiveFilter = (!showFamily && _filter == 'Family')
            ? 'All'
            : _filter;

        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Navigation Menu',
              ),
            ),
            title: Text(
              l10n.dashboard,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              if (flags.isEnabled(FeatureKeys.screenshots))
                IconButton(
                  icon: const Icon(
                    Icons.image_search_rounded,
                    color: AppTheme.primary,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScreenshotsScreen(),
                      ),
                    );
                  },
                  tooltip: 'Scan Payment Screenshot',
                ),
              if (flags.isEnabled(FeatureKeys.voiceLogging))
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
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.account_circle_outlined),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.add, size: 28),
          ),
          body: RefreshIndicator(
            onRefresh: _triggerSync,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  if (_pendingSmsList.isNotEmpty) ...[
                    _buildSmsPendingBanner(theme, isDark),
                    const SizedBox(height: 14),
                  ],
                  if (_mandatoryEmiChecks.any(
                    (c) => !c.isComplete && c.isResponsibleUser,
                  )) ...[
                    _buildMandatoryEmiBanner(theme, isDark),
                    const SizedBox(height: 14),
                  ],
                  if (flags.isEnabled(FeatureKeys.salaryTracking) &&
                      _isSalaryPromptVisible) ...[
                    _buildSalaryPromptBanner(theme, isDark),
                    const SizedBox(height: 14),
                  ],
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
                      children: ledgerCards,
                    ),
                  ),
                  if (ledgerCards.length > 1) ...[
                    const SizedBox(height: 12),
                    // Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(ledgerCards.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          width: activePage == index ? 16.0 : 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            color: activePage == index
                                ? theme.primaryColor
                                : Colors.grey[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Bank Accounts Summary Breakdown
                  if (flags.isEnabled(FeatureKeys.bankBalances)) ...[
                    _buildBankAccountsSummaryCard(theme, isDark),
                    const SizedBox(height: 16),
                  ],

                  // Quick Access Hub
                  ..._buildQuickAccessRows(
                    context: context,
                    theme: theme,
                    isDark: isDark,
                    l10n: l10n,
                    flags: flags,
                  ),

                  // 1. Dashboard Budget & Pace Progress Bar
                  if (flags.isEnabled(FeatureKeys.budgetProgress)) ...[
                    DashboardBudgetProgressBar(
                      totalPersonalExpenses: _totalPersonalExpenses,
                      totalPersonalIncome: _totalIncome,
                      baseSalary: _myCurrentSalary > 0
                          ? _myCurrentSalary
                          : _myBaseSalary,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. AI Financial Advisor / Insights Card
                  if (flags.isEnabled(FeatureKeys.aiAdvisor)) ...[
                    const AiAdvisorCard(),
                    const SizedBox(height: 16),
                  ],

                  // 3. Category Spending Donut / Pie Chart
                  if (flags.isEnabled(FeatureKeys.expenseChart)) ...[
                    ExpensePieChart(
                      transactions: _transactions,
                      initialFilter: effectiveFilter,
                      onFilterChanged: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. Monthly Utilities & Dues
                  if (flags.isEnabled(FeatureKeys.monthlyDues)) ...[
                    MonthlyDuesSection(
                      monthlyExpenses: _monthlyExpenses,
                      userEmail: _userEmail,
                      onMarkPaid: _markPaid,
                      onAddMonthlyDues: _showAddMonthlyDuesDialog,
                      onDeleteItem: _deleteMonthlyDue,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. Family Loans & EMI Ledger
                  if (flags.isEnabled(FeatureKeys.homeLoan) ||
                      flags.isEnabled(FeatureKeys.loansEmiLedger)) ...[
                    FamilyLoanEmiSection(
                      emiBills: _emiList,
                      loans: _loans,
                      homeLoanHistory: _homeLoanHistory,
                      homeLoanConfig: _homeLoanConfig,
                      onPayEmi: _handleMarkEmiPaid,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. Family Pool & Inter-Member Transfers Tracker
                  if (showFamily) ...[
                    FamilyPoolTransfersCard(
                      familyMembers: _familyMembers,
                      monthlyExpenses: _monthlyExpenses,
                      transfers: _familyTransfers,
                      onRecordTransfer: _showRecordTransferDialog,
                      onDeleteTransfer: _handleDeleteTransfer,
                    ),
                    const SizedBox(height: 24),
                  ],

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
                      children: filterOptions.map((name) {
                        final isSelected = effectiveFilter == name;
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
        );
      },
    );
  }
}
