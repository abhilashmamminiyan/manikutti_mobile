import 'dart:convert';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'api_service.dart';
import 'feature_flag_service.dart';
import 'screenshot_payee_rule_service.dart';

class ExtractedReceiptData {
  final double amount;
  final String category;
  final String merchant;
  final String note;
  final String type; // 'Expense' or 'Income'
  final String bankAccount;
  final DateTime date;
  final double confidence;
  final String source; // 'gemini_text', 'gemini_vision', 'local_offline', etc.
  final String rawOcrText;
  final String? matchedRuleId;
  final String? matchedRuleLabel;
  final ScreenshotLedgerTarget suggestedTarget;
  final String? linkedDueTitle;
  final String? transferToMember;

  ExtractedReceiptData({
    required this.amount,
    required this.category,
    required this.merchant,
    required this.note,
    required this.type,
    required this.bankAccount,
    required this.date,
    required this.confidence,
    required this.source,
    required this.rawOcrText,
    this.matchedRuleId,
    this.matchedRuleLabel,
    this.suggestedTarget = ScreenshotLedgerTarget.personal,
    this.linkedDueTitle,
    this.transferToMember,
  });

  ExtractedReceiptData copyWith({
    double? amount,
    String? category,
    String? merchant,
    String? note,
    String? type,
    String? bankAccount,
    DateTime? date,
    double? confidence,
    String? source,
    String? rawOcrText,
    String? matchedRuleId,
    String? matchedRuleLabel,
    ScreenshotLedgerTarget? suggestedTarget,
    String? linkedDueTitle,
    String? transferToMember,
  }) {
    return ExtractedReceiptData(
      amount: amount ?? this.amount,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      type: type ?? this.type,
      bankAccount: bankAccount ?? this.bankAccount,
      date: date ?? this.date,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      matchedRuleId: matchedRuleId ?? this.matchedRuleId,
      matchedRuleLabel: matchedRuleLabel ?? this.matchedRuleLabel,
      suggestedTarget: suggestedTarget ?? this.suggestedTarget,
      linkedDueTitle: linkedDueTitle ?? this.linkedDueTitle,
      transferToMember: transferToMember ?? this.transferToMember,
    );
  }

  factory ExtractedReceiptData.fromMap(
    Map<String, dynamic> map, {
    required String source,
    required String rawOcrText,
  }) {
    final amt = (map['amount'] is num)
        ? (map['amount'] as num).toDouble()
        : double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0;
    return ExtractedReceiptData(
      amount: amt,
      category: (map['category']?.toString() ?? 'Other').trim(),
      merchant: (map['merchant']?.toString() ?? '').trim(),
      note: (map['note']?.toString() ?? 'Screenshot Payment').trim(),
      type: (map['type']?.toString().toLowerCase() == 'income')
          ? 'Income'
          : 'Expense',
      bankAccount: (map['bankAccount']?.toString() ?? 'UPI').trim(),
      date:
          DateTime.tryParse(map['date']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      confidence: (map['confidence'] is num)
          ? (map['confidence'] as num).toDouble()
          : 0.65,
      source: source,
      rawOcrText: rawOcrText,
    );
  }
}

class ScreenshotExtractorService {
  ScreenshotExtractorService._();
  static final ScreenshotExtractorService instance =
      ScreenshotExtractorService._();

