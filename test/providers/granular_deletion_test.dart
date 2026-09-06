import 'package:flutter_test/flutter_test.dart';
import 'package:cashbook/models/transaction_model.dart';
import 'package:cashbook/providers/transaction_provider.dart';
import 'package:cashbook/services/database_service.dart';

class FakeTransactionDbService implements DatabaseService {
  final List<CashTransaction> inMemoryTransactions = [];
  final Map<String, String> settings = {};

  @override
  Future<List<CashTransaction>> getTransactions() async {
    return List.from(inMemoryTransactions);
  }

  @override
  Future<int> insertTransaction(CashTransaction transaction) async {
    final newId = inMemoryTransactions.length + 1;
    final created = transaction.copyWith(id: newId);
    inMemoryTransactions.add(created);
    return newId;
  }

  @override
  Future<int> deleteTransaction(int id) async {
    final countBefore = inMemoryTransactions.length;
    inMemoryTransactions.removeWhere((t) => t.id == id);
    return countBefore - inMemoryTransactions.length;
  }

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Granular Month & Book Deletion Tests', () {
    test('deleteMonthTransactions deletes only specified month transactions', () async {
      final db = FakeTransactionDbService();
      final provider = TransactionProvider(db);

      // Aug transaction
      await provider.addTransaction(CashTransaction(
        type: 'expense',
        amount: 500,
        category: 'Food',
        date: DateTime(2026, 8, 15),
        note: 'Aug lunch',
      ));

      // Sep transactions (2 items)
      await provider.addTransaction(CashTransaction(
        type: 'income',
        amount: 20000,
        category: 'Salary',
        date: DateTime(2026, 9, 1),
        note: 'Sep salary',
      ));
      await provider.addTransaction(CashTransaction(
        type: 'expense',
        amount: 1000,
        category: 'Transport',
        date: DateTime(2026, 9, 5),
        note: 'Sep bus',
      ));

      // Oct transaction
      await provider.addTransaction(CashTransaction(
        type: 'expense',
        amount: 300,
        category: 'Coffee',
        date: DateTime(2026, 10, 1),
        note: 'Oct coffee',
      ));

      expect(provider.transactions.length, equals(4));

      // Delete only Sep 2026 transactions
      final deleted = await provider.deleteMonthTransactions(DateTime(2026, 9));
      expect(deleted, isTrue);

      expect(provider.transactions.length, equals(2));
      expect(provider.transactions.any((t) => t.note == 'Aug lunch'), isTrue);
      expect(provider.transactions.any((t) => t.note == 'Oct coffee'), isTrue);
      expect(provider.transactions.any((t) => t.note.startsWith('Sep')), isFalse);
    });

    test('deleteCustomBookTransactions deletes only custom book transactions and removes book', () async {
      final db = FakeTransactionDbService();
      final provider = TransactionProvider(db);

      await provider.createCustomBook('Trip to Cox');

      // Regular monthly tx
      await provider.addTransaction(CashTransaction(
        type: 'income',
        amount: 10000,
        category: 'Salary',
        date: DateTime(2026, 9, 1),
        note: 'Monthly salary',
      ));

      // Custom book tx (tagged with [Book: Trip to Cox])
      await provider.addTransaction(CashTransaction(
        type: 'expense',
        amount: 3500,
        category: 'Travel',
        date: DateTime(2026, 9, 2),
        note: 'Hotel booking [Book: Trip to Cox]',
      ));

      expect(provider.transactions.length, equals(2));
      expect(provider.customBooks, contains('Trip to Cox'));

      // Delete the custom book and all its transactions
      final deleted = await provider.deleteCustomBookTransactions('Trip to Cox');
      expect(deleted, isTrue);

      expect(provider.transactions.length, equals(1));
      expect(provider.transactions.first.note, equals('Monthly salary'));
      expect(provider.customBooks, isNot(contains('Trip to Cox')));
    });
  });
}
