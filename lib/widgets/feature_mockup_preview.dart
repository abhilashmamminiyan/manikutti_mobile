import 'package:flutter/material.dart';
import '../models/app_feature_info.dart';
import '../theme/app_theme.dart';

class FeatureMockupPreview extends StatelessWidget {
  final MockupType mockupType;
  final int stepIndex; // 0, 1, 2

  const FeatureMockupPreview({
    super.key,
    required this.mockupType,
    required this.stepIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320, minHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF334155), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Column(
          children: [
            // Top Phone Status Bar & Notch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFF090D16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '10:15',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Camera Notch
                  Container(
                    width: 48,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.white70, size: 12),
                      SizedBox(width: 4),
                      Icon(
                        Icons.signal_cellular_4_bar,
                        color: Colors.white70,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.battery_5_bar_rounded,
                        color: Colors.white70,
                        size: 12,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Phone Screen Body Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildPhoneScreenContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneScreenContent(BuildContext context) {
    switch (mockupType) {
      case MockupType.homeScreenWidget:
        return _buildWidgetMockup();
      case MockupType.googleAssistant:
        return _buildAssistantMockup();
      case MockupType.bankStatement:
        return _buildStatementMockup();
      case MockupType.biometricLock:
        return _buildBiometricMockup();
      case MockupType.voiceLogging:
        return _buildVoiceMockup();
      case MockupType.familySanctuary:
        return _buildFamilyMockup();
      case MockupType.upcomingRoadmap:
        return _buildRoadmapMockup();
    }
  }

  // --- 1. HOME SCREEN WIDGET MOCKUP ---
  Widget _buildWidgetMockup() {
    if (stepIndex == 0) {
      // Step 1: Wallpaper long-press with context menu
      return Column(
        children: [
          const SizedBox(height: 12),
          // Home screen mock app grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDummyAppIcon(
                Icons.camera_alt_rounded,
                'Camera',
                Colors.pinkAccent,
              ),
              _buildDummyAppIcon(Icons.mail_rounded, 'Mail', Colors.redAccent),
              _buildDummyAppIcon(Icons.public_rounded, 'Chrome', Colors.amber),
              _buildDummyAppIcon(
                Icons.photo_library_rounded,
                'Photos',
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Pulsing tap animation
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
              ),
              const Icon(
                Icons.touch_app_rounded,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Floating menu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary, width: 1.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.widgets_rounded, color: AppTheme.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Widgets',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap "Widgets" to open selector',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      );
    } else if (stepIndex == 1) {
      // Step 2: Widget drawer sheet
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Colors.white54, size: 14),
                SizedBox(width: 6),
                Text(
                  'Search "Manikutti"',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueAccent, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Manikutti (4x2)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Smart Card',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Displays month-to-date spending, nearest bill alert, and 1-tap voice entry.',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {},
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              label: const Text(
                'Add to Screen',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      );
    } else {
      // Step 3: Active Android home screen with pinned widget
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pinned Manikutti Widget Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2B26), Color(0xFF134E48)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF2DD4BF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.spa_rounded,
                          color: Color(0xFF2DD4BF),
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'The Heritage Ledger',
                          style: TextStyle(
                            color: Color(0xFFCCFBF1),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'October',
                        style: TextStyle(color: Colors.white70, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '₹14,250',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Total Family Expenses',
                  style: TextStyle(color: Colors.white70, fontSize: 9),
                ),
                const SizedBox(height: 8),
                // Bill Alert Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.amber,
                        size: 10,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Jio Fiber due in 3 days (₹799)',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Widget Actions
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Voice Entry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // App Dock
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDummyAppIcon(Icons.call_rounded, 'Phone', Colors.green),
              _buildDummyAppIcon(
                Icons.chat_bubble_rounded,
                'Chat',
                Colors.blue,
              ),
              _buildDummyAppIcon(
                Icons.camera_alt_rounded,
                'Camera',
                Colors.orange,
              ),
              _buildDummyAppIcon(
                Icons.settings_rounded,
                'Settings',
                Colors.grey,
              ),
            ],
          ),
        ],
      );
    }
  }

  // --- 2. GOOGLE ASSISTANT & QUICK SETTINGS MOCKUP ---
  Widget _buildAssistantMockup() {
    if (stepIndex == 0) {
      // Step 1: Hey Google Voice Command
      return Column(
        children: [
          const SizedBox(height: 14),
          const Icon(
            Icons.assistant_rounded,
            color: Colors.blueAccent,
            size: 36,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
            ),
            child: const Column(
              children: [
                Text(
                  '"Hey Google, log 250 rupees for groceries on Manikutti"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'or in Malayalam: "മണിക്കുട്ടിയിൽ 250 രൂപ പലചരക്ക് കുറിക്കുക"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF93C5FD), fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Waveform bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _waveBar(12, Colors.blue),
              const SizedBox(width: 3),
              _waveBar(24, Colors.red),
              const SizedBox(width: 3),
              _waveBar(32, Colors.amber),
              const SizedBox(width: 3),
              _waveBar(20, Colors.green),
              const SizedBox(width: 3),
              _waveBar(10, Colors.blue),
            ],
          ),
        ],
      );
    } else if (stepIndex == 1) {
      // Step 2: Floating Translucent Overlay
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2DD4BF), width: 1.5),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, color: Color(0xFF2DD4BF), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Manikutti Quick Voice',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '₹250 • Grocery • Saved',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Saved instantly & closed overlay',
                  style: TextStyle(color: Colors.white54, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Step 3: Quick Settings Notification Shade Tile
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Notification Shade (Quick Settings)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            childAspectRatio: 2.8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildTile(Icons.wifi, 'Wi-Fi', true),
              _buildTile(Icons.bluetooth, 'Bluetooth', false),
              _buildTile(Icons.flashlight_on, 'Flashlight', false),
              // Custom Manikutti Tile Highlighted!
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF34D399),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mic_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Manikutti Mic',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '1-Tap Record',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  // --- 3. BANK STATEMENT MOCKUP ---
  Widget _buildStatementMockup() {
    if (stepIndex == 0) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SBI_Account_Statement.pdf',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Canara, HDFC, SBI & others',
                        style: TextStyle(color: Colors.white60, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Decrypted securely on your phone',
            style: TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      );
    } else if (stepIndex == 1) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber),
            ),
            child: const Row(
              children: [
                Icon(Icons.filter_alt_rounded, color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Smart Duplicate Protection: 5 existing transactions skipped automatically',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '14 New Entries Found',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'Ready to Import',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _miniTxItem(
                  'Grocery - Reliance Fresh',
                  '-₹840',
                  Colors.redAccent,
                ),
                const Divider(color: Colors.white12, height: 8),
                _miniTxItem('Salary Credit', '+₹45,000', Colors.greenAccent),
                const Divider(color: Colors.white12, height: 8),
                _miniTxItem('Electricity Bill', '-₹1,250', Colors.redAccent),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              minimumSize: const Size(double.infinity, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {},
            child: const Text(
              'Confirm Import',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      );
    }
  }

  // --- 4. BIOMETRIC MOCKUP ---
  Widget _buildBiometricMockup() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E293B),
            border: Border.all(color: AppTheme.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.35),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(
            Icons.fingerprint_rounded,
            color: AppTheme.primary,
            size: 48,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Manikutti App Lock',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Touch fingerprint sensor or enter PIN',
          style: TextStyle(color: Colors.white60, fontSize: 10),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < 2 ? AppTheme.primary : Colors.white24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 5. VOICE LOGGING MOCKUP ---
  Widget _buildVoiceMockup() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2B26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2DD4BF)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Color(0xFF2DD4BF), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Listening (മലയാളം / English)...',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '"100 roopakku petrol adichu"',
                style: TextStyle(
                  color: Color(0xFF5EEAD4),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF134E48),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Auto-Category: Fuel',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    Text(
                      'Amount: ₹100',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 6. FAMILY SANCTUARY MOCKUP ---
  Widget _buildFamilyMockup() {
    const roseColor = Color(0xFFF43F5E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: roseColor.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.family_restroom, color: roseColor, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Shared Household Budget',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.65,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(roseColor),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: ₹18,500',
                    style: TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                  Text(
                    'Budget: ₹30,000',
                    style: TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 7. ROADMAP SNEAK PEEK MOCKUP ---
  Widget _buildRoadmapMockup() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.purpleAccent),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.document_scanner_rounded,
                color: Colors.purpleAccent,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Receipt Camera',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Auto-reads paper supermarket bills',
                      style: TextStyle(color: Colors.white60, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amberAccent),
          ),
          child: const Row(
            children: [
              Icon(Icons.savings_rounded, color: Colors.amberAccent, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goal Savings Jars',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Target savings for festivals & trips',
                      style: TextStyle(color: Colors.white60, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helpers
  Widget _buildDummyAppIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ],
    );
  }

  Widget _waveBar(double height, Color color) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTile(IconData icon, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.blueAccent : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTxItem(String title, String amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
