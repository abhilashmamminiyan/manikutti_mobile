class TransactionModel {
  final int? id;
  final String date;
  final double amount;
  final String category;
  final String note;
  final bool isPaid;
  final String type; // 'Expense' | 'Income' | 'Family'
  final String? addedBy;
  final String? familyCode;
  final bool synced;

  TransactionModel({
    this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.note,
    this.isPaid = true,
    required this.type,
    this.addedBy,
    this.familyCode,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'category': category,
      'note': note,
      'isPaid': isPaid ? 1 : 0,
      'type': type,
      'addedBy': addedBy,
      'familyCode': familyCode,
      'synced': synced ? 1 : 0,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      date: map['date'],
      amount: map['amount'],
      category: map['category'],
      note: map['note'],
      isPaid: map['isPaid'] == 1,
      type: map['type'],
      addedBy: map['addedBy'],
      familyCode: map['familyCode'],
      synced: map['synced'] == 1,
    );
  }

  TransactionModel copyWith({
    int? id,
    String? date,
    double? amount,
    String? category,
    String? note,
    bool? isPaid,
    String? type,
    String? addedBy,
    String? familyCode,
    bool? synced,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      isPaid: isPaid ?? this.isPaid,
      type: type ?? this.type,
      addedBy: addedBy ?? this.addedBy,
      familyCode: familyCode ?? this.familyCode,
      synced: synced ?? this.synced,
    );
  }
}
