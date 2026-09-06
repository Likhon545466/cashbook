import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction_model.dart';
import '../utils/money_formatter.dart';

class StatementExportService {
  StatementExportService._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  /// Prompts the user with a sleek bottom sheet to choose between PDF or Excel/CSV export.
  static Future<void> showExportSheet(
    BuildContext context, {
    required String bookTitle,
    required List<CashTransaction> transactions,
    required int totalIncome,
    required int totalExpense,
  }) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.file_download_outlined,
                      color: scheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Statement',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Book: $bookTitle (${transactions.length} items)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                title: const Text(
                  'PDF Statement',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Clean printable summary with tables'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await exportPdfStatement(
                    bookTitle: bookTitle,
                    transactions: transactions,
                    totalIncome: totalIncome,
                    totalExpense: totalExpense,
                  );
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.table_chart_rounded,
                    color: Colors.green,
                  ),
                ),
                title: const Text(
                  'Excel / CSV Spreadsheet',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Structured raw data for Excel / Sheets'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await exportCsvStatement(
                    bookTitle: bookTitle,
                    transactions: transactions,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exports a beautifully styled PDF Statement.
  static Future<void> exportPdfStatement({
    required String bookTitle,
    required List<CashTransaction> transactions,
    required int totalIncome,
    required int totalExpense,
  }) async {
    final pdf = pw.Document();
    final netBalance = totalIncome - totalExpense;
    final currencyText =
        MoneyFormatter.currencySymbol == '৳' ? 'Tk ' : MoneyFormatter.currencySymbol;

    final sortedList = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    final fonts = await _loadPdfFonts();

    pdf.addPage(
      pw.MultiPage(
        theme: fonts.theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CashBook Statement',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Book: $bookTitle',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey600,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Generated on',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    _dateFormat.format(DateTime.now()),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 14),

          // Summary Cards
          pw.Row(
            children: [
              _buildSummaryCard(
                title: 'Total Income',
                amount: '$currencyText${MoneyFormatter.amount(totalIncome)}',
                bgColor: PdfColors.green50,
                borderColor: PdfColors.green300,
                textColor: PdfColors.green800,
              ),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                title: 'Total Expense',
                amount: '$currencyText${MoneyFormatter.amount(totalExpense)}',
                bgColor: PdfColors.red50,
                borderColor: PdfColors.red300,
                textColor: PdfColors.red800,
              ),
              pw.SizedBox(width: 12),
              _buildSummaryCard(
                title: 'Net Balance',
                amount: '$currencyText${MoneyFormatter.amount(netBalance)}',
                bgColor: netBalance >= 0 ? PdfColors.blue50 : PdfColors.amber50,
                borderColor:
                    netBalance >= 0 ? PdfColors.blue300 : PdfColors.amber300,
                textColor:
                    netBalance >= 0 ? PdfColors.blue800 : PdfColors.amber900,
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Itemized Table
          pw.Text(
            'Itemized Transactions (${sortedList.length})',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 8),

          if (sortedList.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 24),
              child: pw.Center(
                child: pw.Text(
                  'No transactions found in this book.',
                  style: const pw.TextStyle(color: PdfColors.grey600),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Note', 'Type', 'Amount'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              data: sortedList.map((t) {
                final isInc = t.isIncome;
                final sign = isInc ? '+' : '-';
                return [
                  _displayDateFormat.format(t.date),
                  _pdfSafe(t.category, fonts.supportsBangla),
                  _pdfSafe(t.note.isEmpty ? '-' : t.note, fonts.supportsBangla),
                  isInc ? 'Income' : 'Expense',
                  '$sign$currencyText${MoneyFormatter.amount(t.amount)}',
                ];
              }).toList(),
            ),

          pw.SizedBox(height: 24),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Report generated by CashBook App',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey500,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final safeTitle = bookTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final file = File(
      '${dir.path}/Statement_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'CashBook Statement - $bookTitle',
        text: 'Here is the CashBook statement for $bookTitle.',
      ),
    );
  }

  /// Exports an Excel-compatible CSV file.
  static Future<void> exportCsvStatement({
    required String bookTitle,
    required List<CashTransaction> transactions,
  }) async {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Date,Type,Category,Amount,Note,Book');

    final sortedList = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final t in sortedList) {
      final dateStr = DateFormat('yyyy-MM-dd').format(t.date);
      final typeStr = t.isIncome ? 'Income' : 'Expense';
      final catStr = _csvEscape(t.category);
      final amtStr = t.amount.toString();
      final noteStr = _csvEscape(t.note);
      final bookStr = _csvEscape(t.customBook ?? bookTitle);

      buffer.writeln('$dateStr,$typeStr,$catStr,$amtStr,$noteStr,$bookStr');
    }

    final dir = await getTemporaryDirectory();
    final safeTitle = bookTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final file = File(
      '${dir.path}/Statement_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'CashBook Data - $bookTitle',
        text: 'Exported transaction spreadsheet for $bookTitle.',
      ),
    );
  }

  static pw.Widget _buildSummaryCard({
    required String title,
    required String amount,
    required PdfColor bgColor,
    required PdfColor borderColor,
    required PdfColor textColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: borderColor, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              amount,
              style: pw.TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _csvEscape(String text) {
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static Future<_PdfFontConfig> _loadPdfFonts() async {
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

    return _PdfFontConfig(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold ?? regular,
        fontFallback: [?bangla],
      ),
      supportsBangla: bangla != null,
    );
  }

  static Future<pw.Font?> _tryLoadPdfFont(List<String> paths) async {
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
}

class _PdfFontConfig {
  final pw.ThemeData theme;
  final bool supportsBangla;

  _PdfFontConfig({required this.theme, required this.supportsBangla});
}
