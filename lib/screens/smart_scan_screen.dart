import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SmartScanScreen extends StatefulWidget {
  const SmartScanScreen({super.key});

  @override
  State<SmartScanScreen> createState() => _SmartScanScreenState();
}

class _SmartScanScreenState extends State<SmartScanScreen> {
  final ImagePicker _picker = ImagePicker();
  String _scannedText = '';
  bool _isScanning = false;

  Future<void> _processImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isScanning = true;
      });

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      String text = recognizedText.text;

      // Basic extraction via Regex (Custom logic for Google Pay)
      final amountExp = RegExp(r'₹\s?([0-9,]+(\.[0-9]{1,2})?)');
      final amountMatch = amountExp.firstMatch(text);
      String extractedAmount = amountMatch?.group(1) ?? 'Not found';

      setState(() {
        _scannedText =
            'Raw Text:\n$text\n\nExtracted Amount: ₹$extractedAmount';
        _isScanning = false;
      });

      textRecognizer.close();
    } catch (e) {
      setState(() {
        _scannedText = 'Error scanning image: $e';
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.smartScan)),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _processImage,
              icon: const Icon(Icons.document_scanner),
              label: Text(l10n.scanReceipt),
            ),
            const SizedBox(height: 20),
            if (_isScanning) const CircularProgressIndicator(),
            if (!_isScanning && _scannedText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.withOpacity(0.1),
                child: Text(_scannedText),
              ),
          ],
        ),
      ),
    );
  }
}
