class Loan {
  final int? id;
  final String name;
  final double amount;
  final double monthlyEMI;
  final String assignedTo;
  final String familyCode;
  final String adminEmail;
  final String status;
  final double interestRate;
  final String startDate;
  final double balanceRemaining;
  final int tenureMonths;
  final int paidMonths;
  final String payerName;
  final String shareRecipient;

  Loan({
    this.id,
    required this.name,
    required this.amount,
    required this.monthlyEMI,
    required this.assignedTo,
    required this.familyCode,
    this.adminEmail = '',
    this.status = 'Active',
    this.interestRate = 0.0,
    this.startDate = '',
    double? balanceRemaining,
    this.tenureMonths = 0,
    this.paidMonths = 0,
    this.payerName = 'Ajesh',
    this.shareRecipient = 'Nisha',
  }) : balanceRemaining = balanceRemaining ?? amount;

  factory Loan.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] is num
        ? (json['amount'] as num).toDouble()
        : double.tryParse(json['amount']?.toString() ?? '') ?? 0.0);
    final bal = json['balanceRemaining'] != null
        ? (json['balanceRemaining'] is num
            ? (json['balanceRemaining'] as num).toDouble()
            : double.tryParse(json['balanceRemaining']?.toString() ?? '') ?? amt)
        : amt;
    return Loan(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      amount: amt,
      monthlyEMI: (json['monthlyEMI'] is num
          ? (json['monthlyEMI'] as num).toDouble()
          : double.tryParse(json['monthlyEMI']?.toString() ?? '') ?? 0.0),
      assignedTo: json['assignedTo']?.toString() ?? '',
      familyCode: json['familyCode']?.toString() ?? '',
      adminEmail: json['adminEmail']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      interestRate: (json['interestRate'] is num
          ? (json['interestRate'] as num).toDouble()
          : double.tryParse(json['interestRate']?.toString() ?? '') ?? 0.0),
      startDate: json['startDate']?.toString() ?? '',
      balanceRemaining: bal,
      tenureMonths: json['tenureMonths'] is int
          ? json['tenureMonths']
          : int.tryParse(json['tenureMonths']?.toString() ?? '') ?? 0,
      paidMonths: json['paidMonths'] is int
          ? json['paidMonths']
          : int.tryParse(json['paidMonths']?.toString() ?? '') ?? 0,
      payerName: (json['payerName']?.toString().trim().isNotEmpty == true)
          ? json['payerName'].toString().trim()
          : 'Ajesh',
      shareRecipient:
          (json['shareRecipient']?.toString().trim().isNotEmpty == true)
              ? json['shareRecipient'].toString().trim()
              : 'Nisha',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'amount': amount,
      'monthlyEMI': monthlyEMI,
      'assignedTo': assignedTo,
      'familyCode': familyCode,
      'adminEmail': adminEmail,
      'status': status,
      'interestRate': interestRate,
      'startDate': startDate,
      'balanceRemaining': balanceRemaining,
      'tenureMonths': tenureMonths,
      'paidMonths': paidMonths,
      'payerName': payerName,
      'shareRecipient': shareRecipient,
    };
  }
}

class LoanExpense {
  final String date;
  final double amount;
  final String category;
  final String note;
  final String loanName;
  final String addedBy;
  final String familyCode;

  LoanExpense({
    required this.date,
    required this.amount,
    required this.category,
    required this.note,
    required this.loanName,
    required this.addedBy,
    required this.familyCode,
  });

  factory LoanExpense.fromJson(Map<String, dynamic> json) {
    return LoanExpense(
      date: json['date']?.toString() ?? '',
      amount: (json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0.0),
      category: json['category']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      loanName: json['loanName']?.toString() ?? '',
      addedBy: json['addedBy']?.toString() ?? '',
      familyCode: json['familyCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'amount': amount,
      'category': category,
      'note': note,
      'loanName': loanName,
      'addedBy': addedBy,
      'familyCode': familyCode,
    };
  }
}

class LoanRepayment {
  final String date;
  final double amount;
  final String loanName;
  final String paidBy;
  final String familyCode;

  LoanRepayment({
    required this.date,
    required this.amount,
    required this.loanName,
    required this.paidBy,
    required this.familyCode,
  });

  factory LoanRepayment.fromJson(Map<String, dynamic> json) {
    return LoanRepayment(
      date: json['date']?.toString() ?? '',
      amount: (json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0.0),
      loanName: json['loanName']?.toString() ?? '',
      paidBy: json['paidBy']?.toString() ?? '',
      familyCode: json['familyCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'amount': amount,
      'loanName': loanName,
      'paidBy': paidBy,
      'familyCode': familyCode,
    };
  }
}
