import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

class CategoryService {
  static final CategoryService instance = CategoryService._init();
  static const String _keyCategories = 'custom_expense_categories';

  static const List<String> defaultCategories = [
    'Food',
    'Fuel',
    'Shopping',
    'Housing',
    'Transport',
    'Health',
    'Leisure',
    'Investment',
    'Other',
  ];

  final ValueNotifier<List<String>> categoriesNotifier =
      ValueNotifier<List<String>>(defaultCategories);

  CategoryService._init();

  Future<void> init() async {
    final cats = await getExpenseCategories();
    categoriesNotifier.value = cats;
    await syncToWidget(cats);
  }

  Future<List<String>> getExpenseCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_keyCategories);
      if (stored != null && stored.isNotEmpty) {
        return stored;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading categories: $e');
    }
    return List<String>.from(defaultCategories);
  }

  Future<bool> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return false;

    final current = await getExpenseCategories();
    // Case-insensitive duplicate check
    if (current.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      return false;
    }

    current.add(trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCategories, current);
    categoriesNotifier.value = List<String>.from(current);
    await syncToWidget(current);
    return true;
  }

  Future<bool> removeCategory(String category) async {
    final current = await getExpenseCategories();
    final removed = current.remove(category);
    if (removed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyCategories, current);
      categoriesNotifier.value = List<String>.from(current);
      await syncToWidget(current);
      return true;
    }
    return false;
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCategories);
    categoriesNotifier.value = List<String>.from(defaultCategories);
    await syncToWidget(defaultCategories);
  }

  Future<void> syncToWidget(List<String> categories) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'widget_categories',
        categories.join(','),
      );
      await HomeWidget.updateWidget(
        androidName: 'ManikuttiQuickLogWidgetProvider',
      );
    } catch (e) {
      if (kDebugMode) print('Error syncing categories to widget: $e');
    }
  }
}
