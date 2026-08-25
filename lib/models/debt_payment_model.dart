class DebtPayment {
  final int? id;
  final int debtId;
  final int amount;
  final DateTime date;
  final String note;
  final String source;
  final int? transactionId;
  final int? savingsTransferId;

  const DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    required this.note,
    this.source = 'main',
    this.transactionId,
    this.savingsTransferId,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'debtId': debtId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'source': source,
      'transactionId': transactionId,
      'savingsTransferId': savingsTransferId,
    };
  }

  factory DebtPayment.fromMap(Map<String, Object?> map) {
    return DebtPayment(
      id: map['id'] as int?,
      debtId: map['debtId'] as int,
      amount: map['amount'] as int,
      date: DateTime.parse(map['date'] as String),
      note: (map['note'] as String?) ?? '',
      source: (map['source'] as String?) ?? 'main',
      transactionId: map['transactionId'] as int?,
      savingsTransferId: map['savingsTransferId'] as int?,
    );
  }

  DebtPayment copyWith({
    int? id,
    int? debtId,
    int? amount,
    DateTime? date,
    String? note,
    String? source,
    int? transactionId,
    int? savingsTransferId,
  }) {
    return DebtPayment(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      source: source ?? this.source,
      transactionId: transactionId ?? this.transactionId,
      savingsTransferId: savingsTransferId ?? this.savingsTransferId,
    );
  }
}
