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

class HomeLoanConfig {
  final String familyCode;
  final double principalAmount;
  final double interestRate;
  final String startDate;
  final double balanceRemaining;
  final double monthlyEMI;
  final int dueDay;
  final String payerName;
  final String shareRecipient;

  HomeLoanConfig({
    required this.familyCode,
    required this.principalAmount,
    required this.interestRate,
    required this.startDate,
    required this.balanceRemaining,
    required this.monthlyEMI,
    this.dueDay = 10,
    this.payerName = 'Ajesh',
    this.shareRecipient = 'Nisha',
  });

  factory HomeLoanConfig.fromJson(Map<String, dynamic> json) {
    return HomeLoanConfig(
      familyCode: json['familyCode']?.toString() ?? '',
      principalAmount: (json['principalAmount'] is num
          ? (json['principalAmount'] as num).toDouble()
          : double.tryParse(json['principalAmount']?.toString() ?? '') ?? 0.0),
      interestRate: (json['interestRate'] is num
          ? (json['interestRate'] as num).toDouble()
          : double.tryParse(json['interestRate']?.toString() ?? '') ?? 0.0),
      startDate: json['startDate']?.toString() ?? '',
      balanceRemaining: (json['balanceRemaining'] is num
          ? (json['balanceRemaining'] as num).toDouble()
          : double.tryParse(json['balanceRemaining']?.toString() ?? '') ?? 0.0),
      monthlyEMI: (json['monthlyEMI'] is num
          ? (json['monthlyEMI'] as num).toDouble()
          : double.tryParse(json['monthlyEMI']?.toString() ?? '') ?? 0.0),
      dueDay: json['dueDay'] is int
          ? json['dueDay']
          : int.tryParse(json['dueDay']?.toString() ?? '') ?? 10,
      payerName: (json['payerName']?.toString().trim().isNotEmpty == true)
          ? json['payerName'].toString().trim()
          : 'Ajesh',
      shareRecipient:
          (json['shareRecipient']?.toString().trim().isNotEmpty == true)
          ? json['shareRecipient'].toString().trim()
          : 'Nisha',
    );
  }
}

class EmiMonthlyTracking {
  final String monthKey;
  final String loanKey;
  final String familyCode;
  final bool paidToPayer;
  final String paidAt;
  final String paidBy;
  final bool sharedWithRecipient;
  final String sharedAt;
  final String sharedBy;
  final bool autoSmsDetected;
  final String note;

  EmiMonthlyTracking({
    required this.monthKey,
    required this.loanKey,
    required this.familyCode,
    required this.paidToPayer,
    this.paidAt = '',
    this.paidBy = '',
    required this.sharedWithRecipient,
    this.sharedAt = '',
    this.sharedBy = '',
    this.autoSmsDetected = false,
    this.note = '',
  });

  factory EmiMonthlyTracking.fromJson(Map<String, dynamic> json) {
    return EmiMonthlyTracking(
      monthKey: json['monthKey']?.toString() ?? '',
      loanKey: json['loanKey']?.toString() ?? '',
      familyCode: json['familyCode']?.toString() ?? '',
      paidToPayer: json['paidToPayer'] == true,
      paidAt: json['paidAt']?.toString() ?? '',
      paidBy: json['paidBy']?.toString() ?? '',
      sharedWithRecipient: json['sharedWithRecipient'] == true,
      sharedAt: json['sharedAt']?.toString() ?? '',
      sharedBy: json['sharedBy']?.toString() ?? '',
      autoSmsDetected: json['autoSmsDetected'] == true,
      note: json['note']?.toString() ?? '',
    );
  }
}
