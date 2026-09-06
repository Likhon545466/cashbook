import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/models/transaction_model.dart';

void main() {
  group('Monthly Ledger & Rollover Unit Tests', () {
    test('filters transactions by month correctly', () {
      final sep1 = DateTime(2026, 9, 1, 10, 0);
      final sep15 = DateTime(2026, 9, 15, 14, 0);
      final oct1 = DateTime(2026, 10, 1, 9, 0);

      final list = [
        CashTransaction(
          id: 1,
          type: 'income',
          amount: 5000,
          category: 'Salary',
          date: sep1,
          note: 'September Salary',
        ),
        CashTransaction(
          id: 2,
          type: 'expense',
          amount: 1500,
          category: 'Rent',
          date: sep15,
          note: 'September Rent',
        ),
        CashTransaction(
          id: 3,
          type: 'income',
          amount: 3500,
          category: 'Opening Balance',
          date: oct1,
          note: 'Carried forward from September 2026',
        ),
      ];

      final sepItems = list.where(
        (item) => item.date.year == 2026 && item.date.month == 9,
      ).toList();

      final octItems = list.where(
        (item) => item.date.year == 2026 && item.date.month == 10,
      ).toList();

      expect(sepItems.length, equals(2));
      expect(octItems.length, equals(1));

      final sepIncome = sepItems
          .where((i) => i.isIncome)
          .fold<int>(0, (sum, i) => sum + i.amount);
      final sepExpense = sepItems
          .where((i) => !i.isIncome)
          .fold<int>(0, (sum, i) => sum + i.amount);
      final sepNet = sepIncome - sepExpense;

      expect(sepIncome, equals(5000));
      expect(sepExpense, equals(1500));
      expect(sepNet, equals(3500)); // Exactly equal to October Opening Balance!

      final octOpening = octItems
          .where((i) => i.isIncome && i.category == 'Opening Balance')
          .fold<int>(0, (sum, i) => sum + i.amount);
      expect(octOpening, equals(3500));
    });

    test('fresh month starts with 0 opening balance and isolates transactions', () {
      final nov15 = DateTime(2026, 11, 15, 12, 0);
      final list = [
        CashTransaction(
          id: 1,
          type: 'income',
          amount: 8000,
          category: 'Bonus',
          date: nov15,
          note: 'November Fresh bonus',
        ),
      ];

      final opening = list
          .where((i) => i.category == 'Opening Balance')
          .fold<int>(0, (sum, i) => sum + i.amount);
      expect(opening, equals(0));
      expect(list.length, equals(1));
      expect(list.first.amount, equals(8000));
    });
  });
}
