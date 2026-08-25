class CashCategory {
  final int? id;
  final String name;
  final String type;
  final bool isDefault;

  const CashCategory({
    this.id,
    required this.name,
    required this.type,
    required this.isDefault,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'isDefault': isDefault ? 1 : 0,
  };

  factory CashCategory.fromMap(Map<String, Object?> map) {
    return CashCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      isDefault: (map['isDefault'] as int) == 1,
    );
  }
}
