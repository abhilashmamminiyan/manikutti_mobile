class UtilityBill {
  final int? id;
  final String title;
  final double amount;
  final String validity;
  final String status;
  final String lastPaidDate;
  final String nextDueDate;
  final String note;
  final bool logExpense;

  UtilityBill({
    this.id,
    required this.title,
    required this.amount,
    required this.validity,
    required this.status,
    required this.lastPaidDate,
    required this.nextDueDate,
    required this.note,
    this.logExpense = false,
  });

  factory UtilityBill.fromJson(Map<String, dynamic> json) {
    return UtilityBill(
      id: json['id'],
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      validity: json['validity'] ?? '',
      status: json['status'] ?? 'Active',
      lastPaidDate: json['lastPaidDate'] ?? '',
      nextDueDate: json['nextDueDate'] ?? '',
      note: json['note'] ?? '',
      logExpense: json['logExpense'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'validity': validity,
      'status': status,
      'lastPaidDate': lastPaidDate,
      'nextDueDate': nextDueDate,
      'note': note,
      'logExpense': logExpense,
    };
  }
}
