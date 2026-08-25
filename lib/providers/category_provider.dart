import 'package:flutter/foundation.dart';

import '../models/category_model.dart';
import '../services/database_service.dart';

class CategoryProvider extends ChangeNotifier {
  final DatabaseService _databaseService;

  CategoryProvider(this._databaseService);

  final List<CashCategory> _categories = [];

  List<CashCategory> get categories => List.unmodifiable(_categories);

  List<CashCategory> byType(String type) =>
      _categories.where((item) => item.type == type).toList();

  Future<void> loadCategories() async {
    final items = await _databaseService.getCategories();
    _categories
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  Future<bool> addCategory({required String name, required String type}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;

    final exists = _categories.any(
      (item) =>
          item.type == type &&
          item.name.toLowerCase() == cleanName.toLowerCase(),
    );

    if (exists) return false;

    await _databaseService.insertCategory(
      CashCategory(name: cleanName, type: type, isDefault: false),
    );

    await loadCategories();
    return true;
  }

  Future<void> deleteCategory(CashCategory category) async {
    if (category.id == null || category.isDefault) return;
    await _databaseService.deleteCategory(category.id!);
    await loadCategories();
  }
}
