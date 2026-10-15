import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

class ExpenseCategoryData {
  final String category;
  final double amount;
  final double percentage;
  final Color color;
  final IconData icon;

  const ExpenseCategoryData({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.icon,
  });
}

class ExpensePieChart extends StatefulWidget {
  final List<TransactionModel> transactions;
  final String initialFilter; // 'All' | 'Personal' | 'Family'
  final ValueChanged<String>? onFilterChanged;

  const ExpensePieChart({
    super.key,
    required this.transactions,
    this.initialFilter = 'All',
    this.onFilterChanged,
  });

  @override
  State<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<ExpensePieChart>
    with SingleTickerProviderStateMixin {
  late String _currentFilter;
  late AnimationController _animController;
  late Animation<double> _chartAnimation;
  int? _selectedCategoryIndex;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant ExpensePieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter) {
      _currentFilter = widget.initialFilter;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  static const List<Color> _categoryColors = [
    Color(0xFF0D9488), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Cyan
    Color(0xFF64748B), // Slate / Other
  ];

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') ||
        cat.contains('dining') ||
        cat.contains('hotel')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('grocery') || cat.contains('supermarket')) {
      return Icons.local_grocery_store_rounded;
    }
    if (cat.contains('fuel') ||
        cat.contains('petrol') ||
        cat.contains('diesel') ||
        cat.contains('travel')) {
      return Icons.directions_car_rounded;
    }
    if (cat.contains('recharge') ||
        cat.contains('mobile') ||
        cat.contains('phone')) {
      return Icons.phone_android_rounded;
    }
    if (cat.contains('emi') || cat.contains('loan')) {
      return Icons.account_balance_rounded;
    }
    if (cat.contains('utility') ||
        cat.contains('electric') ||
        cat.contains('kseb') ||
        cat.contains('water') ||
        cat.contains('wifi')) {
      return Icons.bolt_rounded;
    }
    if (cat.contains('shopping') ||
        cat.contains('dress') ||
        cat.contains('amazon')) {
      return Icons.shopping_bag_rounded;
    }
    if (cat.contains('medical') ||
        cat.contains('health') ||
        cat.contains('hospital')) {
      return Icons.medical_services_rounded;
    }
    return Icons.category_rounded;
  }

  List<ExpenseCategoryData> _calculateCategoryData() {
    final now = DateTime.now();
    final Map<String, double> totals = {};
    double grandTotal = 0;

    for (final t in widget.transactions) {
      // Exclude income and self transfers from expense pie chart
      if (t.type == 'Income' || t.isTransfer) continue;

      if (_currentFilter == 'Personal' && t.type != 'Personal') continue;
      if (_currentFilter == 'Family' && t.type != 'Family') continue;

      final tDate = DateTime.tryParse(t.date);
      if (tDate == null) continue;
      // Filter for current calendar month
      if (tDate.year != now.year || tDate.month != now.month) continue;

      final cat = t.category.trim().isEmpty ? 'Other' : t.category.trim();
      totals[cat] = (totals[cat] ?? 0) + t.amount;
      grandTotal += t.amount;
    }

    if (grandTotal == 0) return [];

    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<ExpenseCategoryData> result = [];
    int colorIdx = 0;

    for (final entry in sortedEntries) {
      final percentage = (entry.value / grandTotal) * 100;
      final color = _categoryColors[colorIdx % _categoryColors.length];
      result.add(
        ExpenseCategoryData(
          category: entry.key,
          amount: entry.value,
          percentage: percentage,
          color: color,
          icon: _getCategoryIcon(entry.key),
        ),
      );
      colorIdx++;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = _calculateCategoryData();
    final totalExpense = categories.fold(0.0, (sum, c) => sum + c.amount);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title and Segmented Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spending Breakdown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(DateTime.now()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Filter switcher
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceContainer
                      : AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['All', 'Personal', 'Family'].map((f) {
                    final selected = _currentFilter == f;
                    return InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () {
                        setState(() {
                          _currentFilter = f;
                          _selectedCategoryIndex = null;
                        });
                        widget.onFilterChanged?.call(f);
                        _animController.forward(from: 0.0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? (isDark
                                    ? AppTheme.primaryContainer
                                    : AppTheme.primary)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: selected
                                ? (isDark
                                      ? AppTheme.onPrimaryContainer
                                      : Colors.white)
                                : (isDark
                                      ? AppTheme.darkOnSurfaceVariant
                                      : AppTheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (categories.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.donut_large_rounded,
                      size: 48,
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant.withValues(alpha: 0.3)
                          : AppTheme.outline.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No expense records found for this month',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppTheme.darkOnSurfaceVariant
                            : AppTheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Donut Chart & Center Metric
            Center(
              child: SizedBox(
                width: 210,
                height: 210,
                child: AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(210, 210),
                          painter: _DonutChartPainter(
                            categories: categories,
                            progress: _chartAnimation.value,
                            selectedIndex: _selectedCategoryIndex,
                            backgroundColor: isDark
                                ? AppTheme.darkSurfaceContainer
                                : AppTheme.surfaceContainerLow,
                          ),
                        ),
                        // Center Info
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCategoryIndex != null &&
                                      _selectedCategoryIndex! <
                                          categories.length
                                  ? categories[_selectedCategoryIndex!].category
                                  : 'Total Spent',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: isDark
                                    ? AppTheme.darkOnSurfaceVariant
                                    : AppTheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _selectedCategoryIndex != null &&
                                      _selectedCategoryIndex! <
                                          categories.length
                                  ? _currencyFormat.format(
                                      categories[_selectedCategoryIndex!]
                                          .amount,
                                    )
                                  : _currencyFormat.format(totalExpense),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? AppTheme.darkOnSurface
                                    : AppTheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (_selectedCategoryIndex != null &&
                                _selectedCategoryIndex! < categories.length)
                              Text(
                                '${categories[_selectedCategoryIndex!].percentage.toStringAsFixed(1)}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      categories[_selectedCategoryIndex!].color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Legend Grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.asMap().entries.map((entry) {
                final idx = entry.key;
                final cat = entry.value;
                final isSelected = _selectedCategoryIndex == idx;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = isSelected ? null : idx;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cat.color.withValues(alpha: 0.18)
                          : (isDark
                                ? AppTheme.darkSurfaceContainer
                                : AppTheme.surfaceContainerLow),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? cat.color : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: cat.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.darkOnSurface
                                : AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${cat.percentage.toStringAsFixed(0)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cat.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<ExpenseCategoryData> categories;
  final double progress;
  final int? selectedIndex;
  final Color backgroundColor;

  _DonutChartPainter({
    required this.categories,
    required this.progress,
    this.selectedIndex,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 24.0;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (categories.isEmpty) return;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final sweepAngle = (cat.percentage / 100) * 2 * math.pi * progress;
      final isSelected = selectedIndex == i;

      final paint = Paint()
        ..color = cat.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 4 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      final currentRadius = isSelected ? radius + 2 : radius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: currentRadius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.categories != categories;
  }
}
