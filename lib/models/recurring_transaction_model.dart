class RecurringTransaction {
  final int? id;
  final String title;
  final int amount;
  final String type; // 'income' or 'expense'
  final String category;
  final int dayOfMonth; // 1 to 31
  final String? customBook;
  final String note;
  final String? lastAppliedMonth; // e.g. "2026-09"
  final bool isActive;

  const RecurringTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.dayOfMonth,
    this.customBook,
    this.note = '',
    this.lastAppliedMonth,
    this.isActive = true,
  });

  bool get isIncome => type == 'income';

  String get cleanTitle => title.trim();

  bool isDueForMonth(DateTime month) {
    if (!isActive) return false;
    final currentKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    if (lastAppliedMonth == currentKey) return false;
    return month.day >= dayOfMonth;
  }

  RecurringTransaction copyWith({
    int? id,
    String? title,
    int? amount,
    String? type,
    String? category,
    int? dayOfMonth,
    String? customBook,
    String? note,
    String? lastAppliedMonth,
    bool clearLastAppliedMonth = false,
    bool? isActive,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      customBook: customBook ?? this.customBook,
      note: note ?? this.note,
      lastAppliedMonth: clearLastAppliedMonth
          ? null
          : (lastAppliedMonth ?? this.lastAppliedMonth),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'dayOfMonth': dayOfMonth,
      'customBook': customBook,
      'note': note,
      'lastAppliedMonth': lastAppliedMonth,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      amount: map['amount'] as int? ?? 0,
      type: map['type'] as String? ?? 'expense',
      category: map['category'] as String? ?? 'General',
      dayOfMonth: map['dayOfMonth'] as int? ?? 1,
      customBook: map['customBook'] as String?,
      note: map['note'] as String? ?? '',
      lastAppliedMonth: map['lastAppliedMonth'] as String?,
      isActive: (map['isActive'] as int? ?? 1) == 1,
    );
  }
}
