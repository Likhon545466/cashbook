import 'package:flutter/foundation.dart';

import '../models/savings_transfer_model.dart';
import '../services/database_service.dart';

class SavingsProvider extends ChangeNotifier {
  SavingsProvider(this._databaseService);

  final DatabaseService _databaseService;

  List<SavingsTransfer> _items = [];
  bool _loading = false;
  String? _errorMessage;

  List<SavingsTransfer> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  int get balance => _items.fold(
    0,
    (sum, item) => sum + (item.isDeposit ? item.amount : -item.amount),
  );

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _databaseService.getSavingsTransfers();
    } catch (_) {
      _errorMessage = 'Could not load savings.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> deposit({required int amount, String note = ''}) async {
    if (amount <= 0) return false;

    try {
      await _databaseService.insertSavingsTransfer(
        SavingsTransfer(
          type: 'deposit',
          amount: amount,
          date: DateTime.now(),
          note: note,
        ),
      );
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not add to savings.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> withdraw({required int amount, String note = ''}) async {
    if (amount <= 0 || amount > balance) return false;

    try {
      await _databaseService.insertSavingsTransfer(
        SavingsTransfer(
          type: 'withdraw',
          amount: amount,
          date: DateTime.now(),
          note: note,
        ),
      );
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not withdraw savings.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTransfer({
    required SavingsTransfer original,
    required int amount,
  }) async {
    if (original.id == null || amount <= 0) return false;

    final currentBalance = balance;
    final oldEffect = original.isDeposit ? original.amount : -original.amount;
    final newEffect = original.isDeposit ? amount : -amount;
    final projectedBalance = currentBalance - oldEffect + newEffect;

    if (projectedBalance < 0) {
      _errorMessage = 'This change would make savings negative.';
      notifyListeners();
      return false;
    }

    try {
      final changed = await _databaseService.updateSavingsTransfer(
        SavingsTransfer(
          id: original.id,
          type: original.type,
          amount: amount,
          date: original.date,
          note: original.note,
        ),
      );

      if (changed <= 0) return false;
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not update savings entry.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreTransfer(SavingsTransfer item) async {
    try {
      await _databaseService.insertSavingsTransfer(
        SavingsTransfer(
          type: item.type,
          amount: item.amount,
          date: item.date,
          note: item.note,
        ),
      );
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not restore savings entry.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransfer(SavingsTransfer item) async {
    if (item.id == null) return false;

    final projectedBalance =
        balance - (item.isDeposit ? item.amount : -item.amount);

    if (projectedBalance < 0) {
      _errorMessage = 'Delete blocked because savings would become negative.';
      notifyListeners();
      return false;
    }

    try {
      final changed = await _databaseService.deleteSavingsTransfer(item.id!);
      if (changed <= 0) return false;
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not delete savings entry.';
      notifyListeners();
      return false;
    }
  }
}
