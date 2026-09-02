import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/models/transaction_model.dart';
import 'package:cashbook/models/budget_model.dart';
import 'package:cashbook/models/savings_transfer_model.dart';
import 'package:cashbook/models/debt_model.dart';
import 'package:cashbook/models/debt_payment_model.dart';
import 'package:cashbook/models/debt_due_extension_model.dart';
import 'package:cashbook/models/category_model.dart';

void main() {
  group('Data Models Unit Tests', () {
    test('CashTransaction toMap and fromMap roundtrip', () {
      final now = DateTime(2026, 9, 2, 14, 30);
      final tx = CashTransaction(
        id: 10,
        type: 'income',
        amount: 5000,
        category: 'Salary',
        date: now,
        note: 'Monthly salary',
      );

      final map = tx.toMap();
      expect(map['id'], equals(10));
      expect(map['type'], equals('income'));
      expect(map['amount'], equals(5000));
      expect(map['category'], equals('Salary'));
      expect(map['date'], equals(now.toIso8601String()));
      expect(map['note'], equals('Monthly salary'));

      final from = CashTransaction.fromMap(map);
      expect(from.id, equals(tx.id));
      expect(from.isIncome, isTrue);
      expect(from.amount, equals(5000));
      expect(from.category, equals('Salary'));
      expect(from.note, equals('Monthly salary'));
    });

    test('CashCategory fromMap with default fallback', () {
      final category = CashCategory.fromMap({
        'id': 1,
        'name': 'Groceries',
        'type': 'expense',
        'isDefault': 1,
      });

      expect(category.name, equals('Groceries'));
      expect(category.type, equals('expense'));
      expect(category.isDefault, isTrue);
    });

    test('CashBudget toMap and fromMap roundtrip', () {
      final budget = CashBudget(
        id: 2,
        category: 'Food',
        amount: 10000,
        year: 2026,
        month: 9,
      );

      final map = budget.toMap();
      final from = CashBudget.fromMap(map);

      expect(from.id, equals(2));
      expect(from.category, equals('Food'));
      expect(from.amount, equals(10000));
      expect(from.year, equals(2026));
      expect(from.month, equals(9));
    });

    test('SavingsTransfer toMap and fromMap', () {
      final transfer = SavingsTransfer(
        id: 5,
        amount: 3000,
        type: 'deposit',
        date: DateTime(2026, 9, 2),
        note: 'Emergency fund saving',
      );

      expect(transfer.isDeposit, isTrue);
      final map = transfer.toMap();
      final from = SavingsTransfer.fromMap(map);

      expect(from.amount, equals(3000));
      expect(from.type, equals('deposit'));
      expect(from.note, equals('Emergency fund saving'));
    });

    test('DebtItem toMap, fromMap and copyWith', () {
      final debt = DebtItem(
        id: 1,
        direction: 'you_owe',
        person: 'John Doe',
        amount: 2500,
        createdAt: DateTime(2026, 8, 1),
        dueDate: DateTime(2026, 9, 1),
        note: 'Borrow for repair',
      );

      expect(debt.isYouOwe, isTrue);
      final map = debt.toMap();
      final from = DebtItem.fromMap(map);

      expect(from.person, equals('John Doe'));
      expect(from.amount, equals(2500));
      expect(from.dueDate, isNotNull);

      final updated = debt.copyWith(
        amount: 3000,
        clearDueDate: true,
      );
      expect(updated.amount, equals(3000));
      expect(updated.dueDate, isNull);
    });

    test('DebtPayment toMap and fromMap', () {
      final payment = DebtPayment(
        id: 10,
        debtId: 1,
        amount: 1000,
        date: DateTime(2026, 9, 2),
        note: 'First installment',
        source: 'main',
      );

      final map = payment.toMap();
      final from = DebtPayment.fromMap(map);

      expect(from.id, equals(10));
      expect(from.debtId, equals(1));
      expect(from.amount, equals(1000));
      expect(from.source, equals('main'));
    });

    test('DebtDueExtension toMap and fromMap', () {
      final extension = DebtDueExtension(
        id: 3,
        debtId: 1,
        oldDueDate: DateTime(2026, 9, 1),
        newDueDate: DateTime(2026, 10, 1),
        changedAt: DateTime(2026, 9, 2),
        note: 'Agreed 1 month extension',
      );

      final map = extension.toMap();
      final from = DebtDueExtension.fromMap(map);

      expect(from.debtId, equals(1));
      expect(from.oldDueDate, equals(DateTime(2026, 9, 1)));
      expect(from.newDueDate, equals(DateTime(2026, 10, 1)));
      expect(from.note, equals('Agreed 1 month extension'));
    });
  });
}
