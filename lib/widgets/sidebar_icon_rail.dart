import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/bills_dashboard.dart';
import '../screens/loans_emi_screen.dart';
import '../screens/home_loan_screen.dart';
import '../screens/mobile_recharges_screen.dart';
import '../screens/smart_scan_screen.dart';
import '../screens/screenshots_screen.dart';
import '../screens/bank_statement_screen.dart';
import '../screens/settings_screen.dart';
import '../services/whats_new_service.dart';

/// Top-left pulsing arrow button designed to replace the standard hamburger icon.
/// Continuously pulses with a subtle glow, pointing to the right to signify
/// opening the full sidebar drawer.
class PulsingArrowButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const PulsingArrowButton({
    super.key,
    required this.onTap,
    this.size = 20.0,
  });

  @override
  State<PulsingArrowButton> createState() => _PulsingArrowButtonState();
}

class _PulsingArrowButtonState extends State<PulsingArrowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Open Sidebar / സൈഡ്ബാർ തുറക്കുക',
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact vertical sidebar rail displayed on the left side of the screen.
/// Provides direct 1-tap access to all key features via their icons,
/// while keeping the UI clean and spacious.
class SidebarIconRail extends StatelessWidget {
  final String activeRoute;
  final VoidCallback onOpenDrawer;

  const SidebarIconRail({
    super.key,
    this.activeRoute = 'dashboard',
    required this.onOpenDrawer,
  });

  Widget _buildRailItem({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
    bool hasBadge = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = AppTheme.primary;
    final inactiveColor = isDark
        ? AppTheme.darkOnSurfaceVariant.withValues(alpha: 0.85)
        : AppTheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        verticalOffset: 20,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isActive
                    ? Border.all(
                        color: activeColor.withValues(alpha: 0.4),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                  if (hasBadge)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? AppTheme.darkSurfaceContainer.withValues(alpha: 0.85)
        : AppTheme.surfaceContainerLowest.withValues(alpha: 0.95);

    final borderColor = isDark
        ? const Color(0xFF2C3233)
        : AppTheme.outlineVariant.withValues(alpha: 0.35);

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top quick-open handle pointing into the full sidebar
            Tooltip(
              message: 'Full Sidebar / മുഴുവൻ മെനു',
              child: InkWell(
                onTap: onOpenDrawer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Icon(
                    Icons.view_sidebar_rounded,
                    size: 20,
                    color: isDark ? AppTheme.darkOnSurface : AppTheme.primary,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              height: 1,
              color: borderColor,
            ),

            // 1. Dashboard
            _buildRailItem(
              context: context,
              icon: Icons.dashboard_rounded,
              tooltip: 'Dashboard / ഡാഷ്‌ബോർഡ്',
              isActive: activeRoute == 'dashboard',
              onTap: () {
                if (activeRoute != 'dashboard') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                }
              },
            ),

            // 2. Bills & Utilities
            _buildRailItem(
              context: context,
              icon: Icons.receipt_long_rounded,
              tooltip: 'Bills / ബില്ലുകൾ',
              isActive: activeRoute == 'bills',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const BillsDashboard()),
                );
              },
            ),

            // 3. Loans & EMI
            _buildRailItem(
              context: context,
              icon: Icons.account_balance_rounded,
              tooltip: 'Loans & EMI / വായ്പകൾ',
              isActive: activeRoute == 'loans',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoansEmiScreen()),
                );
              },
            ),

            // 4. Home Loan
            _buildRailItem(
              context: context,
              icon: Icons.home_work_rounded,
              tooltip: 'Home Loan / ഭവന വായ്പ',
              isActive: activeRoute == 'home_loan',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeLoanScreen()),
                );
              },
            ),

            // 5. Mobile Recharges
            _buildRailItem(
              context: context,
              icon: Icons.phone_android_rounded,
              tooltip: 'Mobile Recharges / റീചാർജ്',
              isActive: activeRoute == 'recharges',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MobileRechargesScreen()),
                );
              },
            ),

            // 6. Smart Scan
            _buildRailItem(
              context: context,
              icon: Icons.document_scanner_rounded,
              tooltip: 'Smart Scan / സ്കാൻ',
              isActive: activeRoute == 'smart_scan',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SmartScanScreen()),
                );
              },
            ),

            // 7. Screenshots
            _buildRailItem(
              context: context,
              icon: Icons.image_search_rounded,
              tooltip: 'Screenshots / സ്ക്രീൻഷോട്ടുകൾ',
              isActive: activeRoute == 'screenshots',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ScreenshotsScreen()),
                );
              },
            ),

            // 8. Bank Statement
            _buildRailItem(
              context: context,
              icon: Icons.upload_file_rounded,
              tooltip: 'Bank Statement / സ്റ്റേറ്റ്‌മെന്റ്',
              isActive: activeRoute == 'bank_statement',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BankStatementScreen()),
                );
              },
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              height: 1,
              color: borderColor,
            ),

            // 9. Settings with unread update indicator
            ValueListenableBuilder<bool>(
              valueListenable: WhatsNewService.instance.hasUnreadNotifier,
              builder: (context, hasUnread, _) {
                return _buildRailItem(
                  context: context,
                  icon: Icons.settings_rounded,
                  tooltip: 'Settings / ക്രമീകരണങ്ങൾ',
                  isActive: activeRoute == 'settings',
                  hasBadge: hasUnread,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
