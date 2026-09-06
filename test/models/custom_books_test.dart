import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/models/transaction_model.dart';

void main() {
  group('Custom Books & Notes Unit Tests', () {
    test('extracts customBook and cleanNote correctly', () {
      final tx = CashTransaction(
        id: 1,
        type: 'expense',
        amount: 1200,
        category: 'Travel',
        date: DateTime(2026, 9, 6),
        note: 'Hotel booking in Cox [Book: Cox Trip]',
      );

      expect(tx.customBook, equals('Cox Trip'));
      expect(tx.cleanNote, equals('Hotel booking in Cox'));
    });

    test('handles transactions without customBook tag gracefully', () {
      final tx = CashTransaction(
        id: 2,
        type: 'income',
        amount: 5000,
        category: 'Salary',
        date: DateTime(2026, 9, 1),
        note: 'Regular salary deposit',
      );

      expect(tx.customBook, isNull);
      expect(tx.cleanNote, equals('Regular salary deposit'));
    });

    test('handles note that is only a customBook tag', () {
      final tx = CashTransaction(
        id: 3,
        type: 'expense',
        amount: 500,
        category: 'Food',
        date: DateTime(2026, 9, 6),
        note: '[Book: Office Renovation]',
      );

      expect(tx.customBook, equals('Office Renovation'));
      expect(tx.cleanNote, isEmpty);
    });

    test('isolates custom book calculations and balances accurately', () {
      final list = [
        CashTransaction(
          id: 1,
          type: 'income',
          amount: 50000,
          category: 'Budget',
          date: DateTime(2026, 9, 1),
          note: 'Project funding [Book: Side Business]',
        ),
        CashTransaction(
          id: 2,
          type: 'expense',
          amount: 15000,
          category: 'Equipment',
          date: DateTime(2026, 9, 3),
          note: 'Laptop purchase [Book: Side Business]',
        ),
        CashTransaction(
          id: 3,
          type: 'expense',
          amount: 5000,
          category: 'Groceries',
          date: DateTime(2026, 9, 4),
          note: 'Home groceries', // regular monthly transaction
        ),
      ];

      final sideBusinessTxs = list.where((t) => t.customBook == 'Side Business').toList();
      expect(sideBusinessTxs.length, equals(2));

      final income = sideBusinessTxs.where((t) => t.isIncome).fold<int>(0, (s, t) => s + t.amount);
      final expense = sideBusinessTxs.where((t) => !t.isIncome).fold<int>(0, (s, t) => s + t.amount);
      final net = income - expense;

      expect(income, equals(50000));
      expect(expense, equals(15000));
      expect(net, equals(35000));
    });
  });
}
