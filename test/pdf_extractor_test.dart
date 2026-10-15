import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

List<Map<String, dynamic>> parseIndianBankStatementText(String rawText) {
  final cleanedText = rawText.replaceAll('\u00A0', ' ');
  final rawLines = cleanedText
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .toList();

  final List<String> consolidatedLines = [];
  String currentBlock = '';

  const monthNames = 'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec';
  final lineDatePattern = RegExp(
    r'(?:^|\s|\b)(\d{1,2}[\s/-]+(?:' +
        monthNames +
        r')[a-z]*[\s/-]+\d{2,4}|\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4})',
    caseSensitive: false,
  );

  for (final line in rawLines) {
    if (line.isEmpty) continue;
    final match = lineDatePattern.firstMatch(line);
    final hasDateAtStart = match != null && match.start <= 8;

    if (hasDateAtStart) {
      if (currentBlock.isNotEmpty) {
        consolidatedLines.add(currentBlock);
      }
      currentBlock = line;
    } else if (currentBlock.isNotEmpty) {
      currentBlock += ' $line';
    }
  }
  if (currentBlock.isNotEmpty) {
    consolidatedLines.add(currentBlock);
  }

  final results = <Map<String, dynamic>>[];
  const monthMap = {
    'jan': '01',
    'feb': '02',
    'mar': '03',
    'apr': '04',
    'may': '05',
    'jun': '06',
    'jul': '07',
    'aug': '08',
    'sep': '09',
    'oct': '10',
    'nov': '11',
    'dec': '12',
  };

  for (final block in consolidatedLines) {
    final dateMatch = lineDatePattern.firstMatch(block);
    if (dateMatch == null || dateMatch.start > 8) continue;

    final dateStr = dateMatch.group(1)!;
    String parsedDate = '';

    final alphaMonthMatch = RegExp(
      r'^(\d{1,2})[\s/-]+([A-Za-z]{3})[a-z]*[\s/-]+(\d{2,4})$',
    ).firstMatch(dateStr);
    if (alphaMonthMatch != null) {
      final day = alphaMonthMatch.group(1)!.padLeft(2, '0');
      final month = monthMap[alphaMonthMatch.group(2)!.toLowerCase()] ?? '01';
      String year = alphaMonthMatch.group(3)!;
      if (year.length == 2) year = '20$year';
      parsedDate = '$year-$month-$day';
    } else {
      final numParts = dateStr.split(RegExp(r'[-/.]'));
      if (numParts.length == 3) {
        if (numParts[0].length == 4) {
          parsedDate =
              '${numParts[0]}-${numParts[1].padLeft(2, '0')}-${numParts[2].padLeft(2, '0')}';
        } else {
          String year = numParts[2];
          if (year.length == 2) year = '20$year';
          parsedDate =
              '$year-${numParts[1].padLeft(2, '0')}-${numParts[0].padLeft(2, '0')}';
        }
      }
    }

    if (parsedDate.isEmpty) continue;

    String remainder = block.substring(dateMatch.end).trim();
    final secondDateMatch = lineDatePattern.firstMatch(remainder);
    if (secondDateMatch != null && secondDateMatch.start <= 2) {
      remainder = remainder.substring(secondDateMatch.end).trim();
    }

    String textForAmounts = remainder;
    final trailMatch = RegExp(
      r'[\s(]+(cr|dr)[\s)]*$',
      caseSensitive: false,
    ).firstMatch(textForAmounts);
    if (trailMatch != null) {
      textForAmounts = textForAmounts.substring(0, trailMatch.start).trim();
    }

    final tokens = textForAmounts.split(RegExp(r'\s+'));
    final amountTokens = <double>[];
    final descTokens = List<String>.from(tokens);

    while (descTokens.isNotEmpty) {
      String last = descTokens.last.replaceAll(',', '');
      if (last.toLowerCase().endsWith('cr')) {
        last = last.substring(0, last.length - 2);
      } else if (last.toLowerCase().endsWith('dr')) {
        last = last.substring(0, last.length - 2);
      }

      if (last == '-' || last == '--') {
        descTokens.removeLast();
        continue;
      }

      final num = double.tryParse(last);
      if (num != null && RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(last)) {
        amountTokens.insert(0, num);
        descTokens.removeLast();
      } else {
        break;
      }
    }

    if (amountTokens.isEmpty) continue;

    final description = descTokens.join(' ').trim();
    if (description.isEmpty) continue;

    double amount = 0.0;
    String type = 'Expense';

    if (amountTokens.length >= 3) {
      final debit = amountTokens[amountTokens.length - 3];
      final credit = amountTokens[amountTokens.length - 2];
      if (credit > 0 && debit == 0) {
        amount = credit;
        type = 'Income';
      } else {
        amount = debit > 0 ? debit : credit;
        type = debit > 0 ? 'Expense' : 'Income';
      }
    } else if (amountTokens.length == 2) {
      amount = amountTokens[0];
    } else {
      amount = amountTokens[0];
    }

    if (amount <= 0) continue;

    final lowerDesc = description.toLowerCase();
    if (type != 'Income') {
      final isCreditDesc =
          lowerDesc.contains('salary') ||
          lowerDesc.contains('by transfer') ||
          lowerDesc.contains('refund') ||
          lowerDesc.contains('interest') ||
          lowerDesc.contains('dividend') ||
          lowerDesc.contains('/cr/') ||
          lowerDesc.startsWith('cr ') ||
          lowerDesc.endsWith(' cr');
      if (isCreditDesc) {
        type = 'Income';
      }
    }

    String category = 'General';
    if (lowerDesc.contains('swiggy') ||
        lowerDesc.contains('zomato') ||
        lowerDesc.contains('hotel') ||
        lowerDesc.contains('food') ||
        lowerDesc.contains('restaurant')) {
      category = 'Food';
    } else if (lowerDesc.contains('fuel') ||
        lowerDesc.contains('petrol') ||
        lowerDesc.contains('hpcl') ||
        lowerDesc.contains('bpcl') ||
        lowerDesc.contains('uber') ||
        lowerDesc.contains('ola')) {
      category = 'Transport';
    } else if (lowerDesc.contains('amazon') ||
        lowerDesc.contains('flipkart') ||
        lowerDesc.contains('myntra') ||
        lowerDesc.contains('retail') ||
        lowerDesc.contains('pos ')) {
      category = 'Shopping';
    } else if (lowerDesc.contains('salary') || lowerDesc.contains('payroll')) {
      category = 'Salary';
      type = 'Income';
    } else if (lowerDesc.contains('electric') ||
        lowerDesc.contains('kseb') ||
        lowerDesc.contains('bescom') ||
        lowerDesc.contains('airtel') ||
        lowerDesc.contains('jio')) {
      category = 'Utilities';
    } else if (lowerDesc.contains('rent') || lowerDesc.contains('housing')) {
      category = 'Housing';
    } else if (lowerDesc.contains('pharmacy') ||
        lowerDesc.contains('hospital') ||
        lowerDesc.contains('med')) {
      category = 'Health';
    }

    results.add({
      'date': parsedDate,
      'amount': amount,
      'type': type,
      'category': category,
      'description': description,
      'note': description.length > 60
          ? description.substring(0, 60)
          : description,
    });
  }

  return results;
}

