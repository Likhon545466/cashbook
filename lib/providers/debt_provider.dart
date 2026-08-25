import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/debt_model.dart';
import '../models/debt_due_extension_model.dart';
import '../models/debt_payment_model.dart';
import '../models/savings_transfer_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

class DebtProvider extends ChangeNotifier {
  DebtProvider(this._databaseService);

  final DatabaseService _databaseService;

  List<DebtItem> _items = [];
  List<DebtPayment> _payments = [];
  List<DebtDueExtension> _extensions = [];
  bool _loading = false;
  String? _errorMessage;

  List<DebtItem> get items => List.unmodifiable(_items);
  List<DebtPayment> get payments => List.unmodifiable(_payments);
  List<DebtDueExtension> get extensions => List.unmodifiable(_extensions);
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final debts = await _databaseService.getDebts();
      final payments = await _databaseService.getDebtPayments();
      final extensions = await _databaseService.getDebtDueExtensions();

      _items = debts;
      _payments = payments;
      _extensions = extensions;
    } catch (_) {
      _errorMessage = 'Could not load debts.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  int paidFor(DebtItem item) {
    if (item.id == null) return 0;

    return _payments
        .where((payment) => payment.debtId == item.id)
        .fold<int>(0, (sum, payment) => sum + payment.amount);
  }

  int remainingFor(DebtItem item) {
    final remaining = item.amount - paidFor(item);
    return remaining < 0 ? 0 : remaining;
  }

  List<DebtPayment> paymentsFor(DebtItem item) {
    if (item.id == null) return const [];

    final result =
        _payments.where((payment) => payment.debtId == item.id).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return result;
  }

  List<DebtDueExtension> extensionsFor(DebtItem item) {
    if (item.id == null) return const [];

    final result =
        _extensions.where((extension) => extension.debtId == item.id).toList()
          ..sort((a, b) => b.changedAt.compareTo(a.changedAt));

    return result;
  }

  int extensionCountFor(DebtItem item) => extensionsFor(item).length;

  Future<bool> extendDueDate({
    required DebtItem debt,
    required DateTime newDueDate,
    String note = '',
  }) async {
    if (debt.id == null || remainingFor(debt) <= 0) return false;

    final currentDue = debt.dueDate;
    final todayNow = DateTime.now();
    final today = DateTime(todayNow.year, todayNow.month, todayNow.day);
    final newDay = DateTime(newDueDate.year, newDueDate.month, newDueDate.day);

    final minimum = currentDue == null
        ? DateTime(
            debt.createdAt.year,
            debt.createdAt.month,
            debt.createdAt.day,
          )
        : DateTime(currentDue.year, currentDue.month, currentDue.day);

    if (!newDay.isAfter(minimum)) {
      _errorMessage = currentDue == null
          ? 'New due date must be after the debt date.'
          : 'Extended due date must be after the current due date.';
      notifyListeners();
      return false;
    }

    if (newDay.isBefore(today)) {
      _errorMessage = 'Extended due date cannot be in the past.';
      notifyListeners();
      return false;
    }

    try {
      final extension = DebtDueExtension(
        debtId: debt.id!,
        oldDueDate: currentDue,
        newDueDate: newDay,
        changedAt: DateTime.now(),
        note: note.trim(),
      );

      final db = await _databaseService.database;
      await db.transaction((txn) async {
        final extensionData = extension.toMap()..remove('id');
        await txn.insert('debt_due_extensions', extensionData);

        final updatedData = debt.copyWith(dueDate: newDay).toMap()
          ..remove('id');

        await txn.update(
          'debts',
          updatedData,
          where: 'id = ?',
          whereArgs: [debt.id],
        );
      });

      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not extend due date.';
      notifyListeners();
      return false;
    }
  }

  String statusFor(DebtItem item) {
    final remaining = remainingFor(item);
    if (remaining <= 0) return 'Paid';

    final paid = paidFor(item);
    final due = item.dueDate;
    final now = DateTime.now();

    if (due != null) {
      final dueDay = DateTime(due.year, due.month, due.day);
      final today = DateTime(now.year, now.month, now.day);
      if (dueDay.isBefore(today)) return 'Overdue';
    }

    if (paid > 0) return 'Partially Paid';
    return 'Unpaid';
  }

  int get totalYouOwe {
    return _items
        .where((item) => item.isYouOwe)
        .fold<int>(0, (sum, item) => sum + remainingFor(item));
  }

  int get totalOwedToYou {
    return _items
        .where((item) => !item.isYouOwe)
        .fold<int>(0, (sum, item) => sum + remainingFor(item));
  }

  int get openCount {
    return _items.where((item) => remainingFor(item) > 0).length;
  }

  int get overdueCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _items.where((item) {
      final due = item.dueDate;
      if (due == null || remainingFor(item) <= 0) return false;

      final dueDay = DateTime(due.year, due.month, due.day);
      return dueDay.isBefore(today);
    }).length;
  }

  int get dueSoonCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 7));

    return _items.where((item) {
      final due = item.dueDate;
      if (due == null || remainingFor(item) <= 0) return false;

      final dueDay = DateTime(due.year, due.month, due.day);
      return !dueDay.isBefore(today) && !dueDay.isAfter(limit);
    }).length;
  }

  List<DebtItem> get overdueItems {
    final result = _items.where((item) => statusFor(item) == 'Overdue').toList()
      ..sort((a, b) {
        final aDue = a.dueDate;
        final bDue = b.dueDate;
        if (aDue == null && bDue == null) return 0;
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      });

    return List.unmodifiable(result);
  }

  List<DebtItem> get dueSoonItems {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 7));

    final result = _items.where((item) {
      if (remainingFor(item) <= 0) return false;

      final due = item.dueDate;
      if (due == null) return false;

      final dueDay = DateTime(due.year, due.month, due.day);
      return !dueDay.isBefore(today) && !dueDay.isAfter(limit);
    }).toList()..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    return List.unmodifiable(result);
  }

  DebtItem? get nextAttentionDebt {
    if (overdueItems.isNotEmpty) return overdueItems.first;
    if (dueSoonItems.isNotEmpty) return dueSoonItems.first;
    return null;
  }

  int get dueTodayCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _items.where((item) {
      if (remainingFor(item) <= 0) return false;
      final due = item.dueDate;
      if (due == null) return false;
      final dueDay = DateTime(due.year, due.month, due.day);
      return dueDay == today;
    }).length;
  }

  int get netPosition => totalOwedToYou - totalYouOwe;

  double progressFor(DebtItem item) {
    if (item.amount <= 0) return 0;

    final progress = paidFor(item) / item.amount;
    return progress.clamp(0.0, 1.0).toDouble();
  }

  Future<bool> settleDebt(DebtItem debt, {String source = 'main'}) async {
    final remaining = remainingFor(debt);
    if (remaining <= 0) return true;

    return addPayment(
      debt: debt,
      amount: remaining,
      date: DateTime.now(),
      note: 'Settled in full',
      source: source,
    );
  }

  Future<bool> addDebt({
    required String direction,
    required String person,
    required int amount,
    required DateTime createdAt,
    DateTime? dueDate,
    String note = '',
  }) async {
    if (person.trim().isEmpty || amount <= 0) {
      _errorMessage = 'Enter a person and valid amount.';
      notifyListeners();
      return false;
    }

    final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (createdDay.isAfter(today)) {
      _errorMessage = 'Debt date cannot be in the future.';
      notifyListeners();
      return false;
    }

    if (dueDate != null) {
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

      if (dueDay.isBefore(createdDay)) {
        _errorMessage = 'Due date cannot be before debt date.';
        notifyListeners();
        return false;
      }
    }

    try {
      await _databaseService.insertDebt(
        DebtItem(
          direction: direction,
          person: person.trim(),
          amount: amount,
          createdAt: createdAt,
          dueDate: dueDate,
          note: note.trim(),
        ),
      );
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not save debt.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDebt(DebtItem item) async {
    if (item.id == null || item.person.trim().isEmpty || item.amount <= 0) {
      return false;
    }

    final alreadyPaid = paidFor(item);
    if (item.amount < alreadyPaid) {
      _errorMessage =
          'Debt amount cannot be lower than payments already recorded.';
      notifyListeners();
      return false;
    }

    final createdDay = DateTime(
      item.createdAt.year,
      item.createdAt.month,
      item.createdAt.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (createdDay.isAfter(today)) {
      _errorMessage = 'Debt date cannot be in the future.';
      notifyListeners();
      return false;
    }

    final dueDate = item.dueDate;
    if (dueDate != null) {
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (dueDay.isBefore(createdDay)) {
        _errorMessage = 'Due date cannot be before debt date.';
        notifyListeners();
        return false;
      }
    }

    try {
      final changed = await _databaseService.updateDebt(item);
      if (changed <= 0) return false;
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not update debt.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDebt(DebtItem item) async {
    if (item.id == null) return false;

    try {
      final changed = await _databaseService.deleteDebt(item.id!);
      if (changed <= 0) return false;
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not delete debt.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addPayment({
    required DebtItem debt,
    required int amount,
    required DateTime date,
    String note = '',
    String source = 'main',
  }) async {
    if (debt.id == null || amount <= 0) return false;

    if (source != 'main' && source != 'savings') {
      _errorMessage = 'Invalid payment source.';
      notifyListeners();
      return false;
    }

    final remaining = remainingFor(debt);
    if (amount > remaining) {
      _errorMessage = 'Payment cannot be more than the remaining balance.';
      notifyListeners();
      return false;
    }

    final paymentDay = DateTime(date.year, date.month, date.day);
    final createdDay = DateTime(
      debt.createdAt.year,
      debt.createdAt.month,
      debt.createdAt.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (paymentDay.isBefore(createdDay)) {
      _errorMessage = 'Payment date cannot be before debt date.';
      notifyListeners();
      return false;
    }

    if (paymentDay.isAfter(today)) {
      _errorMessage = 'Payment date cannot be in the future.';
      notifyListeners();
      return false;
    }

    try {
      final db = await _databaseService.database;

      await db.transaction((txn) async {
        final isPaying = debt.isYouOwe;
        final transactionType = isPaying ? 'expense' : 'income';
        final category = isPaying ? 'Debt Payment' : 'Debt Collection';
        final movementNote = note.trim().isEmpty
            ? (isPaying
                  ? 'Debt payment • ${debt.person}'
                  : 'Debt collection • ${debt.person}')
            : note.trim();

        int? transactionId;
        int? savingsTransferId;

        if (source == 'main' && isPaying) {
          final rows = await txn.rawQuery(
            "SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0) AS balance FROM transactions",
          );
          final balance = (rows.first['balance'] as num?)?.toInt() ?? 0;

          if (balance < amount) {
            throw StateError('INSUFFICIENT_MAIN_BALANCE');
          }
        }

        if (source == 'savings' && isPaying) {
          final rows = await txn.rawQuery(
            "SELECT COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount ELSE -amount END), 0) AS balance FROM savings_transfers",
          );
          final balance = (rows.first['balance'] as num?)?.toInt() ?? 0;

          if (balance < amount) {
            throw StateError('INSUFFICIENT_SAVINGS');
          }
        }

        final transaction = CashTransaction(
          type: transactionType,
          amount: amount,
          category: category,
          date: date,
          note: movementNote,
        );

        final transactionData = transaction.toMap()..remove('id');
        transactionId = await txn.insert('transactions', transactionData);

        if (source == 'savings') {
          final savingsTransfer = SavingsTransfer(
            type: isPaying ? 'withdraw' : 'deposit',
            amount: amount,
            date: date,
            note: movementNote,
          );

          final savingsData = savingsTransfer.toMap()..remove('id');
          savingsTransferId = await txn.insert(
            'savings_transfers',
            savingsData,
          );
        }

        final payment = DebtPayment(
          debtId: debt.id!,
          amount: amount,
          date: date,
          note: note.trim(),
          source: source,
          transactionId: transactionId,
          savingsTransferId: savingsTransferId,
        );

        final paymentData = payment.toMap()..remove('id');
        await txn.insert('debt_payments', paymentData);
      });

      await load();
      return true;
    } on StateError catch (error) {
      if (error.message == 'INSUFFICIENT_MAIN_BALANCE') {
        _errorMessage = 'Not enough Main Balance for this payment.';
      } else if (error.message == 'INSUFFICIENT_SAVINGS') {
        _errorMessage = 'Not enough Savings for this payment.';
      } else {
        _errorMessage = 'Could not save payment.';
      }
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Could not save payment.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePayment({
    required DebtPayment payment,
    required DebtItem debt,
    required int amount,
    required DateTime date,
    required String note,
    required String source,
  }) async {
    if (payment.id == null || debt.id == null || amount <= 0) return false;

    if (source != 'main' && source != 'savings') {
      _errorMessage = 'Invalid payment source.';
      notifyListeners();
      return false;
    }

    final paymentDay = DateTime(date.year, date.month, date.day);
    final createdDay = DateTime(
      debt.createdAt.year,
      debt.createdAt.month,
      debt.createdAt.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (paymentDay.isBefore(createdDay)) {
      _errorMessage = 'Payment date cannot be before debt date.';
      notifyListeners();
      return false;
    }

    if (paymentDay.isAfter(today)) {
      _errorMessage = 'Payment date cannot be in the future.';
      notifyListeners();
      return false;
    }

    try {
      final db = await _databaseService.database;

      await db.transaction((txn) async {
        if (payment.transactionId != null) {
          await txn.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [payment.transactionId],
          );
        }

        if (payment.savingsTransferId != null) {
          await txn.delete(
            'savings_transfers',
            where: 'id = ?',
            whereArgs: [payment.savingsTransferId],
          );
        }

        final paidWithoutCurrent = paidFor(debt) - payment.amount;
        if (amount > debt.amount - paidWithoutCurrent) {
          throw StateError('OVERPAYMENT');
        }

        if (source == 'main' && debt.isYouOwe) {
          final rows = await txn.rawQuery(
            "SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0) AS balance FROM transactions",
          );
          final balance = (rows.first['balance'] as num?)?.toInt() ?? 0;
          if (balance < amount) {
            throw StateError('INSUFFICIENT_MAIN_BALANCE');
          }
        }

        if (source == 'savings' && debt.isYouOwe) {
          final rows = await txn.rawQuery(
            "SELECT COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount ELSE -amount END), 0) AS balance FROM savings_transfers",
          );
          final balance = (rows.first['balance'] as num?)?.toInt() ?? 0;
          if (balance < amount) {
            throw StateError('INSUFFICIENT_SAVINGS');
          }
        }

        final transaction = CashTransaction(
          type: debt.isYouOwe ? 'expense' : 'income',
          amount: amount,
          category: debt.isYouOwe ? 'Debt Payment' : 'Debt Collection',
          date: date,
          note: note.trim().isEmpty
              ? (debt.isYouOwe
                    ? 'Debt payment • ${debt.person}'
                    : 'Debt collection • ${debt.person}')
              : note.trim(),
        );

        final transactionData = transaction.toMap()..remove('id');
        final transactionId = await txn.insert('transactions', transactionData);

        int? savingsTransferId;
        if (source == 'savings') {
          final transfer = SavingsTransfer(
            type: debt.isYouOwe ? 'withdraw' : 'deposit',
            amount: amount,
            date: date,
            note: transaction.note,
          );
          final data = transfer.toMap()..remove('id');
          savingsTransferId = await txn.insert('savings_transfers', data);
        }

        await txn.update(
          'debt_payments',
          {
            'amount': amount,
            'date': date.toIso8601String(),
            'note': note.trim(),
            'source': source,
            'transactionId': transactionId,
            'savingsTransferId': savingsTransferId,
          },
          where: 'id = ?',
          whereArgs: [payment.id],
        );
      });

      await load();
      return true;
    } on StateError catch (error) {
      switch (error.message) {
        case 'OVERPAYMENT':
          _errorMessage = 'Payment cannot be more than the remaining balance.';
          break;
        case 'INSUFFICIENT_MAIN_BALANCE':
          _errorMessage = 'Not enough Main Balance for this payment.';
          break;
        case 'INSUFFICIENT_SAVINGS':
          _errorMessage = 'Not enough Savings for this payment.';
          break;
        default:
          _errorMessage = 'Could not update payment.';
      }
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Could not update payment.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restorePayment(DebtPayment payment) async {
    try {
      final db = await _databaseService.database;

      await db.transaction((txn) async {
        final debtRows = await txn.query(
          'debts',
          where: 'id = ?',
          whereArgs: [payment.debtId],
          limit: 1,
        );
        if (debtRows.isEmpty) {
          throw StateError('DEBT_NOT_FOUND');
        }

        final debt = DebtItem.fromMap(debtRows.first);
        final movementNote = payment.note.trim().isEmpty
            ? (debt.isYouOwe
                  ? 'Debt payment • ${debt.person}'
                  : 'Debt collection • ${debt.person}')
            : payment.note.trim();

        if (payment.source == 'main' && debt.isYouOwe) {
          final rows = await txn.rawQuery(
            "SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0) AS balance FROM transactions",
          );
          final balance = (rows.first['balance'] as num?)?.toInt() ?? 0;
          if (balance < payment.amount) {
            throw StateError('INSUFFICIENT_MAIN_BALANCE');
          }
        }

        if (payment.source == 'savings' && debt.isYouOwe) {
          final rows = await txn.rawQuery(
            "SELECT COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount ELSE -amount END), 0) AS balance FROM savings_transfers",
          );
          final balance = (rows.first['balance'] as num?)?.toInt() ?? 0;
          if (balance < payment.amount) {
            throw StateError('INSUFFICIENT_SAVINGS');
          }
        }

        final transaction = CashTransaction(
          type: debt.isYouOwe ? 'expense' : 'income',
          amount: payment.amount,
          category: debt.isYouOwe ? 'Debt Payment' : 'Debt Collection',
          date: payment.date,
          note: movementNote,
        );
        final transactionData = transaction.toMap()..remove('id');
        final transactionId = await txn.insert('transactions', transactionData);

        int? savingsTransferId;
        if (payment.source == 'savings') {
          final transfer = SavingsTransfer(
            type: debt.isYouOwe ? 'withdraw' : 'deposit',
            amount: payment.amount,
            date: payment.date,
            note: movementNote,
          );
          final data = transfer.toMap()..remove('id');
          savingsTransferId = await txn.insert('savings_transfers', data);
        }

        final data = payment.toMap()
          ..['transactionId'] = transactionId
          ..['savingsTransferId'] = savingsTransferId;
        await txn.insert(
          'debt_payments',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

      await load();
      return true;
    } on StateError catch (error) {
      _errorMessage = switch (error.message) {
        'DEBT_NOT_FOUND' => 'Debt was not found.',
        'INSUFFICIENT_MAIN_BALANCE' =>
          'Not enough Main Balance to restore this payment.',
        'INSUFFICIENT_SAVINGS' => 'Not enough Savings to restore this payment.',
        _ => 'Could not restore payment.',
      };
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Could not restore payment.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePayment(DebtPayment payment) async {
    if (payment.id == null) return false;

    try {
      final db = await _databaseService.database;

      await db.transaction((txn) async {
        if (payment.transactionId != null) {
          await txn.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [payment.transactionId],
          );
        }

        if (payment.savingsTransferId != null) {
          await txn.delete(
            'savings_transfers',
            where: 'id = ?',
            whereArgs: [payment.savingsTransferId],
          );
        }

        final changed = await txn.delete(
          'debt_payments',
          where: 'id = ?',
          whereArgs: [payment.id],
        );

        if (changed <= 0) {
          throw StateError('PAYMENT_NOT_FOUND');
        }
      });

      await load();
      return true;
    } on StateError catch (error) {
      if (error.message == 'PAYMENT_NOT_FOUND') {
        _errorMessage = 'Payment was not found.';
      } else {
        _errorMessage = 'Could not remove payment.';
      }
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Could not remove payment.';
      notifyListeners();
      return false;
    }
  }
}
