class MobileRecharge {
  final int? id;
  final String name;
  final String phoneNumber;
  final String operator;
  final double planLastRecharged;
  final String planDescription;
  final String validityTill;
  final String lastRechargedDate;
  final int reminderDaysBefore;
  final bool notifyExpiry;
  final String note;
  final bool logExpense;

  const MobileRecharge({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.operator,
    required this.planLastRecharged,
    this.planDescription = '',
    required this.validityTill,
    this.lastRechargedDate = '',
    this.reminderDaysBefore = 1,
    this.notifyExpiry = true,
    this.note = '',
    this.logExpense = false,
  });

  /// Days left until validity expires.
  /// Returns negative value if expired, 0 if expires today, positive if valid.
  int get daysRemaining {
    if (validityTill.isEmpty) return 0;
    final expiry = DateTime.tryParse(validityTill);
    if (expiry == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiry.year, expiry.month, expiry.day);
    return target.difference(today).inDays;
  }

  bool get isExpired => daysRemaining < 0;
  bool get isExpiringToday => daysRemaining == 0;
  bool get isExpiringSoon => daysRemaining > 0 && daysRemaining <= 3;

  String get statusText {
    final d = daysRemaining;
    if (d < 0) {
      final daysAgo = d.abs();
      return daysAgo == 1 ? 'Expired yesterday' : 'Expired $daysAgo days ago';
    }
    if (d == 0) return 'Expires today';
    if (d == 1) return 'Expires tomorrow';
    return '$d days left';
  }

  factory MobileRecharge.fromJson(Map<String, dynamic> json) {
    return MobileRecharge(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      operator: json['operator']?.toString() ?? 'Other',
      planLastRecharged: (json['planLastRecharged'] is num)
          ? (json['planLastRecharged'] as num).toDouble()
          : double.tryParse(json['planLastRecharged']?.toString() ?? '0') ?? 0.0,
      planDescription: json['planDescription']?.toString() ?? '',
      validityTill: json['validityTill']?.toString() ?? '',
      lastRechargedDate: json['lastRechargedDate']?.toString() ?? '',
      reminderDaysBefore: json['reminderDaysBefore'] is int
          ? json['reminderDaysBefore']
          : int.tryParse(json['reminderDaysBefore']?.toString() ?? '1') ?? 1,
      notifyExpiry: json['notifyExpiry'] == true ||
          json['notifyExpiry'] == 'true' ||
          json['notifyExpiry'] == 1,
      note: json['note']?.toString() ?? '',
      logExpense: json['logExpense'] == true ||
          json['logExpense'] == 'true' ||
          json['logExpense'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'operator': operator,
      'planLastRecharged': planLastRecharged,
      'planDescription': planDescription,
      'validityTill': validityTill,
      'lastRechargedDate': lastRechargedDate,
      'reminderDaysBefore': reminderDaysBefore,
      'notifyExpiry': notifyExpiry,
      'note': note,
      'logExpense': logExpense,
    };
  }

  factory MobileRecharge.fromMap(Map<String, dynamic> map) {
    return MobileRecharge.fromJson(map);
  }

  Map<String, dynamic> toMap() {
    final map = toJson();
    map['notifyExpiry'] = notifyExpiry ? 1 : 0;
    map['logExpense'] = logExpense ? 1 : 0;
    return map;
  }

  MobileRecharge copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? operator,
    double? planLastRecharged,
    String? planDescription,
    String? validityTill,
    String? lastRechargedDate,
    int? reminderDaysBefore,
    bool? notifyExpiry,
    String? note,
    bool? logExpense,
  }) {
    return MobileRecharge(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      operator: operator ?? this.operator,
      planLastRecharged: planLastRecharged ?? this.planLastRecharged,
      planDescription: planDescription ?? this.planDescription,
      validityTill: validityTill ?? this.validityTill,
      lastRechargedDate: lastRechargedDate ?? this.lastRechargedDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      notifyExpiry: notifyExpiry ?? this.notifyExpiry,
      note: note ?? this.note,
      logExpense: logExpense ?? this.logExpense,
    );
  }
}