void main() {
  test('PdfDocument password unlock and text extraction test', () {
    final doc = PdfDocument();
    doc.security.userPassword = 'secretpassword';
    final page = doc.pages.add();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    page.graphics.drawString(
      '01 Oct 2026 01 Oct 2026 UPI/DR/12345/Swiggy 250.00 45,210.50 Cr\n02-10-2026 02-10-2026 SALARY CREDIT 50000.00 95,210.50 Cr',
      font,
      bounds: const Rect.fromLTWH(0, 0, 500, 200),
    );
    final bytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();

    final unlockedDoc = PdfDocument(
      inputBytes: bytes,
      password: 'secretpassword',
    );
    final extractedText = PdfTextExtractor(unlockedDoc).extractText();
    unlockedDoc.dispose();

    expect(extractedText.contains('Swiggy'), isTrue);
    expect(extractedText.contains('45,210.50'), isTrue);

    final parsedRows = parseIndianBankStatementText(extractedText);
    expect(parsedRows.length, equals(2));
    expect(parsedRows[0]['amount'], equals(250.0));
    expect(parsedRows[0]['type'], equals('Expense'));
    expect(parsedRows[0]['category'], equals('Food'));
    expect(parsedRows[0]['date'], equals('2026-10-01'));

    expect(parsedRows[1]['amount'], equals(50000.0));
    expect(parsedRows[1]['type'], equals('Income'));
    expect(parsedRows[1]['category'], equals('Salary'));
    expect(parsedRows[1]['date'], equals('2026-10-02'));
  });

  test('Test multi-line and serial number SBI statements', () {
    const sbiSample = '''
1 01/10/2026 01/10/2026 TRANSFER TO 50999912345
UPI/3284729182/swiggy TRANSFER
250.00 45,210.50 Cr
2 05-Oct-2026 BY TRANSFER-INB NEFT*SBIN000123*ABC - 5,000.00 50,210.50(Cr)
3 10-10-2026 PETROL PUMP IOCL 450.00 49,760.50 Dr
''';

    final results = parseIndianBankStatementText(sbiSample);
    expect(results.length, equals(3));
    expect(results[0]['amount'], equals(250.0));
    expect(results[0]['date'], equals('2026-10-01'));
    expect(results[1]['amount'], equals(5000.0));
    expect(results[1]['type'], equals('Income'));
    expect(results[1]['date'], equals('2026-10-05'));
    expect(results[2]['amount'], equals(450.0));
    expect(results[2]['category'], equals('Transport'));
    expect(results[2]['date'], equals('2026-10-10'));
  });
}
