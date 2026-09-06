import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import 'cloud_sync_provider.dart';
import 'transaction_provider.dart';

class RecurringProvider extends ChangeNotifier {
  RecurringProvider(this._databaseService);

  final DatabaseService _databaseService;

  final List<RecurringTransaction> _items = [];
  bool _loading = false;
  String? _errorMessage;

  List<RecurringTransaction> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  List<RecurringTransaction> get dueItems {
    final now = DateTime.now();
    return _items.where((item) => item.isDueForMonth(now)).toList();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final rows = await _databaseService.getRecurringTransactions();
      _items
        ..clear()
        ..addAll(rows);
    } catch (e) {
      _errorMessage = 'Could not load recurring templates: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addRecurring(RecurringTransaction item) async {
    try {
      await _databaseService.insertRecurringTransaction(item);
      await load();
      return true;
    } catch (e) {
      _errorMessage = 'Could not save recurring template: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRecurring(RecurringTransaction item) async {
    try {
      final res = await _databaseService.updateRecurringTransaction(item);
      if (res > 0) {
        await load();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Could not update recurring template: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecurring(int id) async {
    try {
      final res = await _databaseService.deleteRecurringTransaction(id);
      if (res > 0) {
        await load();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Could not delete recurring template: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleActive(RecurringTransaction item) async {
    final updated = item.copyWith(isActive: !item.isActive);
    return updateRecurring(updated);
  }

  /// Applies a recurring transaction into the active ledger for this month.
  Future<bool> applyRecurring(
    RecurringTransaction item,
    BuildContext context,
  ) async {
    try {
      final now = DateTime.now();
      final day = item.dayOfMonth.clamp(1, DateTime(now.year, now.month + 1, 0).day);
      final txDate = DateTime(now.year, now.month, day, now.hour, now.minute);

      final baseNote = item.note.isEmpty ? item.cleanTitle : item.note;
      final fullNote = item.customBook != null && item.customBook!.isNotEmpty
          ? '$baseNote [Book: ${item.customBook}]'.trim()
          : baseNote;

      final tx = CashTransaction(
        type: item.type,
        amount: item.amount,
        category: item.category,
        date: txDate,
        note: fullNote,
      );

      final txProvider = context.read<TransactionProvider>();
      final ok = await txProvider.addTransaction(tx);
      if (!ok) return false;

      final currentKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final updated = item.copyWith(lastAppliedMonth: currentKey);
      await updateRecurring(updated);

      if (context.mounted) {
        context.read<CloudSyncProvider>().scheduleAutoSync();
      }

      return true;
    } catch (e) {
      _errorMessage = 'Could not apply recurring entry: $e';
      notifyListeners();
      return false;
    }
  }

  /// Undoes/reverts the applied recurring transaction for the current month,
  /// clearing its applied status and removing the matching recorded transaction from the ledger.
  Future<bool> undoApplyRecurring(
    RecurringTransaction item,
    BuildContext context, {
    bool deleteRecordedTransaction = true,
  }) async {
    try {
      final now = DateTime.now();
      final baseNote = item.note.isEmpty ? item.cleanTitle : item.note;
      final fullNote = item.customBook != null && item.customBook!.isNotEmpty
          ? '$baseNote [Book: ${item.customBook}]'.trim()
          : baseNote;

      if (deleteRecordedTransaction && context.mounted) {
        final txProvider = context.read<TransactionProvider>();
        final matching = txProvider.transactions.where((t) {
          final isSameMonth =
              t.date.year == now.year && t.date.month == now.month;
          final isSameType = t.type == item.type;
          final isSameAmt = t.amount == item.amount;
          final isSameCat = t.category == item.category;
          final isSameNote = t.note == fullNote ||
              (item.cleanTitle.isNotEmpty && t.note.contains(item.cleanTitle));
          return isSameMonth && isSameType && isSameAmt && isSameCat && isSameNote;
        }).toList();

        if (matching.isNotEmpty) {
          final toDelete = matching.first;
          if (toDelete.id != null) {
            await txProvider.deleteTransaction(toDelete.id!);
          }
        }
      }

      final updated = item.copyWith(clearLastAppliedMonth: true);
      await updateRecurring(updated);

      if (context.mounted) {
        context.read<CloudSyncProvider>().scheduleAutoSync();
      }

      return true;
    } catch (e) {
      _errorMessage = 'Could not undo recurring entry: $e';
      notifyListeners();
      return false;
    }
  }

  /// Applies all due recurring transactions in 1 tap.
  Future<int> applyAllDue(BuildContext context) async {
    final list = dueItems;
    var appliedCount = 0;

    for (final item in list) {
      final success = await applyRecurring(item, context);
      if (success) appliedCount++;
    }

    return appliedCount;
  }
}
