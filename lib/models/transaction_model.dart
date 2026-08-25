class CashTransaction {
  final int? id;
  final String type;
  final int amount;
  final String category;
  final DateTime date;
  final String note;

  const CashTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  bool get isIncome => type == 'income';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory CashTransaction.fromMap(Map<String, Object?> map) {
    return CashTransaction(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: map['amount'] as int,
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      note: (map['note'] as String?) ?? '',
    );
  }

  CashTransaction copyWith({
    int? id,
    String? type,
    int? amount,
    String? category,
    DateTime? date,
    String? note,
  }) {
    return CashTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}
