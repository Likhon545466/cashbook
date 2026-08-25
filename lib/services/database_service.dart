import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/debt_model.dart';
import '../models/debt_due_extension_model.dart';
import '../models/debt_payment_model.dart';
import '../models/transaction_model.dart';
import '../models/savings_transfer_model.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cashbook.db');

    _database = await openDatabase(
      path,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTransactionsTable(db);
        await _createCategoriesTable(db);
        await _createSettingsTable(db);
        await _createBudgetsTable(db);
        await _createSavingsTransfersTable(db);
        await _createDebtsTable(db);
        await _createDebtPaymentsTable(db);
        await _createDebtDueExtensionsTable(db);
        await _seedDefaultCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCategoriesTable(db);
          await _seedDefaultCategories(db);
        }
        if (oldVersion < 3) {
          await _createSettingsTable(db);
        }
        if (oldVersion < 4) {
          await _createBudgetsTable(db);
        }
        if (oldVersion < 5) {
          await _createSavingsTransfersTable(db);
        }
        if (oldVersion < 6) {
          await _createDebtsTable(db);
          await _createDebtPaymentsTable(db);
        }
        if (oldVersion < 7) {
          await _createDebtDueExtensionsTable(db);
        }
        if (oldVersion < 8) {
          await db.execute(
            "ALTER TABLE debt_payments ADD COLUMN source TEXT NOT NULL DEFAULT 'main'",
          );
          await db.execute(
            "ALTER TABLE debt_payments ADD COLUMN transactionId INTEGER",
          );
          await db.execute(
            "ALTER TABLE debt_payments ADD COLUMN savingsTransferId INTEGER",
          );
        }
      },
    );

    return _database!;
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        UNIQUE(name, type)
      )
    ''');
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createBudgetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        UNIQUE(category, year, month)
      )
    ''');
  }

  Future<void> _createSavingsTransfersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS savings_transfers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _createDebtsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        direction TEXT NOT NULL,
        person TEXT NOT NULL,
        amount INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _createDebtPaymentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debtId INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'main',
        transactionId INTEGER,
        savingsTransferId INTEGER,
        FOREIGN KEY(debtId) REFERENCES debts(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createDebtDueExtensionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS debt_due_extensions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debtId INTEGER NOT NULL,
        oldDueDate TEXT,
        newDueDate TEXT NOT NULL,
        changedAt TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(debtId) REFERENCES debts(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _seedDefaultCategories(Database db) async {
    const income = ['Salary', 'Freelance', 'Business', 'Other Income'];
    const expense = [
      'Food',
      'Transport',
      'Shopping',
      'Bills',
      'Rent',
      'Health',
      'Entertainment',
      'Other',
    ];

    final batch = db.batch();

    for (final name in income) {
      batch.insert('categories', {
        'name': name,
        'type': 'income',
        'isDefault': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final name in expense) {
      batch.insert('categories', {
        'name': name,
        'type': 'expense',
        'isDefault': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }

  Future<List<CashTransaction>> getTransactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'date DESC, id DESC');
    return rows.map(CashTransaction.fromMap).toList();
  }

  Future<int> insertTransaction(CashTransaction transaction) async {
    final db = await database;
    final data = transaction.toMap()..remove('id');
    return db.insert('transactions', data);
  }

  Future<int> updateTransaction(CashTransaction transaction) async {
    if (transaction.id == null) return 0;

    final db = await database;
    final data = transaction.toMap()..remove('id');

    return db.update(
      'transactions',
      data,
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;

    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CashCategory>> getCategories() async {
    final db = await database;
    final rows = await db.query(
      'categories',
      orderBy: 'isDefault DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(CashCategory.fromMap).toList();
  }

  Future<int> insertCategory(CashCategory category) async {
    final db = await database;
    final data = category.toMap()..remove('id');

    return db.insert(
      'categories',
      data,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;

    return db.delete(
      'categories',
      where: 'id = ? AND isDefault = 0',
      whereArgs: [id],
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;

    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;

    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final rows = await db.query('settings');

    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<List<CashCategory>> getCustomCategories() async {
    final db = await database;
    final rows = await db.query(
      'categories',
      where: 'isDefault = 0',
      orderBy: 'type ASC, name COLLATE NOCASE ASC',
    );

    return rows.map(CashCategory.fromMap).toList();
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final transactionCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transactions'),
        ) ??
        0;

    final customCategoryCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM categories WHERE isDefault = 0',
          ),
        ) ??
        0;

    final savingsTransferCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM savings_transfers'),
        ) ??
        0;

    final debtCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM debts'),
        ) ??
        0;

    final debtPaymentCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM debt_payments'),
        ) ??
        0;

    final debtDueExtensionCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM debt_due_extensions'),
        ) ??
        0;

    return {
      'transactions': transactionCount,
      'customCategories': customCategoryCount,
      'savingsTransfers': savingsTransferCount,
      'debts': debtCount,
      'debtPayments': debtPaymentCount,
      'debtDueExtensions': debtDueExtensionCount,
    };
  }

  Future<List<CashBudget>> getBudgetsForMonth({
    required int year,
    required int month,
  }) async {
    final db = await database;

    final rows = await db.query(
      'budgets',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      orderBy: 'category COLLATE NOCASE ASC',
    );

    return rows.map(CashBudget.fromMap).toList();
  }

  Future<void> upsertBudget(CashBudget budget) async {
    final db = await database;
    final data = budget.toMap()..remove('id');

    await db.insert(
      'budgets',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBudget({
    required String category,
    required int year,
    required int month,
  }) async {
    final db = await database;

    await db.delete(
      'budgets',
      where: 'category = ? AND year = ? AND month = ?',
      whereArgs: [category, year, month],
    );
  }

  Future<List<CashBudget>> getAllBudgets() async {
    final db = await database;
    final rows = await db.query(
      'budgets',
      orderBy: 'year ASC, month ASC, category COLLATE NOCASE ASC',
    );
    return rows.map(CashBudget.fromMap).toList();
  }

  Future<List<SavingsTransfer>> getSavingsTransfers() async {
    final db = await database;
    final rows = await db.query(
      'savings_transfers',
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(SavingsTransfer.fromMap).toList();
  }

  Future<int> insertSavingsTransfer(SavingsTransfer item) async {
    final db = await database;
    final data = item.toMap()..remove('id');
    return db.insert('savings_transfers', data);
  }

  Future<int> updateSavingsTransfer(SavingsTransfer item) async {
    if (item.id == null) return 0;

    final db = await database;
    final data = item.toMap()..remove('id');

    return db.update(
      'savings_transfers',
      data,
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteSavingsTransfer(int id) async {
    final db = await database;
    return db.delete('savings_transfers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DebtItem>> getDebts() async {
    final db = await database;
    final rows = await db.query('debts', orderBy: 'createdAt DESC, id DESC');
    return rows.map(DebtItem.fromMap).toList();
  }

  Future<int> insertDebt(DebtItem item) async {
    final db = await database;
    final data = item.toMap()..remove('id');
    return db.insert('debts', data);
  }

  Future<int> updateDebt(DebtItem item) async {
    if (item.id == null) return 0;

    final db = await database;
    final data = item.toMap()..remove('id');

    return db.update('debts', data, where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DebtPayment>> getDebtPayments() async {
    final db = await database;
    final rows = await db.query('debt_payments', orderBy: 'date DESC, id DESC');
    return rows.map(DebtPayment.fromMap).toList();
  }

  Future<int> insertDebtPayment(DebtPayment item) async {
    final db = await database;
    final data = item.toMap()..remove('id');
    return db.insert('debt_payments', data);
  }

  Future<int> deleteDebtPayment(int id) async {
    final db = await database;
    return db.delete('debt_payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DebtDueExtension>> getDebtDueExtensions() async {
    final db = await database;
    final rows = await db.query(
      'debt_due_extensions',
      orderBy: 'changedAt DESC, id DESC',
    );
    return rows.map(DebtDueExtension.fromMap).toList();
  }

  Future<int> insertDebtDueExtension(DebtDueExtension item) async {
    final db = await database;
    final data = item.toMap()..remove('id');
    return db.insert('debt_due_extensions', data);
  }

  Future<void> replaceFromBackup({
    required List<CashTransaction> transactions,
    required List<CashCategory> customCategories,
    required Map<String, String> settings,
    List<CashBudget>? budgets,
    List<SavingsTransfer>? savingsTransfers,
    List<DebtItem>? debts,
    List<DebtPayment>? debtPayments,
    List<DebtDueExtension>? debtDueExtensions,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('categories', where: 'isDefault = 0');
      await txn.delete('settings');

      if (budgets != null) {
        await txn.delete('budgets');
      }

      if (savingsTransfers != null) {
        await txn.delete('savings_transfers');
      }

      if (debts != null && debtPayments != null) {
        await txn.delete('debt_due_extensions');
        await txn.delete('debt_payments');
        await txn.delete('debts');
      }

      for (final category in customCategories) {
        final data = category.toMap()
          ..remove('id')
          ..['isDefault'] = 0;

        await txn.insert(
          'categories',
          data,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      for (final transaction in transactions) {
        final data = transaction.toMap()..remove('id');
        await txn.insert('transactions', data);
      }

      if (budgets != null) {
        for (final budget in budgets) {
          final data = budget.toMap()..remove('id');
          await txn.insert(
            'budgets',
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      if (savingsTransfers != null) {
        for (final item in savingsTransfers) {
          final data = item.toMap()..remove('id');
          await txn.insert('savings_transfers', data);
        }
      }

      if (debts != null && debtPayments != null) {
        final idMap = <int, int>{};

        for (final item in debts) {
          final oldId = item.id;
          final data = item.toMap()..remove('id');
          final newId = await txn.insert('debts', data);

          if (oldId != null) {
            idMap[oldId] = newId;
          }
        }

        for (final payment in debtPayments) {
          final mappedDebtId = idMap[payment.debtId];
          if (mappedDebtId == null) continue;

          final data = payment.toMap()
            ..remove('id')
            ..['debtId'] = mappedDebtId;

          await txn.insert('debt_payments', data);
        }

        if (debtDueExtensions != null) {
          for (final extension in debtDueExtensions) {
            final mappedDebtId = idMap[extension.debtId];
            if (mappedDebtId == null) continue;

            final data = extension.toMap()
              ..remove('id')
              ..['debtId'] = mappedDebtId;

            await txn.insert('debt_due_extensions', data);
          }
        }
      }

      for (final entry in settings.entries) {
        await txn.insert('settings', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> clearUserData() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('categories', where: 'isDefault = 0');
      await txn.delete('budgets');
      await txn.delete('savings_transfers');
      await txn.delete('debt_due_extensions');
      await txn.delete('debt_payments');
      await txn.delete('debts');
    });
  }
}
