class DebtItem {
  final int? id;
  final String direction;
  final String person;
  final int amount;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String note;

  const DebtItem({
    this.id,
    required this.direction,
    required this.person,
    required this.amount,
    required this.createdAt,
    this.dueDate,
    required this.note,
  });

  bool get isYouOwe => direction == 'you_owe';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'direction': direction,
      'person': person,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
    };
  }

  factory DebtItem.fromMap(Map<String, Object?> map) {
    final rawDueDate = map['dueDate'] as String?;

    return DebtItem(
      id: map['id'] as int?,
      direction: map['direction'] as String,
      person: map['person'] as String,
      amount: map['amount'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate: rawDueDate == null || rawDueDate.isEmpty
          ? null
          : DateTime.parse(rawDueDate),
      note: (map['note'] as String?) ?? '',
    );
  }

  DebtItem copyWith({
    int? id,
    String? direction,
    String? person,
    int? amount,
    DateTime? createdAt,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? note,
  }) {
    return DebtItem(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      person: person ?? this.person,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      note: note ?? this.note,
    );
  }
}
