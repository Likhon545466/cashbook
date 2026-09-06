import 'package:flutter/foundation.dart';

import '../models/transaction_model.dart';
import '../services/database_service.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseService _databaseService;

  TransactionProvider(this._databaseService);

  static const String _customBooksKey = 'custom_books_list';

  final List<CashTransaction> _transactions = [];
  final List<String> _customBooks = [];
  String? _selectedCustomBook;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<CashTransaction> get transactions => List.unmodifiable(_transactions);
  List<String> get customBooks => List.unmodifiable(_customBooks);
  String? get selectedCustomBook => _selectedCustomBook;
  bool get isCustomBookSelected => _selectedCustomBook != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedMonth => _selectedMonth;

  String get activeBookTitle {
    if (_selectedCustomBook != null) {
      return _selectedCustomBook!;
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  bool get isCurrentMonthSelected {
    if (_selectedCustomBook != null) return false;
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  void setSelectedMonth(DateTime month) {
    _selectedCustomBook = null;
    final target = DateTime(month.year, month.month);
    if (_selectedMonth.year == target.year &&
        _selectedMonth.month == target.month) {
      notifyListeners();
      return;
    }
    _selectedMonth = target;
    notifyListeners();
  }

  void selectCustomBook(String? bookName) {
    if (bookName == null || bookName.trim().isEmpty) {
      _selectedCustomBook = null;
    } else {
      _selectedCustomBook = bookName.trim();
    }
    notifyListeners();
  }

  Future<void> createCustomBook(String bookName) async {
    final trimmed = bookName.trim();
    if (trimmed.isEmpty || _customBooks.contains(trimmed)) return;
    _customBooks.add(trimmed);
    _selectedCustomBook = trimmed;
    await _saveCustomBooks();
    notifyListeners();
  }

  Future<void> deleteCustomBook(String bookName) async {
    _customBooks.remove(bookName);
    if (_selectedCustomBook == bookName) {
      _selectedCustomBook = null;
    }
    await _saveCustomBooks();
    notifyListeners();
  }

  Future<void> _saveCustomBooks() async {
    final csv = _customBooks.join('|||');
    await _databaseService.setSetting(_customBooksKey, csv);
  }

  Future<void> _loadCustomBooks() async {
    final raw = await _databaseService.getSetting(_customBooksKey);
    _customBooks.clear();
    if (raw != null && raw.trim().isNotEmpty) {
      _customBooks.addAll(
        raw.split('|||').map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }
    // Also discover any custom books tagged in existing transactions
    for (final item in _transactions) {
      final b = item.customBook;
      if (b != null && b.isNotEmpty && !_customBooks.contains(b)) {
        _customBooks.add(b);
      }
    }
  }

  void changeSelectedMonth(int monthOffset) {
    if (_selectedCustomBook != null) {
      _selectedCustomBook = null;
    }
    setSelectedMonth(
      DateTime(_selectedMonth.year, _selectedMonth.month + monthOffset),
    );
  }

  void resetToCurrentMonth() {
    _selectedCustomBook = null;
    final now = DateTime.now();
    setSelectedMonth(DateTime(now.year, now.month));
  }

  int get totalIncome => _transactions
      .where((item) => item.isIncome)
      .fold(0, (sum, item) => sum + item.amount);

  int get totalExpense => _transactions
      .where((item) => !item.isIncome)
      .fold(0, (sum, item) => sum + item.amount);

  int get balance => totalIncome - totalExpense;

  List<CashTransaction> get currentBookTransactions {
    if (_selectedCustomBook != null) {
      return _transactions
          .where((item) => item.customBook == _selectedCustomBook)
          .toList(growable: false);
    }
    return _transactions
        .where((item) =>
            item.customBook == null &&
            item.date.year == _selectedMonth.year &&
            item.date.month == _selectedMonth.month)
        .toList(growable: false);
  }

  int get currentBookIncome => currentBookTransactions
      .where((item) => item.isIncome)
      .fold(0, (sum, item) => sum + item.amount);

  int get currentBookExpense => currentBookTransactions
      .where((item) => !item.isIncome)
      .fold(0, (sum, item) => sum + item.amount);

  int get currentBookNet => currentBookIncome - currentBookExpense;

  List<CashTransaction> _forMonth(DateTime month) {
    return _transactions
        .where((item) {
          return item.date.year == month.year && item.date.month == month.month;
        })
        .toList(growable: false);
  }

  List<CashTransaction> transactionsForMonth(DateTime month) => _forMonth(month);

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

  int netCashForMonth(DateTime month) {
    return incomeForMonth(month) - expenseForMonth(month);
  }

  int get selectedMonthIncome => incomeForMonth(_selectedMonth);
  int get selectedMonthExpense => expenseForMonth(_selectedMonth);
  int get selectedMonthNet => selectedMonthIncome - selectedMonthExpense;
  List<CashTransaction> get selectedMonthTransactions => _forMonth(_selectedMonth);

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
      await _loadCustomBooks();
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

  Future<bool> deleteMonthTransactions(DateTime month) async {
    try {
      final targets = _transactions.where((t) {
        return t.date.year == month.year &&
            t.date.month == month.month &&
            t.customBook == null;
      }).toList();

      for (final t in targets) {
        if (t.id != null) {
          await _databaseService.deleteTransaction(t.id!);
        }
      }

      await loadTransactions();
      return true;
    } catch (e) {
      _errorMessage = 'Could not delete month transactions: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCustomBookTransactions(String bookName) async {
    try {
      final targets =
          _transactions.where((t) => t.customBook == bookName).toList();
      for (final t in targets) {
        if (t.id != null) {
          await _databaseService.deleteTransaction(t.id!);
        }
      }
      await deleteCustomBook(bookName);
      await loadTransactions();
      return true;
    } catch (e) {
      _errorMessage = 'Could not delete book transactions: $e';
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
