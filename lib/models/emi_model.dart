class EmiBill {
  final int? id;
  final String title;
  final double amount;
  final String dueDate;
  final String status;
  final String familyCode;
  final String adminEmail;
  final int tenure;
  final double monthlyPayment;
  final String startDate;
  final int paidMonths;
  final String type; // 'EMI' | 'Bill'
  final String owner;

  EmiBill({
    this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.status = 'Unpaid',
    required this.familyCode,
    this.adminEmail = '',
    required this.tenure,
    required this.monthlyPayment,
    required this.startDate,
    this.paidMonths = 0,
    this.type = 'EMI',
    this.owner = 'Family',
  });

  factory EmiBill.fromJson(Map<String, dynamic> json) {
    return EmiBill(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] is num
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0.0),
      dueDate: json['dueDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Unpaid',
      familyCode: json['familyCode']?.toString() ?? '',
      adminEmail: json['adminEmail']?.toString() ?? '',
      tenure: json['tenure'] is int
          ? json['tenure']
          : int.tryParse(json['tenure']?.toString() ?? '') ?? 0,
      monthlyPayment: (json['monthlyPayment'] is num
          ? (json['monthlyPayment'] as num).toDouble()
          : double.tryParse(json['monthlyPayment']?.toString() ?? '') ?? 0.0),
      startDate: json['startDate']?.toString() ?? '',
      paidMonths: json['paidMonths'] is int
          ? json['paidMonths']
          : int.tryParse(json['paidMonths']?.toString() ?? '') ?? 0,
      type: json['type']?.toString() ?? 'EMI',
      owner: json['owner']?.toString() ?? 'Family',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'dueDate': dueDate,
      'status': status,
      'familyCode': familyCode,
      'adminEmail': adminEmail,
      'tenure': tenure,
      'monthlyPayment': monthlyPayment,
      'startDate': startDate,
      'paidMonths': paidMonths,
      'type': type,
      'owner': owner,
    };
  }

  double get progressPercentage {
    if (tenure <= 0) return 0.0;
    final progress = paidMonths / tenure;
    return progress > 1.0 ? 1.0 : progress;
  }

  bool get isCompleted =>
      paidMonths >= tenure || status.toLowerCase() == 'completed';
}
