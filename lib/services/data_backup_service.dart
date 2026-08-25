import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/debt_model.dart';
import '../models/debt_due_extension_model.dart';
import '../models/debt_payment_model.dart';
import '../models/savings_transfer_model.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';

class DataBackupService {
  DataBackupService(this._databaseService);

  final DatabaseService _databaseService;

  Future<File> _writeTempFile({
    required String name,
    required String contents,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');
    return file.writeAsString(contents, flush: true);
  }

  Future<void> shareBackup() async {
    final transactions = await _databaseService.getTransactions();
    final categories = await _databaseService.getCustomCategories();
    final settings = await _databaseService.getAllSettings();
    final budgets = await _databaseService.getAllBudgets();
    final savings = await _databaseService.getSavingsTransfers();
    final debts = await _databaseService.getDebts();
    final debtPayments = await _databaseService.getDebtPayments();
    final debtDueExtensions = await _databaseService.getDebtDueExtensions();

    final payload = {
      'app': 'CashBook',
      'backupVersion': 4,
      'createdAt': DateTime.now().toIso8601String(),
      'transactions': transactions.map((e) => e.toMap()).toList(),
      'customCategories': categories.map((e) => e.toMap()).toList(),
      'budgets': budgets.map((e) => e.toMap()).toList(),
      'savingsTransfers': savings.map((e) => e.toMap()).toList(),
      'debts': debts.map((e) => e.toMap()).toList(),
      'debtPayments': debtPayments.map((e) => e.toMap()).toList(),
      'debtDueExtensions': debtDueExtensions.map((e) => e.toMap()).toList(),
      'settings': settings,
    };

    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = await _writeTempFile(
      name: 'CashBook_backup_$stamp.json',
      contents: const JsonEncoder.withIndent('  ').convert(payload),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'CashBook Backup',
        text: 'CashBook local backup',
      ),
    );
  }

