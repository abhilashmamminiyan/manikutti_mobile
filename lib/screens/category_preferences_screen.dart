import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../theme/app_theme.dart';

class CategoryPreferencesScreen extends StatefulWidget {
  const CategoryPreferencesScreen({super.key});

  @override
  State<CategoryPreferencesScreen> createState() =>
      _CategoryPreferencesScreenState();
}

class _CategoryPreferencesScreenState extends State<CategoryPreferencesScreen> {
  final TextEditingController _categoryController = TextEditingController();
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final list = await CategoryService.instance.getExpenseCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        _isLoading = false;
      });
    }
  }

  void _showAddCategoryDialog() {
    _categoryController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Add Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a name for the new expense category:',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                autofocus: true,
                maxLength: 24,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Snacks, Gym, Books',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _categoryController.text.trim();
                if (name.isEmpty) return;

                final success = await CategoryService.instance.addCategory(
                  name,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (success) {
                  await _loadCategories();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Category "$name" added successfully!'),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Category "$name" already exists.'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCategory(String category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to remove "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await CategoryService.instance.removeCategory(
                category,
              );
              if (success) {
                await _loadCategories();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "$category"'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmResetDefaults() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Categories?'),
        content: const Text(
          'This will restore the original default expense categories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await CategoryService.instance.resetToDefaults();
              await _loadCategories();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Categories reset to defaults'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expense Categories',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset to Defaults',
            onPressed: _confirmResetDefaults,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainerLowest
                        : AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2C3233)
                          : AppTheme.outlineVariant.withOpacity(0.18),
                    ),
                    boxShadow: AppTheme.ambientCardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.widgets_rounded,
                          color: Color(0xFF0F766E),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interactive Widget & App',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Categories added here automatically sync to your home screen Quick Log keypad and transaction entry forms.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppTheme.darkOnSurfaceVariant
                                    : AppTheme.onSurfaceVariant.withOpacity(
                                        0.7,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Categories Header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AVAILABLE CATEGORIES (${_categories.length})',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),

                // Categories Card List
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainerLowest
                        : AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2C3233)
                          : AppTheme.outlineVariant.withOpacity(0.18),
                    ),
                    boxShadow: AppTheme.ambientCardShadow,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF2C3233)
                            : AppTheme.outlineVariant.withOpacity(0.15),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isDefault = CategoryService.defaultCategories
                          .contains(category);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDefault
                                ? const Color(0xFF0F766E).withOpacity(0.12)
                                : const Color(0xFF0284C7).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              isDefault
                                  ? Icons.label_rounded
                                  : Icons.star_rounded,
                              size: 18,
                              color: isDefault
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        title: Text(
                          category,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          isDefault ? 'Default category' : 'Custom category',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                        trailing: isDefault
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkSurfaceContainer
                                      : AppTheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Built-in',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppTheme.darkOnSurfaceVariant
                                        : AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                tooltip: 'Remove Category',
                                onPressed: () =>
                                    _confirmDeleteCategory(category),
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
