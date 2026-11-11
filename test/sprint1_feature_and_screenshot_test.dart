import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manikutti_flutter/services/feature_flag_service.dart';
import 'package:manikutti_flutter/services/screenshot_extractor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeatureFlagService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await FeatureFlagService.instance.clear();
    });

    test(
      'defaults remain fail-open offline and persist role updates',
      () async {
        final flags = FeatureFlagService.instance;
        expect(flags.roleName, equals('Member'));
        expect(flags.masterAiEnabled, isTrue);
        expect(flags.isEnabled(FeatureKeys.homeLoan), isTrue);
        expect(flags.isEnabled(FeatureKeys.aiScreenshotExtraction), isTrue);

        await flags.updateFromServer(
          roleName: 'Basic',
          permissions: {
            FeatureKeys.homeLoan: false,
            FeatureKeys.loansEmiLedger: false,
            FeatureKeys.billsUtilities: true,
          },
          aiEnabled: true,
        );

        expect(flags.roleName, equals('Basic'));
        expect(flags.isEnabled(FeatureKeys.homeLoan), isFalse);
        expect(flags.isEnabled(FeatureKeys.loansEmiLedger), isFalse);
        expect(flags.isEnabled(FeatureKeys.billsUtilities), isTrue);
        // Keys omitted from payload stay fail-open by default
        expect(flags.isEnabled(FeatureKeys.screenshots), isTrue);
      },
    );

    test(
      'master aiEnabled=false forces AI features off regardless of role grants',
      () async {
        final flags = FeatureFlagService.instance;
        await flags.updateFromServer(
          roleName: 'Partner',
          permissions: {
            FeatureKeys.aiScreenshotExtraction: true,
            FeatureKeys.aiAdvisor: true,
            FeatureKeys.screenshots: true,
          },
          aiEnabled: false,
        );

        expect(flags.masterAiEnabled, isFalse);
        expect(flags.isEnabled(FeatureKeys.aiScreenshotExtraction), isFalse);
        expect(flags.isEnabled(FeatureKeys.aiAdvisor), isFalse);
        // Non-AI local OCR screenshot tool remains usable
        expect(flags.isEnabled(FeatureKeys.screenshots), isTrue);

        await flags.clear();
        expect(flags.roleName, equals('Member'));
        expect(flags.masterAiEnabled, isTrue);
        expect(flags.isEnabled(FeatureKeys.aiScreenshotExtraction), isTrue);
      },
    );
  });

  group('ScreenshotExtractorService Offline Parser Tests', () {
    final extractor = ScreenshotExtractorService.instance;

    test('parses GPay food payment screenshot cleanly', () {
      const sampleOcr = '''
Paid ₹450
Paid to Swiggy
12 Nov 2026, 8:15 PM
UPI transaction ID: 631209876543
Paid via GPay - SBI
''';
      final parsed = extractor.extractLocally(sampleOcr);

      expect(parsed.amount, equals(450.0));
      expect(parsed.category, equals('Food'));
      expect(parsed.type, equals('Expense'));
      expect(parsed.merchant.toLowerCase(), contains('swiggy'));
      expect(parsed.bankAccount, equals('SBI'));
      expect(parsed.source, equals('local_offline'));
    });

    test('parses KSEB utility bill with commas and skips long UTR numbers', () {
      const sampleOcr = '''
PhonePe
Transaction Successful
Rs. 1,250.50
Paid to KSEB Electricity Board
UTR: 431209876543
Federal Bank
''';
      final parsed = extractor.extractLocally(sampleOcr);

      expect(parsed.amount, equals(1250.50));
      expect(parsed.category, equals('Bills'));
      expect(parsed.type, equals('Expense'));
      expect(parsed.bankAccount, equals('Federal'));
    });

    test('identifies income/salary credits accurately', () {
      const sampleOcr = '''
Salary credited
Received from Acme Technologies
₹45,000.00
Credited to HDFC Bank A/c
''';
      final parsed = extractor.extractLocally(sampleOcr);

      expect(parsed.amount, equals(45000.0));
      expect(parsed.type, equals('Income'));
      expect(parsed.category, equals('Salary'));
      expect(parsed.bankAccount, equals('HDFC'));
    });

    test('falls back to line-based amount while ignoring 12-digit refs', () {
      const sampleOcr = '''
431209876543
850.50
Apollo Pharmacy
Paytm
''';
      final parsed = extractor.extractLocally(sampleOcr);

      expect(parsed.amount, equals(850.50));
      expect(parsed.category, equals('Health'));
      expect(parsed.bankAccount, equals('Paytm'));
    });
  });
}
