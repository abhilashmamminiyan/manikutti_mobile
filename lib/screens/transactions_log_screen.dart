import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'add_transaction_screen.dart';
import 'bank_statement_screen.dart';

enum DateFilterPreset { allTime, thisMonth, lastMonth, customRange }

enum SortOption { dateDesc, dateAsc, amountDesc, amountAsc }

class TransactionsLogScreen extends StatefulWidget {
  final String initialFilter; // 'All' | 'Personal' | 'Family'

  const TransactionsLogScreen({super.key, this.initialFilter = 'All'});

  @override
  State<TransactionsLogScreen> createState() => _TransactionsLogScreenState();
}

class _TransactionsLogScreenState extends State<TransactionsLogScreen> {
  List<TransactionModel> _allTransactions = [];
  bool _isLoading = true;

  // Filters
  late String _typeFilter; // 'All' | 'Personal' | 'Family'
  DateFilterPreset _dateFilter = DateFilterPreset.thisMonth;
  DateTimeRange? _customDateRange;
  SortOption _sortOption = SortOption.dateDesc;
  String _searchQuery = '';
  String _bankFilter = 'All'; // 'All' | 'SBI' | 'Canara Bank'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialFilter;
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final list = await DbHelper.instance.getAllTransactions();
      if (mounted) {
        setState(() {
          _allTransactions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  Future<void> _syncAndReload() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Syncing changes with Google Sheets...'),
        duration: Duration(seconds: 1),
      ),
    );
    await SyncService.instance.syncData();
    await _loadTransactions();
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

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _customDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _dateFilter = DateFilterPreset.customRange;
      });
    }
  }

  List<TransactionModel> get _filteredTransactions {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    final filtered = _allTransactions.where((t) {
      // 1. Type filter
      if (_typeFilter == 'Personal') {
        if (t.type != 'Expense' && t.type != 'Income') return false;
      } else if (_typeFilter == 'Family') {
        if (t.type != 'Family') return false;
      }

      // 2. Date filter
      final tDate = DateTime.tryParse(t.date)?.toLocal();
      if (tDate != null) {
        switch (_dateFilter) {
          case DateFilterPreset.thisMonth:
            if (tDate.isBefore(thisMonthStart) || tDate.isAfter(thisMonthEnd)) {
              return false;
            }
            break;
          case DateFilterPreset.lastMonth:
            if (tDate.isBefore(lastMonthStart) || tDate.isAfter(lastMonthEnd)) {
              return false;
            }
            break;
          case DateFilterPreset.customRange:
            if (_customDateRange != null) {
              final rangeStart = DateTime(
                _customDateRange!.start.year,
                _customDateRange!.start.month,
                _customDateRange!.start.day,
              );
              final rangeEnd = DateTime(
                _customDateRange!.end.year,
                _customDateRange!.end.month,
                _customDateRange!.end.day,
                23,
                59,
                59,
              );
              if (tDate.isBefore(rangeStart) || tDate.isAfter(rangeEnd)) {
                return false;
              }
            }
            break;
          case DateFilterPreset.allTime:
            // No date restriction
            break;
        }
      }

      // 3. Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final noteMatch = t.note.toLowerCase().contains(q);
        final catMatch = t.category.toLowerCase().contains(q);
        final typeMatch = t.type.toLowerCase().contains(q);
        if (!noteMatch && !catMatch && !typeMatch) return false;
      }

      // 4. Bank account filter
      if (_bankFilter != 'All') {
        final itemBank = (t.bankAccount != null && t.bankAccount!.isNotEmpty)
            ? t.bankAccount!
            : TransactionModel.bankSbi;
        if (itemBank != _bankFilter) return false;
      }

      return true;
    }).toList();

    // 4. Sort / Amount & Date Ordering
    filtered.sort((a, b) {
      switch (_sortOption) {
        case SortOption.amountDesc:
          return b.amount.compareTo(a.amount);
        case SortOption.amountAsc:
          return a.amount.compareTo(b.amount);
        case SortOption.dateAsc:
          return a.date.compareTo(b.date);
        case SortOption.dateDesc:
          return b.date.compareTo(a.date);
      }
    });

    return filtered;
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sort Transactions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.arrow_downward_rounded,
                    color: AppTheme.primary,
                  ),
                  title: const Text('Amount: High to Low'),
                  trailing: _sortOption == SortOption.amountDesc
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() => _sortOption = SortOption.amountDesc);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.arrow_upward_rounded,
                    color: AppTheme.primary,
                  ),
                  title: const Text('Amount: Low to High'),
                  trailing: _sortOption == SortOption.amountAsc
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() => _sortOption = SortOption.amountAsc);
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_today_rounded,
                    color: AppTheme.secondary,
                  ),
                  title: const Text('Date: Newest First'),
                  trailing: _sortOption == SortOption.dateDesc
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.secondary,
                        )
                      : null,
                  onTap: () {
                    setState(() => _sortOption = SortOption.dateDesc);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.history_rounded,
                    color: AppTheme.secondary,
                  ),
                  title: const Text('Date: Oldest First'),
                  trailing: _sortOption == SortOption.dateAsc
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.secondary,
                        )
                      : null,
                  onTap: () {
                    setState(() => _sortOption = SortOption.dateAsc);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getSortLabel() {
    switch (_sortOption) {
      case SortOption.amountDesc:
        return 'Amount (High → Low)';
      case SortOption.amountAsc:
        return 'Amount (Low → High)';
      case SortOption.dateAsc:
        return 'Date (Oldest)';
      case SortOption.dateDesc:
        return 'Date (Newest)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transactions = _filteredTransactions;

    // Calculate totals for filtered view
    double totalSpent = 0;
    double totalIncome = 0;
    for (final t in transactions) {
      if (t.type == 'Income') {
        totalIncome += t.amount;
      } else {
        totalSpent += t.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BankStatementScreen()),
              );
              if (mounted) {
                _loadTransactions();
              }
            },
            tooltip: 'Upload Bank Statement',
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            onPressed: _syncAndReload,
            tooltip: 'Sync with Sheets',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          if (added == true || mounted) {
            _loadTransactions();
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: _syncAndReload,
        color: AppTheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search note, category...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceContainer
                            : AppTheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 12),

                    // Type Segmented Pill Selector (All | Personal | Family)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceContainer
                            : AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: ['All', 'Personal', 'Family'].map((name) {
                          final isSelected = _typeFilter == name;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _typeFilter = name),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                            ? AppTheme.primaryContainer
                                            : AppTheme.primary)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isSelected
                                      ? AppTheme.subtleFloatShadow
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    name,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: isSelected
                                              ? (isDark
                                                    ? AppTheme
                                                          .onPrimaryContainer
                                                    : Colors.white)
                                              : (isDark
                                                    ? AppTheme
                                                          .darkOnSurfaceVariant
                                                    : AppTheme
                                                          .onSurfaceVariant),
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
                    const SizedBox(height: 12),

                    // Date Filter Row (Chips)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDateChip(
                            label: 'This Month',
                            preset: DateFilterPreset.thisMonth,
                          ),
                          const SizedBox(width: 8),
                          _buildDateChip(
                            label: 'Last Month',
                            preset: DateFilterPreset.lastMonth,
                          ),
                          const SizedBox(width: 8),
                          _buildDateChip(
                            label: 'All Time',
                            preset: DateFilterPreset.allTime,
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            avatar: Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: _dateFilter == DateFilterPreset.customRange
                                  ? Colors.white
                                  : AppTheme.primary,
                            ),
                            label: Text(
                              _dateFilter == DateFilterPreset.customRange &&
                                      _customDateRange != null
                                  ? '${DateFormat('MMM dd').format(_customDateRange!.start)} - ${DateFormat('MMM dd').format(_customDateRange!.end)}'
                                  : 'Custom Range',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    _dateFilter == DateFilterPreset.customRange
                                    ? Colors.white
                                    : (isDark
                                          ? AppTheme.darkOnSurface
                                          : AppTheme.onSurface),
                              ),
                            ),
                            backgroundColor:
                                _dateFilter == DateFilterPreset.customRange
                                ? AppTheme.primary
                                : (isDark
                                      ? AppTheme.darkSurfaceContainer
                                      : AppTheme.surfaceContainerLow),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color:
                                    _dateFilter == DateFilterPreset.customRange
                                    ? AppTheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                            onPressed: _pickCustomDateRange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bank Account Filter Row (Chips)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildBankFilterChip(label: 'All Banks', bank: 'All'),
                          const SizedBox(width: 8),
                          _buildBankFilterChip(
                            label: 'SBI',
                            bank: TransactionModel.bankSbi,
                          ),
                          const SizedBox(width: 8),
                          _buildBankFilterChip(
                            label: 'Canara Bank',
                            bank: TransactionModel.bankCanara,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sort Filter Pill Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${transactions.length} ${transactions.length == 1 ? "record" : "records"} found',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _showSortBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurfaceContainer
                                  : AppTheme.surfaceContainerHigh.withOpacity(
                                      0.5,
                                    ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sort_rounded,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getSortLabel(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Overview Card of Filtered Data
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceContainerLowest
                            : AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2C3233)
                              : AppTheme.outlineVariant.withOpacity(0.2),
                        ),
                        boxShadow: AppTheme.ambientCardShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Filtered Spent',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${totalSpent.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: Colors.grey.withOpacity(0.2),
                          ),
                          Column(
                            children: [
                              Text(
                                'Filtered Income',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${totalIncome.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: Colors.grey.withOpacity(0.2),
                          ),
                          Column(
                            children: [
                              Text(
                                'Net Difference',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: (totalIncome - totalSpent) >= 0
                                      ? Colors.green
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${(totalIncome - totalSpent).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: (totalIncome - totalSpent) >= 0
                                      ? Colors.green
                                      : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Transaction items list or Empty State
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            else if (transactions.isEmpty)
              SliverFillRemaining(
                child: Center(
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
                          Icons.receipt_long_rounded,
                          size: 44,
                          color: AppTheme.outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions match your filters.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset Filters'),
                        onPressed: () {
                          setState(() {
                            _typeFilter = 'All';
                            _dateFilter = DateFilterPreset.allTime;
                            _customDateRange = null;
                            _sortOption = SortOption.dateDesc;
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final t = transactions[index];
                    DateTime? parsedDate;
                    try {
                      parsedDate = DateTime.parse(t.date).toLocal();
                    } catch (_) {}

                    final formattedDate = parsedDate != null
                        ? DateFormat('MMM dd, yyyy').format(parsedDate)
                        : t.date;

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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.note.isNotEmpty ? t.note : t.category,
                                  style: theme.textTheme.titleSmall?.copyWith(
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
                                                ? AppTheme.darkOnSurfaceVariant
                                                : AppTheme.onSurfaceVariant
                                                      .withOpacity(0.7),
                                            fontSize: 11,
                                          ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (t.bankAccount ==
                                                        TransactionModel
                                                            .bankCanara
                                                    ? const Color(0xFF0284C7)
                                                    : const Color(0xFF1E88E5))
                                                .withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (t.bankAccount != null &&
                                                t.bankAccount!.isNotEmpty)
                                            ? t.bankAccount!
                                            : 'SBI',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              t.bankAccount ==
                                                  TransactionModel.bankCanara
                                              ? const Color(0xFF0284C7)
                                              : const Color(0xFF1E88E5),
                                        ),
                                      ),
                                    ),
                                    if (t.type == 'Family' &&
                                        t.addedBy != null) ...[
                                      Text(
                                        ' • By ${t.addedBy!.split('@').first}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: isDark
                                                  ? AppTheme
                                                        .darkOnSurfaceVariant
                                                  : AppTheme.onSurfaceVariant
                                                        .withOpacity(0.7),
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic,
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: t.type == 'Income'
                                      ? Colors.green
                                      : (t.type == 'Family'
                                            ? Colors.blue
                                            : Colors.redAccent),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    t.synced
                                        ? Icons.cloud_done
                                        : Icons.cloud_off,
                                    size: 13,
                                    color: t.synced
                                        ? Colors.green
                                        : Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.synced ? 'Synced' : 'Pending',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: t.synced
                                          ? Colors.green
                                          : Colors.amber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }, childCount: transactions.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required DateFilterPreset preset,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _dateFilter == preset;

    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        color: isSelected
            ? Colors.white
            : (isDark ? AppTheme.darkOnSurface : AppTheme.onSurface),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: isDark
          ? AppTheme.darkSurfaceContainer
          : AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : Colors.transparent,
        ),
      ),
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() {
            _dateFilter = preset;
            _customDateRange = null;
          });
        }
      },
    );
  }

  Widget _buildBankFilterChip({required String label, required String bank}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _bankFilter == bank;

    return ChoiceChip(
      avatar: bank != 'All'
          ? Icon(
              Icons.account_balance_rounded,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (bank == TransactionModel.bankCanara
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF1E88E5)),
            )
          : null,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        color: isSelected
            ? Colors.white
            : (isDark ? AppTheme.darkOnSurface : AppTheme.onSurface),
      ),
      selected: isSelected,
      selectedColor: bank == TransactionModel.bankCanara
          ? const Color(0xFF0284C7)
          : (bank == TransactionModel.bankSbi
                ? const Color(0xFF1E88E5)
                : AppTheme.primary),
      backgroundColor: isDark
          ? AppTheme.darkSurfaceContainer
          : AppTheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark
                    ? Colors.white12
                    : AppTheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() {
            _bankFilter = bank;
          });
        }
      },
    );
  }
}