  Future<void> shareCsv() async {
    final transactions = await _databaseService.getTransactions();
    final buffer = StringBuffer()..writeln('Type,Amount,Category,Date,Note');

    for (final item in transactions) {
      buffer.writeln(
        [
          item.type,
          item.amount.toString(),
          item.category,
          DateFormat('yyyy-MM-dd').format(item.date),
          item.note,
        ].map(_csvCell).join(','),
      );
    }

    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = await _writeTempFile(
      name: 'CashBook_transactions_$stamp.csv',
      contents: buffer.toString(),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'CashBook CSV Export',
        text: 'CashBook transaction export',
      ),
    );
  }

  Future<void> sharePdfReport({
    DateTime? month,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if ((startDate == null) != (endDate == null)) {
      throw ArgumentError('Both startDate and endDate are required.');
    }

    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw ArgumentError('Start date cannot be after end date.');
    }
    final transactions = await _databaseService.getTransactions();
    final savings = await _databaseService.getSavingsTransfers();
    final debts = await _databaseService.getDebts();
    final debtPayments = await _databaseService.getDebtPayments();
    final debtDueExtensions = await _databaseService.getDebtDueExtensions();

    bool inPeriod(DateTime date) {
      if (month != null) return _sameMonth(date, month);

      if (startDate != null && endDate != null) {
        final day = DateTime(date.year, date.month, date.day);
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final end = DateTime(endDate.year, endDate.month, endDate.day);

        return !day.isBefore(start) && !day.isAfter(end);
      }

      return true;
    }

    final periodTransactions = transactions
        .where((item) => inPeriod(item.date))
        .toList();

    final periodSavings = savings.where((item) => inPeriod(item.date)).toList();

    final periodDebts = debts
        .where((item) => inPeriod(item.createdAt))
        .toList();

    final periodPayments = debtPayments
        .where((item) => inPeriod(item.date))
        .toList();

    final periodExtensions = debtDueExtensions
        .where((item) => inPeriod(item.changedAt))
        .toList();

    final debtById = {
      for (final debt in debts)
        if (debt.id != null) debt.id!: debt,
    };

    final ledger = <_PdfLedgerEntry>[
      ...periodTransactions.map(
        (item) => _PdfLedgerEntry(
          date: item.date,
          type: item.isIncome ? 'Cash In' : 'Cash Out',
          details: item.category,
          note: item.note,
          amount: item.amount,
        ),
      ),
      ...periodSavings.map(
        (item) => _PdfLedgerEntry(
          date: item.date,
          type: item.isDeposit ? 'Savings Add' : 'Savings Withdraw',
          details: 'Savings / Reserve',
          note: item.note,
          amount: item.amount,
        ),
      ),
      ...periodDebts.map(
        (item) => _PdfLedgerEntry(
          date: item.createdAt,
          type: item.isYouOwe ? 'You Owe' : 'Owed to You',
          details: item.person,
          note: item.note,
          amount: item.amount,
        ),
      ),
      ...periodPayments.map((payment) {
        final debt = debtById[payment.debtId];

        return _PdfLedgerEntry(
          date: payment.date,
          type: debt?.isYouOwe == true ? 'Debt Repayment' : 'Debt Collection',
          details: debt?.person ?? 'Debt Payment',
          note: payment.note,
          amount: payment.amount,
        );
      }),
      ...periodExtensions.map((extension) {
        final debt = debtById[extension.debtId];
        final oldDate = extension.oldDueDate == null
            ? 'No previous due date'
            : DateFormat('dd MMM yyyy').format(extension.oldDueDate!);
        final newDate = DateFormat('dd MMM yyyy').format(extension.newDueDate);

        return _PdfLedgerEntry(
          date: extension.changedAt,
          type: 'Due Date Extended',
          details: debt?.person ?? 'Debt',
          note:
              '$oldDate → $newDate'
              '${extension.note.isEmpty ? '' : ' • ${extension.note}'}',
          amount: 0,
        );
      }),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final income = periodTransactions
        .where((item) => item.isIncome)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final expense = periodTransactions
        .where((item) => !item.isIncome)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final savingsNet = periodSavings.fold<int>(
      0,
      (sum, item) => sum + (item.isDeposit ? item.amount : -item.amount),
    );
    final youOweAdded = periodDebts
        .where((item) => item.isYouOwe)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final owedToYouAdded = periodDebts
        .where((item) => !item.isYouOwe)
        .fold<int>(0, (sum, item) => sum + item.amount);
    final debtPaymentsTotal = periodPayments.fold<int>(
      0,
      (sum, item) => sum + item.amount,
    );

    final fonts = await _loadPdfFonts();
    final customRange = startDate != null && endDate != null;

    final reportTitle = customRange
        ? 'CashBook Custom Date Ledger'
        : month == null
        ? 'CashBook Full Ledger'
        : 'CashBook Monthly Summary';

    final periodLabel = customRange
        ? '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}'
        : month == null
        ? 'All recorded entries'
        : DateFormat('MMMM yyyy').format(month);

    final document = pw.Document(
      title: reportTitle,
      author: 'CashBook',
      creator: 'CashBook',
      theme: fonts.theme,
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 30),
        ),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 14),
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo700,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      reportTitle,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      periodLabel,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                DateFormat('dd MMM yyyy').format(DateTime.now()),
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by CashBook',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 9),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pdfSummaryCard('Income', _money(income), PdfColors.green700),
              _pdfSummaryCard('Expense', _money(expense), PdfColors.red700),
              _pdfSummaryCard(
                'Net Cash',
                _money(income - expense),
                income - expense >= 0 ? PdfColors.indigo700 : PdfColors.red700,
              ),
              _pdfSummaryCard(
                'Savings Net',
                _signedMoney(savingsNet),
                PdfColors.teal700,
              ),
              _pdfSummaryCard(
                'You Owe Added',
                _money(youOweAdded),
                PdfColors.deepOrange700,
              ),
              _pdfSummaryCard(
                'Owed to You Added',
                _money(owedToYouAdded),
                PdfColors.blue700,
              ),
              _pdfSummaryCard(
                'Debt Payments',
                _money(debtPaymentsTotal),
                PdfColors.amber800,
              ),
              _pdfSummaryCard(
                'Entries',
                ledger.length.toString(),
                PdfColors.purple700,
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            customRange
                ? 'Selected Date Entries'
                : month == null
                ? 'Full Ledger Entries'
                : 'Monthly Entries',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 9),
          if (ledger.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'No entries found for this period.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 10,
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Type', 'Details', 'Note', 'Amount'],
              data: ledger
                  .map(
                    (item) => [
                      DateFormat('dd MMM yy').format(item.date),
                      _pdfSafe(item.type, fonts.supportsBangla),
                      _pdfSafe(item.details, fonts.supportsBangla),
                      _pdfSafe(
                        item.note.isEmpty ? '-' : item.note,
                        fonts.supportsBangla,
                      ),
                      item.amount == 0 ? '-' : _money(item.amount),
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.indigo100,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.indigo900,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey900,
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.9),
                1: pw.FlexColumnWidth(1.15),
                2: pw.FlexColumnWidth(1.25),
                3: pw.FlexColumnWidth(1.7),
                4: pw.FlexColumnWidth(1.0),
              },
            ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              customRange
                  ? 'Custom report includes entries recorded from ${DateFormat('dd MMM yyyy').format(startDate)} to ${DateFormat('dd MMM yyyy').format(endDate)}.'
                  : month == null
                  ? 'Ledger includes cash transactions, savings transfers, debt creation and debt payments.'
                  : 'Monthly report includes entries recorded in ${DateFormat('MMMM yyyy').format(month)}.',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.indigo900,
              ),
            ),
          ),
        ],
      ),
    );

    final stamp = customRange
        ? '${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}'
        : month == null
        ? DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())
        : DateFormat('yyyyMM').format(month);

    final name = customRange
        ? 'CashBook_custom_$stamp.pdf'
        : month == null
        ? 'CashBook_full_ledger_$stamp.pdf'
        : 'CashBook_monthly_$stamp.pdf';

    final file = await _writeTempBytes(
      name: name,
      bytes: await document.save(),
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: reportTitle,
        text: '$reportTitle - $periodLabel',
      ),
    );
  }

  Future<File> _writeTempBytes({
    required String name,
    required Uint8List bytes,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<_PdfFonts> _loadPdfFonts() async {
    pw.Font? regular;
    pw.Font? bold;
    pw.Font? bangla;

    regular = await _tryLoadPdfFont(const [
      '/system/fonts/NotoSans-Regular.ttf',
      '/system/fonts/Roboto-Regular.ttf',
    ]);

    bold = await _tryLoadPdfFont(const [
      '/system/fonts/NotoSans-Bold.ttf',
      '/system/fonts/Roboto-Bold.ttf',
    ]);

    bangla = await _tryLoadPdfFont(const [
      '/system/fonts/NotoSansBengali-Regular.ttf',
      '/system/fonts/NotoSansBengaliUI-Regular.ttf',
      '/system/fonts/NotoSansBengali.ttf',
    ]);

    return _PdfFonts(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold ?? regular,
        fontFallback: [?bangla],
      ),
      supportsBangla: bangla != null,
    );
  }

  Future<pw.Font?> _tryLoadPdfFont(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        return pw.Font.ttf(ByteData.sublistView(bytes));
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  pw.Widget _pdfSummaryCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameMonth(DateTime date, DateTime month) {
    return date.year == month.year && date.month == month.month;
  }

  static String _money(int value) {
    return 'BDT ${NumberFormat('#,##0').format(value)}';
  }

  static String _signedMoney(int value) {
    if (value == 0) return _money(0);
    return '${value > 0 ? '+' : '-'}${_money(value.abs())}';
  }

  static String _pdfSafe(String value, bool supportsBangla) {
    if (supportsBangla) return value;

    final buffer = StringBuffer();

    for (final rune in value.runes) {
      if (rune == 10 || rune == 13 || (rune >= 32 && rune <= 255)) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write('?');
      }
    }

    return buffer.toString();
  }

  Future<BackupRestoreResult?> pickAndReadBackup() async {
    const typeGroup = XTypeGroup(
      label: 'CashBook Backup',
      extensions: ['json'],
    );

    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'CashBook') {
      throw const FormatException('Invalid CashBook backup.');
    }

    final version = decoded['backupVersion'];
    if (version != 1 && version != 2 && version != 3 && version != 4) {
      throw const FormatException('Unsupported backup version.');
    }

    final transactions = _list(
      decoded['transactions'],
    ).map((e) => CashTransaction.fromMap(e)).toList();

    final categories = _list(decoded['customCategories']).map((e) {
      final map = Map<String, Object?>.from(e)..['isDefault'] = 0;
      return CashCategory.fromMap(map);
    }).toList();

    final List<CashBudget>? budgets = version >= 2
        ? _list(decoded['budgets']).map(CashBudget.fromMap).toList()
        : null;

    final List<SavingsTransfer>? savings = version >= 2
        ? _list(
            decoded['savingsTransfers'],
          ).map(SavingsTransfer.fromMap).toList()
        : null;

    final List<DebtItem>? debts = version >= 3
        ? _list(decoded['debts']).map(DebtItem.fromMap).toList()
        : null;

    final List<DebtPayment>? debtPayments = version >= 3
        ? _list(decoded['debtPayments']).map(DebtPayment.fromMap).toList()
        : null;

    final List<DebtDueExtension>? debtDueExtensions = version >= 4
        ? _list(
            decoded['debtDueExtensions'],
          ).map(DebtDueExtension.fromMap).toList()
        : version >= 3
        ? const []
        : null;

    final rawSettings = decoded['settings'];
    if (rawSettings is! Map) {
      throw const FormatException('Backup settings are invalid.');
    }

    final settings = <String, String>{};
    for (final entry in rawSettings.entries) {
      if (entry.key is String && entry.value is String) {
        settings[entry.key as String] = entry.value as String;
      }
    }

    return BackupRestoreResult(
      transactions: transactions,
      customCategories: categories,
      budgets: budgets,
      savingsTransfers: savings,
      debts: debts,
      debtPayments: debtPayments,
      debtDueExtensions: debtDueExtensions,
      settings: settings,
    );
  }

  List<Map<String, Object?>> _list(Object? value) {
    if (value == null) return [];
    if (value is! List) {
      throw const FormatException('Backup data is incomplete.');
    }

    return value.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid backup item.');
      }
      return Map<String, Object?>.from(item);
    }).toList();
  }

  Future<void> restoreBackup(BackupRestoreResult backup) {
    return _databaseService.replaceFromBackup(
      transactions: backup.transactions,
      customCategories: backup.customCategories,
      settings: backup.settings,
      budgets: backup.budgets,
      savingsTransfers: backup.savingsTransfers,
      debts: backup.debts,
      debtPayments: backup.debtPayments,
      debtDueExtensions: backup.debtDueExtensions,
    );
  }

  Future<void> clearUserData() => _databaseService.clearUserData();

  Future<Map<String, int>> getStats() => _databaseService.getDatabaseStats();

  static String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }
}

class _PdfLedgerEntry {
  final DateTime date;
  final String type;
  final String details;
  final String note;
  final int amount;

  const _PdfLedgerEntry({
    required this.date,
    required this.type,
    required this.details,
    required this.note,
    required this.amount,
  });
}

class _PdfFonts {
  final pw.ThemeData theme;
  final bool supportsBangla;

  const _PdfFonts({required this.theme, required this.supportsBangla});
}

class BackupRestoreResult {
  final List<CashTransaction> transactions;
  final List<CashCategory> customCategories;
  final List<CashBudget>? budgets;
  final List<SavingsTransfer>? savingsTransfers;
  final List<DebtItem>? debts;
  final List<DebtPayment>? debtPayments;
  final List<DebtDueExtension>? debtDueExtensions;
  final Map<String, String> settings;

  const BackupRestoreResult({
    required this.transactions,
    required this.customCategories,
    required this.budgets,
    required this.savingsTransfers,
    required this.debts,
    required this.debtPayments,
    required this.debtDueExtensions,
    required this.settings,
  });
}
