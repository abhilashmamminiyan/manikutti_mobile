import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'add_transaction_screen.dart';

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

  List<dynamic> _monthlyExpenses = [];
  List<dynamic> _notifications = [];
  double _totalRegularExpenses = 0;
  String? _familyCode;
  String? _userEmail;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkFamilyMembership();
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
            return AlertDialog(
              title: const Text('Join Family Sanctuary', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Enter the invitation code sent to your email by your admin to join your family ledger:'),
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
                    Text(error, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
                  onPressed: loading ? null : () async {
                    final token = tokenController.text.trim();
                    if (token.isEmpty) return;
                    setState(() {
                      loading = true;
                      error = '';
                    });
                    try {
                      final success = await ApiService.instance.acceptInvitation(token);
                      if (success) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Successfully joined family group!')),
                          );
                          _loadData();
                        }
                      } else {
                        setState(() => error = 'Failed to join. Invalid or expired token.');
                      }
                    } catch (e) {
                      setState(() => error = e.toString().replaceAll('Exception: ', ''));
                    } finally {
                      setState(() => loading = false);
                    }
                  },
                  child: loading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
      _calculateTotals(list);
      
      setState(() {
        _transactions = list;
      });

      await _fetchFamilyDuesAndNotifications();
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
        
        final expenses = await ApiService.instance.fetchMonthlyExpenses(_familyCode!);
        final notifs = await ApiService.instance.fetchNotifications(_familyCode!);
        
        double regularSum = 0;
        for (final item in expenses) {
          regularSum += (item['amount'] as num).toDouble();
        }
        
        setState(() {
          _monthlyExpenses = expenses;
          _notifications = notifs;
          _totalRegularExpenses = regularSum;
        });

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
      
      final isAssignedToMe = assignedTo?.toLowerCase() == _userEmail?.toLowerCase();
      
      bool isPaidThisMonth = false;
      if (lastPaidDateStr != null && lastPaidDateStr.isNotEmpty) {
        try {
          final lastPaid = DateTime.parse(lastPaidDateStr);
          isPaidThisMonth = lastPaid.month == today.month && lastPaid.year == today.year;
        } catch (_) {}
      }

      if (isAssignedToMe && !isPaidThisMonth && item['status'] != 'Paid') {
        await NotificationService.instance.scheduleMonthlyReminder(
          id: id,
          title: 'Payment Due: $title',
          body: 'Your commitment for $title (₹${amount.toStringAsFixed(0)}) is due today.',
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
      final success = await ApiService.instance.markMonthlyExpensePaid(id, paidDate);
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
      final isAssignedToMe = assignedTo?.toLowerCase() == _userEmail?.toLowerCase();
      final lastPaidDateStr = item['lastPaidDate'] as String?;
      bool isPaidThisMonth = false;
      if (lastPaidDateStr != null && lastPaidDateStr.isNotEmpty) {
        try {
          final lastPaid = DateTime.parse(lastPaidDateStr);
          isPaidThisMonth = lastPaid.month == today.month && lastPaid.year == today.year;
        } catch (_) {}
      }
      return isAssignedToMe && !isPaidThisMonth && item['status'] != 'Paid';
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
            return Container(
              padding: const EdgeInsets.all(24),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Family Activity Feed',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Manrope'),
                          ),
                          Text(
                            'Real-time prosperity logs',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                                ),
                                title: Text(
                                  notif['message'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: Text(
                                  timeAgo,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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

  Widget _buildPersonalCard(ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.primaryColor, theme.primaryColor.withBlue(150)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Savings (Personal)',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Icon(Icons.savings_outlined, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₹${(_totalIncome - _totalPersonalExpenses).toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Personal Income', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text('₹${_totalIncome.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Personal Spend', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text('₹${_totalPersonalExpenses.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCard(ThemeData theme, bool isDark) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Family Prosperity Ledger',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Icon(Icons.people_alt_outlined, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₹${(_totalFamilyExpenses + _totalRegularExpenses).toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Family Pool Expenses', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text('₹${_totalFamilyExpenses.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Regular Commitments', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text('₹${_totalRegularExpenses.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _calculateTotals(List<TransactionModel> list) {
    double income = 0;
    double personalEx = 0;
    double familyEx = 0;

    for (final t in list) {
      if (t.type == 'Income') {
        income += t.amount;
      } else if (t.type == 'Expense') {
        personalEx += t.amount;
      } else if (t.type == 'Family') {
        familyEx += t.amount;
      }
    }

    setState(() {
      _totalIncome = income;
      _totalPersonalExpenses = personalEx;
      _totalFamilyExpenses = familyEx;
    });
  }

  Future<void> _triggerSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing changes with Google Sheets...'), duration: Duration(seconds: 1)),
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

  List<TransactionModel> get _filteredTransactions {
    if (_filter == 'All') return _transactions;
    if (_filter == 'Personal') {
      return _transactions.where((t) => t.type == 'Expense' || t.type == 'Income').toList();
    }
    return _transactions.where((t) => t.type == 'Family').toList();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manikutti Dashboard'),
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
            icon: const Icon(Icons.sync),
            onPressed: _triggerSync,
            tooltip: 'Sync with Sheets',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
          if (result == true) {
            _loadData();
            // Try to sync in background
            _triggerSync();
          }
        },
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: RefreshIndicator(
        onRefresh: _triggerSync,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                      color: _currentPage == index ? theme.primaryColor : Colors.grey[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              // Regular Commitments Section
              if (_monthlyExpenses.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Regular Commitments',
                  style: TextStyle(
                    fontFamily: 'Manrope',
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
                    final status = item['status'] as String;
                    final assignedTo = item['assignedTo'] as String?;
                    final lastPaidDateStr = item['lastPaidDate'] as String?;
                    
                    final isAssignedToMe = assignedTo?.toLowerCase() == _userEmail?.toLowerCase();
                    
                    final today = DateTime.now();
                    bool isPaidThisMonth = false;
                    if (lastPaidDateStr != null && lastPaidDateStr.isNotEmpty) {
                      try {
                        final lastPaid = DateTime.parse(lastPaidDateStr);
                        isPaidThisMonth = lastPaid.month == today.month && lastPaid.year == today.year;
                      } catch (_) {}
                    }
                    
                    final paid = isPaidThisMonth || status == 'Paid';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isAssignedToMe ? theme.primaryColor : Colors.grey).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.account_balance_outlined,
                                color: isAssignedToMe ? theme.primaryColor : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Due Day: $dueDay • ${isAssignedToMe ? "Assigned to You" : "Assigned to ${assignedTo?.split('@')[0] ?? 'Family'}"}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${amount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                if (paid)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'PAID',
                                      style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else if (isAssignedToMe)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _markPaid(item['id'] as int),
                                    child: const Text('Pay', style: TextStyle(fontSize: 11)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'UNPAID',
                                      style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),
              
              // Filter Chips
              Row(
                children: ['All', 'Personal', 'Family'].map((name) {
                  final isSelected = _filter == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _filter = name),
                      selectedColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              // Recent Transactions Headline
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transactions Log',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                ],
              ),
              const SizedBox(height: 12),
              
              // Transactions List
              _filteredTransactions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions recorded locally yet.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final t = _filteredTransactions[index];
                        final formattedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(t.date));
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(t.type).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getCategoryIcon(t.category),
                                color: _getCategoryColor(t.type),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.note.isNotEmpty ? t.note : t.category,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Text(
                                  '${t.type == 'Income' ? '+' : '-'}₹${t.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: t.type == 'Income' ? Colors.green : (t.type == 'Family' ? Colors.blue : Colors.red),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$formattedDate • ${t.type}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                  Row(
                                    children: [
                                      if (t.type == 'Family' && t.addedBy != null) ...[
                                        Text(
                                          'By: ${t.addedBy!.split('@').first} ',
                                          style: TextStyle(color: Colors.grey[500], fontSize: 10, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                      Icon(
                                        t.synced ? Icons.cloud_done : Icons.cloud_off,
                                        size: 14,
                                        color: t.synced ? Colors.green : Colors.amber,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
  }
}

