import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/services/csv_import_service.dart';
import 'package:cashbook/models/transaction_model.dart';

void main() {
  group('CsvImportService Unit Tests', () {
    test('parses standard CashBook CSV export correctly', () {
      const csvData = '''Date,Type,Amount,Category,Note
2026-09-02 14:30:00,income,5000,Salary,"Monthly salary pay"
2026-09-02 18:00:00,expense,450,Food,"Dinner at restaurant"
2026-09-01 10:15:00,expense,1200,Shopping,"Groceries for week"
''';

      final preview = CsvImportService.parseCsv(csvData);

      expect(preview.totalRows, equals(3));
      expect(preview.validCount, equals(3));
      expect(preview.invalidCount, equals(0));
      expect(preview.discoveredCategories, containsAll(['Salary', 'Food', 'Shopping']));

      final row1 = preview.rows[0];
      expect(row1.type, equals('income'));
      expect(row1.amount, equals(5000));
      expect(row1.category, equals('Salary'));
      expect(row1.note, equals('Monthly salary pay'));
      expect(row1.isValid, isTrue);
    });

    test('detects duplicates against existing transactions', () {
      final existing = [
        CashTransaction(
          id: 1,
          type: 'income',
          amount: 5000,
          category: 'Salary',
          date: DateTime(2026, 9, 2, 10, 0),
          note: 'Pay',
        ),
      ];

      const csvData = '''Date,Type,Amount,Category,Note
2026-09-02,income,5000,Salary,Pay
2026-09-02,expense,300,Snacks,Coffee
''';

      final preview = CsvImportService.parseCsv(csvData, existingTransactions: existing);

      expect(preview.totalRows, equals(2));
      expect(preview.validCount, equals(1)); // only the non-duplicate
      expect(preview.duplicateCount, equals(1));

      expect(preview.rows[0].isDuplicate, isTrue);
      expect(preview.rows[1].isDuplicate, isFalse);
    });

    test('handles bank statement format with alternative headers and currency symbols', () {
      const csvData = '''Transaction Date,Entry,Value,Tag,Description
02/09/2026,Credit,"৳15,000",Freelance,Design gig
01/09/2026,Debit,"\$2,500",Rent,Apartment rent
''';

      final preview = CsvImportService.parseCsv(csvData);

      expect(preview.totalRows, equals(2));
      expect(preview.validCount, equals(2));

      final row1 = preview.rows[0];
      expect(row1.type, equals('income'));
      expect(row1.amount, equals(15000));
      expect(row1.category, equals('Freelance'));

      final row2 = preview.rows[1];
      expect(row2.type, equals('expense'));
      expect(row2.amount, equals(2500));
      expect(row2.category, equals('Rent'));
    });

    test('marks rows with invalid date or invalid amount as invalid', () {
      const csvData = '''Date,Type,Amount,Category,Note
invalid-date,expense,500,Food,Test
2026-09-02,expense,0,Food,Zero amount
2026-09-02,expense,abc,Food,Non-numeric amount
''';

      final preview = CsvImportService.parseCsv(csvData);

      expect(preview.totalRows, equals(3));
      expect(preview.validCount, equals(0));
      expect(preview.invalidCount, equals(3));
    });
  });
}
