class HomeLoanEntry {
  final int? id;
  final String date;
  final double totalPayment;
  final double principal;
  final double interest;
  final double balance;
  final String familyCode;
  final String addedBy;

  HomeLoanEntry({
    this.id,
    required this.date,
    required this.totalPayment,
    required this.principal,
    required this.interest,
    required this.balance,
    this.familyCode = '',
    this.addedBy = '',
  });

  factory HomeLoanEntry.fromJson(Map<String, dynamic> json) {
    return HomeLoanEntry(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      date: json['date']?.toString() ?? '',
      totalPayment: (json['totalPayment'] is num
          ? (json['totalPayment'] as num).toDouble()
          : double.tryParse(json['totalPayment']?.toString() ?? '') ?? 0.0),
      principal: (json['principal'] is num
          ? (json['principal'] as num).toDouble()
          : double.tryParse(json['principal']?.toString() ?? '') ?? 0.0),
      interest: (json['interest'] is num
          ? (json['interest'] as num).toDouble()
          : double.tryParse(json['interest']?.toString() ?? '') ?? 0.0),
      balance: (json['balance'] is num
          ? (json['balance'] as num).toDouble()
          : double.tryParse(json['balance']?.toString() ?? '') ?? 0.0),
      familyCode: json['familyCode']?.toString() ?? '',
      addedBy: json['addedBy']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'totalPayment': totalPayment,
      'principal': principal,
      'interest': interest,
      'balance': balance,
      'familyCode': familyCode,
      if (addedBy.isNotEmpty) 'addedBy': addedBy,
    };
  }

  HomeLoanEntry copyWith({
    int? id,
    String? date,
    double? totalPayment,
    double? principal,
    double? interest,
    double? balance,
    String? familyCode,
    String? addedBy,
  }) {
    return HomeLoanEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      totalPayment: totalPayment ?? this.totalPayment,
      principal: principal ?? this.principal,
      interest: interest ?? this.interest,
      balance: balance ?? this.balance,
      familyCode: familyCode ?? this.familyCode,
      addedBy: addedBy ?? this.addedBy,
    );
  }
}
