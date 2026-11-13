import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../screens/dashboard_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/smart_scan_screen.dart';
import '../screens/bills_dashboard.dart';
import '../screens/loans_emi_screen.dart';
import '../screens/home_loan_screen.dart';
import '../screens/mobile_recharges_screen.dart';
import '../screens/screenshots_screen.dart';
import '../screens/bank_statement_screen.dart';
import '../services/api_service.dart';
import '../services/feature_flag_service.dart';
import '../services/whats_new_service.dart';
import '../screens/login_screen.dart';
import '../screens/about_app_screen.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool hasBadge = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPaper = AppTheme.isPaper(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isPaper ? 12 : 16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? AppTheme.error.withOpacity(0.1)
                        : (isPaper
                            ? (isDark ? AppTheme.paperDarkCard : AppTheme.paperContainerLow)
                            : (isDark
                                ? AppTheme.darkSurfaceContainer
                                : AppTheme.surfaceContainerLow)),
                    shape: isPaper ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isPaper ? BorderRadius.circular(10) : null,
                    border: isPaper
                        ? Border.all(
                            color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2DDD5),
                          )
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isDestructive
                        ? AppTheme.error
                        : (isPaper
                            ? (isDark ? AppTheme.paperTabBlue : AppTheme.paperInkNavy)
                            : (isDark ? AppTheme.darkOnSurface : AppTheme.primary)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? AppTheme.error
                          : (isPaper
                              ? (isDark ? AppTheme.paperDarkInk : AppTheme.paperInkNavy)
                              : (isDark
                                    ? AppTheme.darkOnSurface
                                    : AppTheme.onSurface)),
                    ),
                  ),
                ),
                if (hasBadge)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark
                      ? AppTheme.darkOnSurfaceVariant.withOpacity(0.5)
                      : AppTheme.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPaper = AppTheme.isPaper(context);

    return Drawer(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(isPaper ? 18 : 28)),
      ),
      backgroundColor: isPaper
          ? (isDark ? AppTheme.paperDarkBackground : AppTheme.paperSurface)
          : (isDark ? AppTheme.darkSurface : AppTheme.surface),
      child: SafeArea(
        child: Column(
          children: [
            // Editorial Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isPaper
                      ? LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF2B1F17), const Color(0xFF1E1712)]
                              : [AppTheme.paperLeatherDark, AppTheme.paperLeatherMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : AppTheme.heroCardGradient,
                  borderRadius: BorderRadius.circular(isPaper ? 16 : 24),
                  border: isPaper
                      ? Border.all(
                          color: const Color(0xFFD4AF37).withOpacity(0.4),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: isPaper ? AppTheme.paperCardShadow : AppTheme.editorialShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isPaper ? Icons.menu_book_rounded : Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPaper
                                  ? const Color(0xFFD4AF37).withOpacity(0.3)
                                  : AppTheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isPaper ? 'DIARY LEDGER' : 'SANCTUARY',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isPaper ? Colors.white : AppTheme.onSecondaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.appTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Navigation List
            Expanded(
              child: ValueListenableBuilder<Map<String, bool>>(
                valueListenable:
                    FeatureFlagService.instance.permissionsNotifier,
                builder: (context, perms, _) {
                  final flags = FeatureFlagService.instance;
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.dashboard_rounded,
                        title: l10n.dashboard,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DashboardScreen(),
                            ),
                          );
                        },
                      ),
                      if (flags.isEnabled(FeatureKeys.billsUtilities))
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.receipt_long_rounded,
                          title: l10n.bills,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BillsDashboard(),
                              ),
                            );
                          },
                        ),
                      if (flags.isEnabled(FeatureKeys.loansEmiLedger))
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.account_balance_rounded,
                          title: l10n.loansAndEmi,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoansEmiScreen(),
                              ),
                            );
                          },
                        ),
                      if (flags.isEnabled(FeatureKeys.homeLoan))
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.home_work_rounded,
                          title: l10n.homeLoan,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomeLoanScreen(),
                              ),
                            );
                          },
                        ),
                      if (flags.isEnabled(FeatureKeys.mobileRecharges))
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.phone_android_rounded,
                          title: l10n.mobileRecharges,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MobileRechargesScreen(),
                              ),
                            );
                          },
                        ),
                      if (flags.isEnabled(FeatureKeys.smartScan))
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.document_scanner_rounded,
                          title: l10n.smartScan,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SmartScanScreen(),
                              ),
                            );
                          },
                        ),
                      if (flags.isEnabled(FeatureKeys.screenshots))
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.image_search_rounded,
                          title: l10n.screenshots,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScreenshotsScreen(),
                              ),
                            );
                          },
                        ),
                      if (flags.isEnabled(FeatureKeys.bankStatement))
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.upload_file_rounded,
                          title: l10n.bankStatement,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BankStatementScreen(),
                              ),
                            );
                          },
                        ),
                      if (flags.isEnabled(FeatureKeys.aboutApp))
                        _buildDrawerItem(
                          context: context,
                          icon: Icons.auto_awesome_rounded,
                          title: l10n.aboutApp,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AboutAppScreen(),
                              ),
                            );
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Divider(
                          color: isDark
                              ? const Color(0xFF2C3233)
                              : AppTheme.outlineVariant.withOpacity(0.25),
                          thickness: 1,
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            WhatsNewService.instance.hasUnreadNotifier,
                        builder: (context, hasUnread, _) {
                          return _buildDrawerItem(
                            context: context,
                            icon: Icons.settings_rounded,
                            title: l10n.settings,
                            hasBadge: hasUnread,
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.logout_rounded,
                        title: l10n.logout,
                        isDestructive: true,
                        onTap: () async {
                          await ApiService.instance.clearSession();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Subtle Footer
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                isPaper ? 'The Paper Ledger • Handwritten Aesthetic' : 'The Heritage Ledger • Offline First',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppTheme.darkOnSurfaceVariant.withOpacity(0.5)
                      : AppTheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