  static final List<_CategoryRule> _categoryRules = [
    _CategoryRule(
      RegExp(
        r'\b(swiggy|zomato|kfc|mcdonald|domino|pizza|tea|coffee|chai|cafe|hotel|restaurant|biryani|bakery|eatfit|blinkit|zepto|instamart|bigbasket|dmart|supermarket|grocery|vegetables|milk|fruits|meat|fish)\b',
        caseSensitive: false,
      ),
      'Food',
    ),
    _CategoryRule(
      RegExp(
        r'\b(uber|ola|rapido|irctc|metro|redbus|petrol|diesel|fuel|hpcl|bpcl|iocl|indian oil|fastag|toll|parking|auto)\b',
        caseSensitive: false,
      ),
      'Transport',
    ),
    _CategoryRule(
      RegExp(
        r'\b(kseb|bescom|tneb|electricity|water|gas|indane|hp gas|bharatgas|jio|airtel|vi\b|bsnl|broadband|wifi|recharge|bill|dth|tataplay|postpaid)\b',
        caseSensitive: false,
      ),
      'Bills',
    ),
    _CategoryRule(
      RegExp(
        r'\b(amazon|flipkart|myntra|ajio|nykaa|meesho|reliance|croma|mall|fashion|decathlon|ikea)\b',
        caseSensitive: false,
      ),
      'Shopping',
    ),
    _CategoryRule(
      RegExp(
        r'\b(pharmacy|apollo|medplus|1mg|pharmeasy|hospital|clinic|doctor|lab|scan|dental|medical|health)\b',
        caseSensitive: false,
      ),
      'Health',
    ),
    _CategoryRule(
      RegExp(
        r'\b(netflix|prime|hotstar|spotify|youtube|bookmyshow|pvr|inox|cinema|movie|game)\b',
        caseSensitive: false,
      ),
      'Leisure',
    ),
    _CategoryRule(
      RegExp(
        r'\b(rent|maintenance|housing|house|broker|plumber|electrician|carpenter)\b',
        caseSensitive: false,
      ),
      'Housing',
    ),
    _CategoryRule(
      RegExp(
        r'\b(sip|mutual fund|zerodha|groww|upstox|lic|insurance|ppf|nps|rd|fd)\b',
        caseSensitive: false,
      ),
      'Investment',
    ),
    _CategoryRule(
      RegExp(
        r'\b(emi|loan|bajaj|home loan|muthoot|manappuram)\b',
        caseSensitive: false,
      ),
      'Loan/EMI',
    ),
  ];

  /// 2-stage extraction pipeline:
  /// Stage 1: On-device ML Kit OCR (0 API cost)
  /// Stage 2: Optional server Gemini Flash Lite (text-first; vision fallback only if sparse & enabled by Admin)
  /// Stage 3: Offline local regex + merchant-category dictionary
  Future<ExtractedReceiptData> extractFromImageFile(String imagePath) async {
    String ocrText = '';

    // Stage 1: On-Device ML Kit Text Recognition (0 cost)
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      ocrText = recognizedText.text.trim();
    } catch (e) {
      // Proceed to local fallback / Vision if needed
    } finally {
      await textRecognizer.close();
    }

    final rules = await ScreenshotPayeeRuleService.instance.getRules();
    final localResult = applyPayeeRuleSync(extractLocally(ocrText), rules);

    // Check if Admin enabled Gemini AI extraction for this user's role
    final aiEnabledForUser = FeatureFlagService.instance.isEnabled(
      FeatureKeys.aiScreenshotExtraction,
    );

    if (!aiEnabledForUser) {
      return localResult;
    }

    // Stage 2: Gemini Flash Lite via server endpoint (OCR text first; image only if OCR sparse/missed)
    try {
      String? imageBase64;
      final needsVisionFallback =
          ocrText.length < 18 || localResult.amount <= 0;
      if (needsVisionFallback) {
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          // Guard payload size (< 1.5 MB) to protect free quota & serverless memory
          if (bytes.length <= 1500 * 1024) {
            imageBase64 = base64Encode(bytes);
          }
        }
      }

      final remote = await ApiService.instance.extractScreenshotWithAi(
        ocrText: ocrText,
        imageBase64: imageBase64,
      );

      if (remote != null && remote['extracted'] is Map<String, dynamic>) {
        final ext = remote['extracted'] as Map<String, dynamic>;
        final src = remote['source']?.toString() ?? 'gemini_text';
        final parsed = ExtractedReceiptData.fromMap(
          ext,
          source: src,
          rawOcrText: ocrText,
        );
        if (parsed.amount > 0) {
          return applyPayeeRuleSync(parsed, rules);
        }
      }
    } catch (_) {
      // Offline / rate-limit fallback seamlessly returns local result
    }

