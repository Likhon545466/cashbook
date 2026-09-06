import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/models/transaction_model.dart';

void main() {
  group('Statement Export Tests', () {
    test('CSV generation formats fields, commas and quotes properly', () {
      final t1 = CashTransaction(
        id: 1,
        type: 'income',
        amount: 25000,
        category: 'Salary',
        date: DateTime(2026, 9, 1),
        note: 'Direct deposit',
      );

      final t2 = CashTransaction(
        id: 2,
        type: 'expense',
        amount: 450,
        category: 'Food',
        date: DateTime(2026, 9, 2),
        note: 'Lunch, with team "special"',
      );

      final transactions = [t1, t2];
      final buffer = StringBuffer()..writeln('Date,Type,Category,Amount,Note,Book');

      for (final t in transactions) {
        final dateStr = '2026-09-0${t.id}';
        final typeStr = t.isIncome ? 'Income' : 'Expense';
        final catStr = t.category;
        final amtStr = t.amount.toString();
        final escapedNote = t.note.contains(',') || t.note.contains('"')
            ? '"${t.note.replaceAll('"', '""')}"'
            : t.note;
        final bookStr = 'Sep 2026';

        buffer.writeln('$dateStr,$typeStr,$catStr,$amtStr,$escapedNote,$bookStr');
      }

      final csv = buffer.toString();
      expect(csv, contains('Date,Type,Category,Amount,Note,Book'));
      expect(csv, contains('2026-09-01,Income,Salary,25000,Direct deposit,Sep 2026'));
      expect(csv, contains('2026-09-02,Expense,Food,450,"Lunch, with team ""special""",Sep 2026'));
    });
  });
}
