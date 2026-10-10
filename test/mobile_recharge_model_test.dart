import 'package:flutter_test/flutter_test.dart';
import 'package:manikutti_flutter/models/mobile_recharge_model.dart';

void main() {
  group('MobileRecharge Model Tests', () {
    test('fromJson correctly parses fields and JSON serialization', () {
      final json = {
        'id': 1,
        'name': 'Mom Jio',
        'phoneNumber': '9876543210',
        'operator': 'Jio',
        'planLastRecharged': 299.0,
        'planDescription': '1.5GB/day 28 days',
        'validityTill': '2026-11-01',
        'lastRechargedDate': '2026-10-04',
        'reminderDaysBefore': 1,
        'notifyExpiry': true,
        'note': 'SIM slot 1',
        'logExpense': false,
      };

      final recharge = MobileRecharge.fromJson(json);

      expect(recharge.id, 1);
      expect(recharge.name, 'Mom Jio');
      expect(recharge.phoneNumber, '9876543210');
      expect(recharge.operator, 'Jio');
      expect(recharge.planLastRecharged, 299.0);
      expect(recharge.planDescription, '1.5GB/day 28 days');
      expect(recharge.validityTill, '2026-11-01');
      expect(recharge.reminderDaysBefore, 1);
      expect(recharge.notifyExpiry, isTrue);

      final outJson = recharge.toJson();
      expect(outJson['name'], 'Mom Jio');
      expect(outJson['operator'], 'Jio');
      expect(outJson['planLastRecharged'], 299.0);
    });

    test('daysRemaining and statusText work accurately', () {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final futureDate = now.add(const Duration(days: 5));
      final futureStr =
          '${futureDate.year}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}';
      final pastDate = now.subtract(const Duration(days: 2));
      final pastStr =
          '${pastDate.year}-${pastDate.month.toString().padLeft(2, '0')}-${pastDate.day.toString().padLeft(2, '0')}';

      final rechargeToday = MobileRecharge(
        name: 'Test Today',
        phoneNumber: '9999999999',
        operator: 'Airtel',
        planLastRecharged: 199,
        validityTill: todayStr,
      );
      expect(rechargeToday.daysRemaining, 0);
      expect(rechargeToday.isExpiringToday, isTrue);
      expect(rechargeToday.isExpired, isFalse);
      expect(rechargeToday.statusText, 'Expires today');

      final rechargeFuture = MobileRecharge(
        name: 'Test Future',
        phoneNumber: '9999999999',
        operator: 'Vi',
        planLastRecharged: 479,
        validityTill: futureStr,
      );
      expect(rechargeFuture.daysRemaining, 5);
      expect(rechargeFuture.isExpired, isFalse);
      expect(rechargeFuture.statusText, '5 days left');

      final rechargePast = MobileRecharge(
        name: 'Test Past',
        phoneNumber: '9999999999',
        operator: 'BSNL',
        planLastRecharged: 153,
        validityTill: pastStr,
      );
      expect(rechargePast.daysRemaining, lessThan(0));
      expect(rechargePast.isExpired, isTrue);
      expect(rechargePast.statusText, contains('Expired'));
    });

    test('copyWith updates specified fields correctly', () {
      const original = MobileRecharge(
        id: 5,
        name: 'Dad BSNL',
        phoneNumber: '9447000000',
        operator: 'BSNL',
        planLastRecharged: 197,
        validityTill: '2026-10-20',
      );

      final updated = original.copyWith(
        planLastRecharged: 249,
        validityTill: '2026-11-20',
      );

      expect(updated.id, 5);
      expect(updated.name, 'Dad BSNL');
      expect(updated.planLastRecharged, 249);
      expect(updated.validityTill, '2026-11-20');
      expect(updated.operator, 'BSNL');
    });
  });
}
