import 'package:flutter/foundation.dart';

import '../models/transaction_model.dart';
import '../services/database_service.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseService _databaseService;

  TransactionProvider(this._databaseService);

  final List<CashTransaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CashTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalIncome => _transactions
      .where((item) => item.isIncome)
      .fold(0, (sum, item) => sum + item.amount);

  int get totalExpense => _transactions
      .where((item) => !item.isIncome)
      .fold(0, (sum, item) => sum + item.amount);

  int get balance => totalIncome - totalExpense;

  List<CashTransaction> _forMonth(DateTime month) {
    return _transactions
        .where((item) {
          return item.date.year == month.year && item.date.month == month.month;
        })
        .toList(growable: false);
  }

  int incomeForMonth(DateTime month) {
    return _forMonth(
      month,
    ).where((item) => item.isIncome).fold(0, (sum, item) => sum + item.amount);
  }

  int expenseForMonth(DateTime month) {
    return _forMonth(
      month,
    ).where((item) => !item.isIncome).fold(0, (sum, item) => sum + item.amount);
  }

  int get monthlyIncome => incomeForMonth(DateTime.now());

  int get monthlyExpense => expenseForMonth(DateTime.now());

  int get previousMonthIncome {
    final now = DateTime.now();
    return incomeForMonth(DateTime(now.year, now.month - 1));
  }

  int get previousMonthExpense {
    final now = DateTime.now();
    return expenseForMonth(DateTime(now.year, now.month - 1));
  }

  int get todayIncome {
    final now = DateTime.now();

    return _transactions
        .where((item) => item.isIncome && _isSameDay(item.date, now))
        .fold(0, (sum, item) => sum + item.amount);
  }

  int get todayExpense {
    final now = DateTime.now();

    return _transactions
        .where((item) => !item.isIncome && _isSameDay(item.date, now))
        .fold(0, (sum, item) => sum + item.amount);
  }

  String? get currentMonthTopExpenseCategory {
    final now = DateTime.now();
    final totals = <String, int>{};

    for (final item in _transactions.where(
      (item) =>
          !item.isIncome &&
          item.date.year == now.year &&
          item.date.month == now.month,
    )) {
      totals[item.category] = (totals[item.category] ?? 0) + item.amount;
    }

    if (totals.isEmpty) return null;

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  int get currentMonthTopExpenseAmount {
    final category = currentMonthTopExpenseCategory;
    if (category == null) return 0;

    final now = DateTime.now();

    return _transactions
        .where(
          (item) =>
              !item.isIncome &&
              item.category == category &&
              item.date.year == now.year &&
              item.date.month == now.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  double get monthlySavingsRate {
    if (monthlyIncome <= 0) return 0;
    return ((monthlyIncome - monthlyExpense) / monthlyIncome) * 100;
  }

  List<CashTransaction> get recentTransactions =>
      _transactions.take(5).toList(growable: false);

  Future<void> loadTransactions() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await _databaseService.getTransactions();

      _transactions
        ..clear()
        ..addAll(items);
    } catch (_) {
      _errorMessage = 'Could not load transactions.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addTransaction(CashTransaction transaction) async {
    try {
      await _databaseService.insertTransaction(transaction);
      await loadTransactions();
      return true;
    } catch (_) {
      _errorMessage = 'Could not save transaction.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreTransaction(CashTransaction transaction) async {
    try {
      final restored = CashTransaction(
        type: transaction.type,
        amount: transaction.amount,
        category: transaction.category,
        date: transaction.date,
        note: transaction.note,
      );

      await _databaseService.insertTransaction(restored);
      await loadTransactions();
      return true;
    } catch (_) {
      _errorMessage = 'Could not restore transaction.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTransaction(CashTransaction transaction) async {
    try {
      final changed = await _databaseService.updateTransaction(transaction);

      if (changed == 0) {
        _errorMessage = 'Transaction was not found.';
        notifyListeners();
        return false;
      }

      await loadTransactions();
      return true;
    } catch (_) {
      _errorMessage = 'Could not update transaction.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      final deleted = await _databaseService.deleteTransaction(id);

      if (deleted == 0) {
        _errorMessage = 'Transaction was not found.';
        notifyListeners();
        return false;
      }

      await loadTransactions();
      return true;
    } catch (_) {
      _errorMessage = 'Could not delete transaction.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
