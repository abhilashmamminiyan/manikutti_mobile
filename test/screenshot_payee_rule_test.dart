import 'package:flutter_test/flutter_test.dart';
import 'package:manikutti_flutter/services/category_service.dart';
import 'package:manikutti_flutter/services/screenshot_extractor_service.dart';
import 'package:manikutti_flutter/services/screenshot_payee_rule_service.dart';

void main() {
  group('ScreenshotPayeeRuleService matching & priority', () {
    final athulyaRule = ScreenshotPayeeRule(
      id: 'rule_athulya',
      label: 'Athulya',
      matchPatterns: ['9876543210', 'athulya@okaxis'],
      category: 'Emergency Fund',
      target: ScreenshotLedgerTarget.personal,
      customNote: 'Monthly savings to Athulya',
    );

    final momNishaRule = ScreenshotPayeeRule(
      id: 'rule_nisha',
      label: 'Nisha (Mom)',
      matchPatterns: ['9123456789', 'Nisha'],
      category: 'Home Loan',
      target: ScreenshotLedgerTarget.homeLoan,
      linkedDueTitle: 'Home loan',
      transferToMember: 'Nisha',
    );

    test('matches formatted Indian phone number (+91 spaces/hyphens)', () {
      const ocr = '''
      Paid to Athulya
      +91 98765-43210
      ₹3,000.00
      Completed
      ''';

      final matched = ScreenshotPayeeRuleService.matchFirstRule(
        [athulyaRule, momNishaRule],
        rawOcrText: ocr,
        merchant: 'Athulya',
      );

      expect(matched, isNotNull);
      expect(matched!.id, 'rule_athulya');
      expect(matched.category, 'Emergency Fund');
      expect(matched.target, ScreenshotLedgerTarget.personal);
    });

    test('payee rule overrides default/AI category and sets Home Loan + Family target', () {
      const ocr = '''
      Google Pay
      Paid to Nisha
      9123456789
      ₹12,500
      ''';

      final extractor = ScreenshotExtractorService.instance;
      final base = extractor.extractLocally(ocr);
      final overridden = extractor.applyPayeeRuleSync(
        base.copyWith(category: 'Food'),
        [athulyaRule, momNishaRule],
      );

      expect(overridden.amount, 12500);
      expect(overridden.category, 'Home Loan');
      expect(overridden.suggestedTarget, ScreenshotLedgerTarget.homeLoan);
      expect(overridden.linkedDueTitle, 'Home loan');
      expect(overridden.transferToMember, 'Nisha');
      expect(overridden.source, 'payee_rule');
    });

    test('CategoryService includes Savings, Emergency Fund, and Home Loan so Food fallback does not happen', () {
      expect(CategoryService.defaultCategories, contains('Savings'));
      expect(CategoryService.defaultCategories, contains('Emergency Fund'));
      expect(CategoryService.defaultCategories, contains('Home Loan'));
      expect(CategoryService.defaultCategories, contains('Loan/EMI'));
    });
  });
}
