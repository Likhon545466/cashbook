class DebtDueExtension {
  final int? id;
  final int debtId;
  final DateTime? oldDueDate;
  final DateTime newDueDate;
  final DateTime changedAt;
  final String note;

  const DebtDueExtension({
    this.id,
    required this.debtId,
    required this.oldDueDate,
    required this.newDueDate,
    required this.changedAt,
    this.note = '',
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'debtId': debtId,
      'oldDueDate': oldDueDate?.toIso8601String(),
      'newDueDate': newDueDate.toIso8601String(),
      'changedAt': changedAt.toIso8601String(),
      'note': note,
    };
  }

  factory DebtDueExtension.fromMap(Map<String, Object?> map) {
    final rawOld = map['oldDueDate'] as String?;

    return DebtDueExtension(
      id: map['id'] as int?,
      debtId: map['debtId'] as int,
      oldDueDate: rawOld == null || rawOld.isEmpty
          ? null
          : DateTime.parse(rawOld),
      newDueDate: DateTime.parse(map['newDueDate'] as String),
      changedAt: DateTime.parse(map['changedAt'] as String),
      note: (map['note'] as String?) ?? '',
    );
  }
}
