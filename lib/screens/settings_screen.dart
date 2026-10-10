import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setup_app_lock_screen.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurfaceContainerLowest
                  : AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.ambientCardShadow,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2C3233)
                    : AppTheme.outlineVariant.withOpacity(0.18),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.language_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l10n.language,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceContainer
                          : AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: Localizations.localeOf(context).languageCode,
                        dropdownColor: isDark
                            ? AppTheme.darkSurfaceContainer
                            : AppTheme.surfaceContainerLowest,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.primary,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(
                              'English',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ml',
                            child: Text(
                              'മലയാളം',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('languageCode', value);
                            if (context.mounted) {
                              MyApp.setLocale(context, Locale(value));
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: isDark
                        ? const Color(0xFF2C3233)
                        : AppTheme.outlineVariant.withOpacity(0.15),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? AppTheme.primaryContainer
                                  : AppTheme.primary)
                              .withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: isDark
                          ? AppTheme.primaryContainer
                          : AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Theme Mode',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Light, dark, or system preference',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceContainer
                          : AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ThemeMode>(
                        value: MyApp.getThemeMode(context),
                        dropdownColor: isDark
                            ? AppTheme.darkSurfaceContainer
                            : AppTheme.surfaceContainerLowest,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.primary,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text(
                              'System',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text(
                              'Light',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text(
                              'Dark',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                        onChanged: (mode) async {
                          if (mode != null) {
                            final prefs = await SharedPreferences.getInstance();
                            final str = mode == ThemeMode.light
                                ? 'light'
                                : (mode == ThemeMode.dark ? 'dark' : 'system');
                            await prefs.setString('themeMode', str);
                            if (context.mounted) {
                              MyApp.setThemeMode(context, mode);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: isDark
                        ? const Color(0xFF2C3233)
                        : AppTheme.outlineVariant.withOpacity(0.15),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: AppTheme.secondary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'App Lock',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Require PIN or Biometrics on launch',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.outlineVariant,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SetupAppLockScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'The Heritage Ledger • Version 2.1.0',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AppTheme.darkOnSurfaceVariant.withOpacity(0.5)
                    : AppTheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
