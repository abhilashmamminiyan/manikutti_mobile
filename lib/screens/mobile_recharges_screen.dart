import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mobile_recharge_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../database/db_helper.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';
import 'add_mobile_recharge_screen.dart';

class MobileRechargesScreen extends StatefulWidget {
  const MobileRechargesScreen({super.key});

  @override
  State<MobileRechargesScreen> createState() => _MobileRechargesScreenState();
}

class _MobileRechargesScreenState extends State<MobileRechargesScreen> {
  List<MobileRecharge> _recharges = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Expiring Soon',
    'Jio',
    'Airtel',
    'Vi',
    'BSNL',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecharges();
  }

  Future<void> _loadRecharges() async {
    setState(() => _isLoading = true);

    // 1. Load instantly from local SQLite
    try {
      final localList = await DbHelper.instance.getAllMobileRecharges();
      if (mounted) {
        setState(() {
          _recharges = localList;
        });
      }
    } catch (_) {}

    // 2. Fetch from cloud sheets if available and merge
    try {
      final cloudData = await ApiService.instance.fetchMobileRecharges();
      if (cloudData.isNotEmpty) {
        final cloudList = cloudData
            .map((j) => MobileRecharge.fromJson(j))
            .toList();
        if (mounted) {
          setState(() {
            _recharges = cloudList;
          });
        }
      }
    } catch (_) {}

    _scheduleAllReminders();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _scheduleAllReminders() {
    for (final r in _recharges) {
      if (r.notifyExpiry && r.id != null && r.validityTill.isNotEmpty) {
        final expiry = DateTime.tryParse(r.validityTill);
        if (expiry != null && !r.isExpired) {
          final notificationId = 30000 + (r.id! % 10000);
          NotificationService.instance.scheduleRechargeExpiryReminder(
            id: notificationId,
            name: r.name,
            operatorName: r.operator,
            phoneNumber: r.phoneNumber,
            amount: r.planLastRecharged,
            expiryDate: expiry,
            daysBefore: r.reminderDaysBefore,
          );
        }
      }
    }
  }

  Color _getOperatorColor(String operator) {
    switch (operator.toLowerCase()) {
      case 'jio':
        return const Color(0xFF0F52BA);
      case 'airtel':
        return const Color(0xFFE40000);
      case 'vi':
        return const Color(0xFFC70039);
      case 'bsnl':
        return const Color(0xFF008542);
      default:
        return const Color(0xFF5C6F84);
    }
  }

  List<MobileRecharge> get _filteredRecharges {
    if (_selectedFilter == 'All') return _recharges;
    if (_selectedFilter == 'Expiring Soon') {
      return _recharges
          .where((r) => r.isExpiringSoon || r.isExpiringToday || r.isExpired)
          .toList();
    }
    return _recharges
        .where((r) => r.operator.toLowerCase() == _selectedFilter.toLowerCase())
        .toList();
  }

  Future<void> _deleteRecharge(MobileRecharge recharge) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recharge'),
        content: Text(
          'Are you sure you want to remove ${recharge.name} (${recharge.phoneNumber})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || recharge.id == null) return;

    await DbHelper.instance.deleteMobileRecharge(recharge.id!);
    final notificationId = 30000 + (recharge.id! % 10000);
    await NotificationService.instance.cancelRechargeReminder(notificationId);
    ApiService.instance
        .deleteMobileRecharge(recharge.id!)
        .catchError((_) => false);

    _loadRecharges();
  }

  void _showQuickRechargeDialog(MobileRecharge recharge) {
    int additionalDays = 28;
    double newAmount = recharge.planLastRecharged;
    bool logExpense = recharge.logExpense;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSB) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final currentExpiry =
              DateTime.tryParse(recharge.validityTill) ?? DateTime.now();
          final baseDate = currentExpiry.isAfter(DateTime.now())
              ? currentExpiry
              : DateTime.now();
          final newExpiry = baseDate.add(Duration(days: additionalDays));

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: _getOperatorColor(recharge.operator),
                ),
                const SizedBox(width: 8),
                Text('Renew ${recharge.name}'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recharge.operator} • ${recharge.phoneNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkOnSurfaceVariant : Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Validity Extension:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [28, 56, 84, 365].map((d) {
                    final isSel = additionalDays == d;
                    return ChoiceChip(
                      label: Text('+$d d'),
                      selected: isSel,
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSel
                            ? Colors.white
                            : (isDark
                                  ? AppTheme.darkOnSurface
                                  : AppTheme.onSurface),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setSB(() => additionalDays = d);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerHigh.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New Expiry Date:'),
                      Text(
                        DateFormat('MMM dd, yyyy').format(newExpiry),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Record in Expenses',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: logExpense,
                  activeColor: AppTheme.primary,
                  onChanged: (val) => setSB(() => logExpense = val ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final updated = recharge.copyWith(
                    validityTill: DateFormat('yyyy-MM-dd').format(newExpiry),
                    lastRechargedDate: DateFormat(
                      'yyyy-MM-dd',
                    ).format(DateTime.now()),
                    logExpense: logExpense,
                  );

                  await DbHelper.instance.updateMobileRecharge(updated);

                  if (updated.notifyExpiry && updated.id != null) {
                    final notificationId = 30000 + (updated.id! % 10000);
                    await NotificationService.instance
                        .scheduleRechargeExpiryReminder(
                          id: notificationId,
                          name: updated.name,
                          operatorName: updated.operator,
                          phoneNumber: updated.phoneNumber,
                          amount: updated.planLastRecharged,
                          expiryDate: newExpiry,
                          daysBefore: updated.reminderDaysBefore,
                        );
                  }

                  ApiService.instance
                      .updateMobileRecharge(updated.toJson())
                      .catchError((_) => false);

                  _loadRecharges();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Recharge renewed till ${DateFormat('MMM dd, yyyy').format(newExpiry)}',
                        ),
                        backgroundColor: AppTheme.primary,
                      ),
                    );
                  }
                },
                child: const Text('Confirm Renewal'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalSims = _recharges.length;
    final expiringCount = _recharges
        .where((r) => r.isExpiringSoon || r.isExpiringToday || r.isExpired)
        .length;
    final totalSpend = _recharges.fold<double>(
      0.0,
      (sum, r) => sum + r.planLastRecharged,
    );

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.surface,
      appBar: AppBar(
        title: const Text('Mobile Recharges'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add SIM'),
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddMobileRechargeScreen()),
          );
          if (added == true) _loadRecharges();
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecharges,
          child: _isLoading && _recharges.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview Metric Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Active SIMs',
                              value: '$totalSims',
                              icon: Icons.sim_card_outlined,
                              accentColor: AppTheme.primary,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Expiring',
                              value: '$expiringCount',
                              icon: Icons.warning_amber_rounded,
                              accentColor: expiringCount > 0
                                  ? AppTheme.error
                                  : Colors.green,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Burn',
                              value: '₹${totalSpend.toStringAsFixed(0)}',
                              icon: Icons.currency_rupee_rounded,
                              accentColor: AppTheme.secondary,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((filter) {
                            final isSel = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: isSel,
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  color: isSel
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (val) {
                                  if (val)
                                    setState(() => _selectedFilter = filter);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Recharges List
                      if (_filteredRecharges.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredRecharges.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final recharge = _filteredRecharges[index];
                            return _buildRechargeCard(recharge, isDark);
                          },
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainer
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.editorialShadow,
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeCard(MobileRecharge recharge, bool isDark) {
    final opColor = _getOperatorColor(recharge.operator);
    final days = recharge.daysRemaining;

    Color statusBg;
    Color statusText;
    String badgeLabel;

    if (days < 0) {
      statusBg = AppTheme.error.withOpacity(0.15);
      statusText = AppTheme.error;
      badgeLabel = 'Expired';
    } else if (days == 0) {
      statusBg = Colors.orange.withOpacity(0.2);
      statusText = Colors.deepOrange;
      badgeLabel = 'Expires Today';
    } else if (days <= 3) {
      statusBg = Colors.amber.withOpacity(0.2);
      statusText = Colors.amber[900]!;
      badgeLabel = '$days days left';
    } else {
      statusBg = Colors.green.withOpacity(0.15);
      statusText = Colors.green[800]!;
      badgeLabel = '$days days left';
    }

    DateTime? expiry;
    if (recharge.validityTill.isNotEmpty) {
      expiry = DateTime.tryParse(recharge.validityTill);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainer
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.editorialShadow,
        border: Border.all(
          color: days <= 3 ? statusText.withOpacity(0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Operator Badge, Contact Name, Status Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: opColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  recharge.operator.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recharge.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: statusText,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Phone Number & Notification icon
          Row(
            children: [
              const Icon(Icons.call_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                recharge.phoneNumber,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (recharge.notifyExpiry)
                const Tooltip(
                  message: 'Recharge expiry reminder active',
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Alert ON',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Plan Details & Expiry Date Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkBackground.withOpacity(0.5)
                  : AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last Plan',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${recharge.planLastRecharged.toStringAsFixed(0)} ${recharge.planDescription.isNotEmpty ? '• ${recharge.planDescription}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Validity Till',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expiry != null
                          ? DateFormat('MMM dd, yyyy').format(expiry)
                          : 'N/A',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: days <= 3 ? statusText : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Actions Row: Renew / Recharged Today, Edit, Delete
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showQuickRechargeDialog(recharge),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.autorenew_rounded, size: 16),
                  label: const Text(
                    'Recharged Today',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () async {
                  final updated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddMobileRechargeScreen(initialRecharge: recharge),
                    ),
                  );
                  if (updated == true) _loadRecharges();
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppTheme.error,
                ),
                onPressed: () => _deleteRecharge(recharge),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              size: 48,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Mobile Recharges Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep track of family and personal SIM cards, expiry dates, and recharge reminders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First SIM'),
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddMobileRechargeScreen(),
                ),
              );
              if (added == true) _loadRecharges();
            },
          ),
        ],
      ),
    );
  }
}
