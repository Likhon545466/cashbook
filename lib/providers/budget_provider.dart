import 'package:flutter/foundation.dart';

import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider(this._databaseService);

  final DatabaseService _databaseService;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<CashBudget> _budgets = [];
  bool _loading = false;

  DateTime get selectedMonth => _selectedMonth;
  List<CashBudget> get budgets => List.unmodifiable(_budgets);
  bool get loading => _loading;

  Future<void> loadCurrentMonth() async {
    await loadMonth(DateTime.now());
  }

  Future<void> loadMonth(DateTime month) async {
    _selectedMonth = DateTime(month.year, month.month);
    _loading = true;
    notifyListeners();

    try {
      _budgets = await _databaseService.getBudgetsForMonth(
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setBudget({
    required String category,
    required int amount,
  }) async {
    if (amount <= 0) return;

    await _databaseService.upsertBudget(
      CashBudget(
        category: category,
        amount: amount,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      ),
    );

    await loadMonth(_selectedMonth);
  }

  Future<void> removeBudget(String category) async {
    await _databaseService.deleteBudget(
      category: category,
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    );

    await loadMonth(_selectedMonth);
  }

  int budgetForCategory(String category) {
    for (final budget in _budgets) {
      if (budget.category == category) {
        return budget.amount;
      }
    }
    return 0;
  }

  int spentForCategory(String category, List<CashTransaction> transactions) {
    return transactions
        .where(
          (item) =>
              !item.isIncome &&
              item.category == category &&
              item.date.year == _selectedMonth.year &&
              item.date.month == _selectedMonth.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  int totalBudget() {
    return _budgets.fold(0, (sum, item) => sum + item.amount);
  }

  int totalSpent(List<CashTransaction> transactions) {
    return transactions
        .where(
          (item) =>
              !item.isIncome &&
              item.date.year == _selectedMonth.year &&
              item.date.month == _selectedMonth.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  double totalProgress(List<CashTransaction> transactions) {
    final budget = totalBudget();
    if (budget <= 0) return 0;

    return totalSpent(transactions) / budget;
  }
}
