import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';

class CsvImportRow {
  final DateTime date;
  final String type; // 'income' | 'expense'
  final int amount;
  final String category;
  final String note;
  final bool isDuplicate;
  final bool isValid;
  final String? errorMessage;

  const CsvImportRow({
    required this.date,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    this.isDuplicate = false,
    this.isValid = true,
    this.errorMessage,
  });

  CashTransaction toTransaction() {
    return CashTransaction(
      type: type,
      amount: amount,
      category: category,
      date: date,
      note: note,
    );
  }
}

class CsvImportPreview {
  final List<CsvImportRow> rows;
  final int totalRows;
  final int validCount;
  final int duplicateCount;
  final int invalidCount;
  final Set<String> discoveredCategories;

  const CsvImportPreview({
    required this.rows,
    required this.totalRows,
    required this.validCount,
    required this.duplicateCount,
    required this.invalidCount,
    required this.discoveredCategories,
  });
}

class CsvImportService {
  final DatabaseService _databaseService;

  CsvImportService(this._databaseService);

  static CsvImportPreview parseCsv(
    String content, {
    List<CashTransaction> existingTransactions = const [],
  }) {
    final lines = _splitCsvLines(content);
    if (lines.isEmpty) {
      return const CsvImportPreview(
        rows: [],
        totalRows: 0,
        validCount: 0,
        duplicateCount: 0,
        invalidCount: 0,
        discoveredCategories: {},
      );
    }

    final headerRow = lines.first;
    final headerIndexMap = _mapHeaders(headerRow);

    final rows = <CsvImportRow>[];
    final discoveredCategories = <String>{};

    for (var i = 1; i < lines.length; i++) {
      final lineTokens = lines[i];
      if (lineTokens.isEmpty || (lineTokens.length == 1 && lineTokens[0].trim().isEmpty)) {
        continue;
      }

      final parsedRow = _parseLine(
        tokens: lineTokens,
        headers: headerIndexMap,
        existing: existingTransactions,
      );

      if (parsedRow != null) {
        rows.add(parsedRow);
        if (parsedRow.isValid && parsedRow.category.isNotEmpty) {
          discoveredCategories.add(parsedRow.category);
        }
      }
    }

    final total = rows.length;
    final valid = rows.where((r) => r.isValid && !r.isDuplicate).length;
    final dupes = rows.where((r) => r.isValid && r.isDuplicate).length;
    final invalid = rows.where((r) => !r.isValid).length;

    return CsvImportPreview(
      rows: rows,
      totalRows: total,
      validCount: valid,
      duplicateCount: dupes,
      invalidCount: invalid,
      discoveredCategories: discoveredCategories,
    );
  }

  Future<int> executeImport(List<CsvImportRow> rowsToImport) async {
    final validRows = rowsToImport.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return 0;

    final db = await _databaseService.database;
    var importedCount = 0;

    await db.transaction((txn) async {
      // 1. Ensure custom categories exist
      final existingCatRows = await txn.query('custom_categories');
      final existingCategories = existingCatRows
          .map((r) => (r['name'] as String).toLowerCase())
          .toSet();

      for (final row in validRows) {
        final catLower = row.category.trim().toLowerCase();
        if (catLower.isNotEmpty && !existingCategories.contains(catLower)) {
          await txn.insert('custom_categories', {
            'name': row.category.trim(),
            'type': row.type,
            'isDefault': 0,
          });
          existingCategories.add(catLower);
        }
      }

      // 2. Insert transactions
      for (final row in validRows) {
        await txn.insert('transactions', {
          'type': row.type,
          'amount': row.amount,
          'category': row.category.trim(),
          'date': row.date.toIso8601String(),
          'note': row.note.trim(),
        });
        importedCount++;
      }
    });

    return importedCount;
  }

  static Map<String, int> _mapHeaders(List<String> header) {
    final map = <String, int>{};

    for (var i = 0; i < header.length; i++) {
      final key = header[i].trim().toLowerCase();

      if (key == 'date' || key == 'datetime' || key == 'time' || key == 'timestamp' || key.contains('date')) {
        map['date'] ??= i;
      } else if (key == 'type' || key == 'direction' || key == 'transaction type' || key == 'entry') {
        map['type'] ??= i;
      } else if (key == 'amount' || key == 'value' || key == 'cost' || key == 'total' || key == 'price' || key.contains('amount')) {
        map['amount'] ??= i;
      } else if (key == 'category' || key == 'group' || key == 'tag' || key == 'label') {
        map['category'] ??= i;
      } else if (key == 'note' || key == 'description' || key == 'remark' || key == 'memo' || key == 'details' || key == 'comment') {
        map['note'] ??= i;
      }
    }

    // Default column fallback if unlabelled: Date=0, Type=1, Amount=2, Category=3, Note=4
    map['date'] ??= 0;
    map['type'] ??= 1;
    map['amount'] ??= 2;
    map['category'] ??= 3;
    map['note'] ??= 4;

    return map;
  }

