class SavingsTransfer {
  final int? id;
  final String type;
  final int amount;
  final DateTime date;
  final String note;

  const SavingsTransfer({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
  });

  bool get isDeposit => type == 'deposit';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory SavingsTransfer.fromMap(Map<String, Object?> map) {
    return SavingsTransfer(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: map['amount'] as int,
      date: DateTime.parse(map['date'] as String),
      note: (map['note'] as String?) ?? '',
    );
  }
}
