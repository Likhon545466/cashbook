import 'database_service.dart';

class DataIntegrityService {
  DataIntegrityService(this._databaseService);

  final DatabaseService _databaseService;

  Future<DataIntegrityResult> run() async {
    final db = await _databaseService.database;
    final issues = <DataIntegrityIssue>[];

    final integrityRows = await db.rawQuery('PRAGMA integrity_check');
    final integrityOk =
        integrityRows.length == 1 &&
        integrityRows.first.values.isNotEmpty &&
        integrityRows.first.values.first.toString().toLowerCase() == 'ok';

    if (!integrityOk) {
      issues.add(
        const DataIntegrityIssue(
          title: 'SQLite integrity check failed',
          detail: 'The database reported an internal consistency problem.',
          severity: DataIntegritySeverity.critical,
        ),
      );
    }

    final foreignKeyRows = await db.rawQuery('PRAGMA foreign_key_check');
    if (foreignKeyRows.isNotEmpty) {
      issues.add(
        DataIntegrityIssue(
          title: 'Broken debt payment links',
          detail:
              '${foreignKeyRows.length} foreign-key issue${foreignKeyRows.length == 1 ? '' : 's'} found.',
          severity: DataIntegritySeverity.critical,
        ),
      );
    }

    final invalidTransactions = await _count(
      "SELECT COUNT(*) FROM transactions WHERE amount <= 0 "
      "OR type NOT IN ('income', 'expense')",
    );
    if (invalidTransactions > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Invalid cash transactions',
          detail:
              '$invalidTransactions transaction${invalidTransactions == 1 ? '' : 's'} has an invalid amount or type.',
          severity: DataIntegritySeverity.warning,
        ),
      );
    }

    final invalidBudgets = await _count(
      'SELECT COUNT(*) FROM budgets WHERE amount <= 0 OR month < 1 OR month > 12',
    );
    if (invalidBudgets > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Invalid budgets',
          detail:
              '$invalidBudgets budget${invalidBudgets == 1 ? '' : 's'} has an invalid amount or month.',
          severity: DataIntegritySeverity.warning,
        ),
      );
    }

    final invalidSavings = await _count(
      "SELECT COUNT(*) FROM savings_transfers WHERE amount <= 0 "
      "OR type NOT IN ('deposit', 'withdraw')",
    );
    if (invalidSavings > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Invalid savings entries',
          detail:
              '$invalidSavings savings entr${invalidSavings == 1 ? 'y' : 'ies'} has an invalid amount or type.',
          severity: DataIntegritySeverity.warning,
        ),
      );
    }

    final savingsBalanceRows = await db.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount "
      "WHEN type = 'withdraw' THEN -amount ELSE 0 END), 0) AS balance "
      'FROM savings_transfers',
    );
    final savingsBalance =
        (savingsBalanceRows.first['balance'] as num?)?.toInt() ?? 0;

    if (savingsBalance < 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Savings balance is negative',
          detail:
              'Savings history produces a balance of ৳${savingsBalance.abs()}.',
          severity: DataIntegritySeverity.critical,
        ),
      );
    }

    final invalidDebts = await _count(
      "SELECT COUNT(*) FROM debts WHERE amount <= 0 "
      "OR TRIM(person) = '' "
      "OR direction NOT IN ('you_owe', 'owed_to_you')",
    );
    if (invalidDebts > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Invalid debt records',
          detail:
              '$invalidDebts debt record${invalidDebts == 1 ? '' : 's'} has invalid core data.',
          severity: DataIntegritySeverity.warning,
        ),
      );
    }

    final invalidPayments = await _count(
      'SELECT COUNT(*) FROM debt_payments WHERE amount <= 0',
    );
    if (invalidPayments > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Invalid debt payments',
          detail:
              '$invalidPayments payment${invalidPayments == 1 ? '' : 's'} has an invalid amount.',
          severity: DataIntegritySeverity.warning,
        ),
      );
    }

    final orphanPayments = await _count(
      'SELECT COUNT(*) FROM debt_payments p '
      'LEFT JOIN debts d ON d.id = p.debtId '
      'WHERE d.id IS NULL',
    );
    if (orphanPayments > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Orphan debt payments',
          detail:
              '$orphanPayments payment${orphanPayments == 1 ? '' : 's'} is not linked to an existing debt.',
          severity: DataIntegritySeverity.critical,
        ),
      );
    }

    final orphanExtensions = await _count(
      'SELECT COUNT(*) FROM debt_due_extensions e '
      'LEFT JOIN debts d ON d.id = e.debtId '
      'WHERE d.id IS NULL',
    );
    if (orphanExtensions > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Orphan due-date extensions',
          detail:
              '$orphanExtensions extension record${orphanExtensions == 1 ? '' : 's'} is not linked to an existing debt.',
          severity: DataIntegritySeverity.critical,
        ),
      );
    }

    final invalidExtensions = await _count(
      'SELECT COUNT(*) FROM debt_due_extensions '
      'WHERE oldDueDate IS NOT NULL '
      'AND datetime(newDueDate) <= datetime(oldDueDate)',
    );
    if (invalidExtensions > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Invalid due-date extension history',
          detail:
              '$invalidExtensions extension${invalidExtensions == 1 ? '' : 's'} has an invalid date sequence.',
          severity: DataIntegritySeverity.warning,
        ),
      );
    }

    final overpaidDebts = await _count(
      'SELECT COUNT(*) FROM debts d '
      'WHERE COALESCE(('
      'SELECT SUM(p.amount) FROM debt_payments p WHERE p.debtId = d.id'
      '), 0) > d.amount',
    );
    if (overpaidDebts > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Debt overpayment detected',
          detail:
              '$overpaidDebts debt${overpaidDebts == 1 ? '' : 's'} has payments greater than the original amount.',
          severity: DataIntegritySeverity.critical,
        ),
      );
    }

    final paymentBeforeDebt = await _count(
      'SELECT COUNT(*) FROM debt_payments p '
      'JOIN debts d ON d.id = p.debtId '
      'WHERE datetime(p.date) < datetime(d.createdAt)',
    );
    if (paymentBeforeDebt > 0) {
      issues.add(
        DataIntegrityIssue(
          title: 'Payment date before debt date',
          detail:
              '$paymentBeforeDebt payment${paymentBeforeDebt == 1 ? '' : 's'} is dated before its debt was created.',
          severity: DataIntegritySeverity.warning,
        ),
      );
    }

    final stats = await _databaseService.getDatabaseStats();

    return DataIntegrityResult(
      checkedAt: DateTime.now(),
      issues: issues,
      transactionCount: stats['transactions'] ?? 0,
      savingsTransferCount: stats['savingsTransfers'] ?? 0,
      debtCount: stats['debts'] ?? 0,
      debtPaymentCount: stats['debtPayments'] ?? 0,
      debtDueExtensionCount: stats['debtDueExtensions'] ?? 0,
    );
  }

  Future<int> _count(String sql) async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery(sql);
    if (rows.isEmpty || rows.first.values.isEmpty) return 0;
    return (rows.first.values.first as num?)?.toInt() ?? 0;
  }
}

enum DataIntegritySeverity { warning, critical }

class DataIntegrityIssue {
  final String title;
  final String detail;
  final DataIntegritySeverity severity;

  const DataIntegrityIssue({
    required this.title,
    required this.detail,
    required this.severity,
  });
}

class DataIntegrityResult {
  final DateTime checkedAt;
  final List<DataIntegrityIssue> issues;
  final int transactionCount;
  final int savingsTransferCount;
  final int debtCount;
  final int debtPaymentCount;
  final int debtDueExtensionCount;

  const DataIntegrityResult({
    required this.checkedAt,
    required this.issues,
    required this.transactionCount,
    required this.savingsTransferCount,
    required this.debtCount,
    required this.debtPaymentCount,
    required this.debtDueExtensionCount,
  });

  bool get healthy => issues.isEmpty;

  int get checkedRecords =>
      transactionCount +
      savingsTransferCount +
      debtCount +
      debtPaymentCount +
      debtDueExtensionCount;

  int get criticalCount => issues
      .where((issue) => issue.severity == DataIntegritySeverity.critical)
      .length;

  int get warningCount => issues
      .where((issue) => issue.severity == DataIntegritySeverity.warning)
      .length;
}