    return localResult;
  }

  /// Applies saved Payee / Phone Number / UPI rules at highest priority.
  ExtractedReceiptData applyPayeeRuleSync(
    ExtractedReceiptData extracted,
    List<ScreenshotPayeeRule> rules,
  ) {
    final matched = ScreenshotPayeeRuleService.matchFirstRule(
      rules,
      rawOcrText: extracted.rawOcrText,
      merchant: extracted.merchant,
      note: extracted.note,
    );
    if (matched == null) return extracted;

    final customNote = matched.customNote?.trim();
    final resolvedNote = (customNote != null && customNote.isNotEmpty)
        ? customNote
        : (extracted.merchant.isNotEmpty
              ? '${matched.label} (${extracted.merchant})'
              : '${matched.label} (Rule)');

    return extracted.copyWith(
      category: matched.category,
      type: matched.transactionType,
      note: resolvedNote,
      confidence: extracted.amount > 0 ? 0.96 : extracted.confidence,
      source: 'payee_rule',
      matchedRuleId: matched.id,
      matchedRuleLabel: matched.label,
      suggestedTarget: matched.target,
      linkedDueTitle: matched.linkedDueTitle,
      transferToMember: matched.transferToMember,
    );
  }

  /// Pure offline deterministic parser for Indian UPI/Bank payment screenshots.
  ExtractedReceiptData extractLocally(String ocrText) {
    final normalized = ocrText.replaceAll('\r', '\n');
    final lower = normalized.toLowerCase();

    double amount = 0.0;

    final currencyPatterns = [
      RegExp(
        r'(?:₹|rs\.?|inr)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:paid|amount|sent|debited|credited|total)\s*[:\-]?\s*(?:₹|rs\.?|inr)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
    ];

    for (final regex in currencyPatterns) {
      final match = regex.firstMatch(normalized);
      if (match != null) {
        final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (val != null && val > 0 && val < 10000000) {
          amount = val;
          break;
        }
      }
    }

    if (amount <= 0) {
      for (final line in normalized.split('\n')) {
        final trimmed = line.trim();
        if (RegExp(r'^[0-9][0-9,]*(?:\.[0-9]{1,2})?$').hasMatch(trimmed)) {
          final val = double.tryParse(trimmed.replaceAll(',', ''));
          if (val != null && val >= 1 && val < 500000) {
            amount = val;
            break;
          }
        }
      }
    }

    String merchant = '';
    final merchantRegex = RegExp(
      r"(?:paid to|to|transfer to|received from|from|merchant)\s*[:\-]?\s*([a-z0-9 &._'\-]{2,40})",
      caseSensitive: false,
    );
    final mMatch = merchantRegex.firstMatch(normalized);
    if (mMatch != null && mMatch.group(1) != null) {
      merchant = mMatch.group(1)!.split('\n').first.trim();
    }

    final isIncome =
        RegExp(
          r'\b(received from|credited to|credit alert|cashback|refunded|you received|salary credited)\b',
          caseSensitive: false,
        ).hasMatch(lower) &&
        !RegExp(
          r'\b(paid to|sent to|debited|you paid)\b',
          caseSensitive: false,
        ).hasMatch(lower);

    final type = isIncome ? 'Income' : 'Expense';

    String category = isIncome ? 'Salary' : 'Other';
    for (final rule in _categoryRules) {
      if (rule.pattern.hasMatch(normalized)) {
        category = rule.category;
        break;
      }
    }

    String bankAccount = 'UPI';
    if (RegExp(r'\bsbi\b|state bank', caseSensitive: false).hasMatch(lower)) {
      bankAccount = 'SBI';
    } else if (RegExp(r'\bhdfc\b', caseSensitive: false).hasMatch(lower)) {
      bankAccount = 'HDFC';
    } else if (RegExp(r'\bicici\b', caseSensitive: false).hasMatch(lower)) {
      bankAccount = 'ICICI';
    } else if (RegExp(r'\bfederal\b', caseSensitive: false).hasMatch(lower)) {
      bankAccount = 'Federal';
    } else if (RegExp(r'\bcanara\b', caseSensitive: false).hasMatch(lower)) {
      bankAccount = 'Canara';
    } else if (RegExp(r'\baxis\b', caseSensitive: false).hasMatch(lower)) {
      bankAccount = 'Axis';
    } else if (RegExp(
      r'\bgpay\b|google pay',
      caseSensitive: false,
    ).hasMatch(lower)) {
      bankAccount = 'GPay';
    } else if (RegExp(r'\bphonepe\b', caseSensitive: false).hasMatch(lower)) {
      bankAccount = 'PhonePe';
    } else if (RegExp(r'\bpaytm\b', caseSensitive: false).hasMatch(lower)) {
      bankAccount = 'Paytm';
    }

    final note = merchant.isNotEmpty
        ? '$merchant (Screenshot)'
        : 'Screenshot Payment';
    final confidence = amount > 0 ? (merchant.isNotEmpty ? 0.72 : 0.55) : 0.2;

    return ExtractedReceiptData(
      amount: amount,
      category: category,
      merchant: merchant,
      note: note,
      type: type,
      bankAccount: bankAccount,
      date: DateTime.now().toUtc(),
      confidence: confidence,
      source: 'local_offline',
      rawOcrText: ocrText,
    );
  }
}

class _CategoryRule {
  final RegExp pattern;
  final String category;
  const _CategoryRule(this.pattern, this.category);
}