  static CsvImportRow? _parseLine({
    required List<String> tokens,
    required Map<String, int> headers,
    required List<CashTransaction> existing,
  }) {
    String getVal(String key) {
      final idx = headers[key];
      if (idx == null || idx >= tokens.length) return '';
      return tokens[idx].trim();
    }

    final rawDate = getVal('date');
    final rawType = getVal('type');
    final rawAmount = getVal('amount');
    final rawCategory = getVal('category');
    final rawNote = getVal('note');

    // Parse Date
    final date = _parseDate(rawDate);
    if (date == null) {
      return CsvImportRow(
        date: DateTime.now(),
        type: 'expense',
        amount: 0,
        category: rawCategory,
        note: rawNote,
        isValid: false,
        errorMessage: 'Invalid date format: "$rawDate"',
      );
    }

    // Parse Amount
    final amount = _parseAmount(rawAmount);
    if (amount == null || amount <= 0) {
      return CsvImportRow(
        date: date,
        type: 'expense',
        amount: 0,
        category: rawCategory,
        note: rawNote,
        isValid: false,
        errorMessage: 'Invalid amount: "$rawAmount"',
      );
    }

    // Parse Type
    final type = _normalizeType(rawType, rawAmount);

    final category = rawCategory.isEmpty ? 'Other' : rawCategory;
    final note = rawNote;

    // Duplicate Check
    final isDuplicate = existing.any((tx) {
      final sameDay = tx.date.year == date.year &&
          tx.date.month == date.month &&
          tx.date.day == date.day;
      return sameDay &&
          tx.amount == amount &&
          tx.type == type &&
          tx.category.toLowerCase() == category.toLowerCase();
    });

    return CsvImportRow(
      date: date,
      type: type,
      amount: amount,
      category: category,
      note: note,
      isDuplicate: isDuplicate,
      isValid: true,
    );
  }

  static String _normalizeType(String rawType, String rawAmount) {
    final t = rawType.trim().toLowerCase();
    if (t == 'income' || t == 'credit' || t == 'deposit' || t == 'in' || t == '+') {
      return 'income';
    }
    if (t == 'expense' || t == 'debit' || t == 'withdrawal' || t == 'out' || t == '-') {
      return 'expense';
    }

    // Guess from negative/positive amount if type is missing
    if (rawAmount.trim().startsWith('-')) {
      return 'expense';
    }
    if (rawAmount.trim().startsWith('+')) {
      return 'income';
    }

    return 'expense';
  }

  static int? _parseAmount(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'[^0-9.-]'), '')
        .replaceAll(',', '');

    if (cleaned.startsWith('-')) {
      cleaned = cleaned.substring(1);
    }

    final parsedDouble = double.tryParse(cleaned);
    if (parsedDouble == null) return null;
    return parsedDouble.round();
  }

  static DateTime? _parseDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // 1. Try ISO8601
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    // 2. Formats to try
    final formats = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd/MM/yyyy',
      'MM/dd/yyyy HH:mm:ss',
      'MM/dd/yyyy HH:mm',
      'MM/dd/yyyy',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
      'd MMM yyyy',
      'MMM d, yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseLoose(text);
      } catch (_) {}
    }

    return null;
  }

  static List<List<String>> _splitCsvLines(String content) {
    final result = <List<String>>[];
    final currentToken = StringBuffer();
    var currentLine = <String>[];
    var inQuotes = false;

    for (var i = 0; i < content.length; i++) {
      final char = content[i];

      if (char == '"') {
        if (inQuotes && i + 1 < content.length && content[i + 1] == '"') {
          // Escaped quote: ""
          currentToken.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentLine.add(currentToken.toString());
        currentToken.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++; // Skip \n in CRLF
        }
        currentLine.add(currentToken.toString());
        currentToken.clear();
        if (currentLine.any((token) => token.trim().isNotEmpty)) {
          result.add(currentLine);
        }
        currentLine = [];
      } else {
        currentToken.write(char);
      }
    }

    if (currentToken.isNotEmpty || currentLine.isNotEmpty) {
      currentLine.add(currentToken.toString());
      if (currentLine.any((token) => token.trim().isNotEmpty)) {
        result.add(currentLine);
      }
    }

    return result;
  }
}
