import 'package:flutter/material.dart';
import '../models/app_feature_info.dart';
import '../theme/app_theme.dart';
import '../widgets/screenshot_tutorial_stepper.dart';
import '../widgets/voice_logging_sheet.dart';
import 'bank_statement_screen.dart';
import 'setup_app_lock_screen.dart';
import 'loans_emi_screen.dart';
import 'mobile_recharges_screen.dart';
import 'add_transaction_screen.dart';

class FeatureDetailScreen extends StatelessWidget {
  final AppFeature feature;

  const FeatureDetailScreen({
    super.key,
    required this.feature,
  });

  void _handleAction(BuildContext context) {
    final routeId = feature.actionRouteId;
    if (routeId == null) return;

    switch (routeId) {
      case 'voice_logging':
        VoiceLoggingSheet.show(context);
        break;
      case 'bank_statement':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BankStatementScreen()),
        );
        break;
      case 'app_lock':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SetupAppLockScreen()),
        );
        break;
      case 'loans':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoansEmiScreen()),
        );
        break;
      case 'recharges':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MobileRechargesScreen()),
        );
        break;
      case 'add_expense':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        );
        break;
      case 'dashboard':
      case 'settings':
      case 'home_widget':
      default:
        Navigator.pop(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          feature.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Hero Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        feature.accentColor.withOpacity(0.25),
                        AppTheme.darkSurfaceContainerLowest,
                      ]
                    : [
                        feature.accentColor.withOpacity(0.12),
                        AppTheme.surfaceContainerLowest,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: feature.accentColor.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: AppTheme.ambientCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: feature.accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: feature.accentColor.withOpacity(0.5),
                        ),
                      ),
                      child: Icon(
                        feature.icon,
                        color: feature.accentColor,
                        size: 32,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceContainer
                                : AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            feature.category,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: feature.accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: feature.accentColor.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            feature.badge,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark
                                  ? Colors.white
                                  : feature.accentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  feature.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feature.shortTagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppTheme.darkOnSurfaceVariant
                        : AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // User Overview Section
          Text(
            'About this Feature',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceContainerLowest
                  : AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2C3233)
                    : AppTheme.outlineVariant.withOpacity(0.18),
              ),
              boxShadow: AppTheme.ambientCardShadow,
            ),
            child: Text(
              feature.userOverview,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Screenshot Tutorial Walkthrough (if steps exist)
          if (feature.hasTutorial) ...[
            Row(
              children: [
                const Icon(
                  Icons.slideshow_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Visual Step-by-Step Guide',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ScreenshotTutorialStepper(steps: feature.tutorialSteps),
            const SizedBox(height: 24),
          ],

          // Key Highlights / Benefits
          Text(
            'Key Benefits & Highlights',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceContainerLowest
                  : AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2C3233)
                    : AppTheme.outlineVariant.withOpacity(0.18),
              ),
              boxShadow: AppTheme.ambientCardShadow,
            ),
            child: Column(
              children: feature.keyBenefits.map((benefit) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: feature.accentColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: feature.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          benefit,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 28),

          // Action Button
          if (feature.actionLabel != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: feature.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: () => _handleAction(context),
              icon: Icon(feature.icon, size: 20),
              label: Text(
                feature.actionLabel!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
