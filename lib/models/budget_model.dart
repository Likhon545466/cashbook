class CashBudget {
  final int? id;
  final String category;
  final int amount;
  final int year;
  final int month;

  const CashBudget({
    this.id,
    required this.category,
    required this.amount,
    required this.year,
    required this.month,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'year': year,
      'month': month,
    };
  }

  factory CashBudget.fromMap(Map<String, Object?> map) {
    return CashBudget(
      id: map['id'] as int?,
      category: map['category'] as String,
      amount: map['amount'] as int,
      year: map['year'] as int,
      month: map['month'] as int,
    );
  }
}
