import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/feature_flag_service.dart';
import '../theme/app_theme.dart';
import 'share_expense_sheet.dart';

class ScreenshotsScreen extends StatefulWidget {
  const ScreenshotsScreen({super.key});

  @override
  State<ScreenshotsScreen> createState() => _ScreenshotsScreenState();
}

class _ScreenshotsScreenState extends State<ScreenshotsScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<String> _recentPaths = [];

  Future<void> _pickAndScan({bool camera = false}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;

    setState(() {
      _recentPaths.remove(file.path);
      _recentPaths.insert(0, file.path);
    });

    await ShareExpenseSheet.show(context, imagePath: file.path);
  }

  @override
  Widget build(BuildContext context) {
    final aiOn = FeatureFlagService.instance.isEnabled(
      FeatureKeys.aiScreenshotExtraction,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Screenshots Log')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            aiOn
                                ? 'Smart Screenshot Extraction (AI Active)'
                                : 'Offline Screenshot Extraction (AI Off)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share any GPay, PhonePe, Paytm, or bank screenshot directly to Manikutti from your phone share sheet, or pick from gallery below to log & forward to WhatsApp in 1 tap.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickAndScan(camera: false),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Pick Screenshot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickAndScan(camera: true),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Camera'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Recently Scanned in This Session',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _recentPaths.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.screenshot_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No screenshots scanned yet.\nPick one above or share from GPay / WhatsApp.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: _recentPaths.length,
                      itemBuilder: (context, idx) {
                        final path = _recentPaths[idx];
                        return InkWell(
                          onTap: () =>
                              ShareExpenseSheet.show(context, imagePath: path),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: Colors.black12,
                                child: Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
