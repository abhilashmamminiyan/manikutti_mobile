import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_drawer.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setup_app_lock_screen.dart';
import 'about_app_screen.dart';
import 'whats_new_screen.dart';
import 'notification_settings_screen.dart';
import 'category_preferences_screen.dart';
import 'payee_rules_screen.dart';
import '../services/whats_new_service.dart';
import '../services/feature_flag_service.dart';
import '../theme/app_theme.dart';
import '../widgets/color_picker_dialog.dart';

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
                      color: AppTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      MyApp.getThemeStyle(context) == ThemeStyle.paper
                          ? Icons.menu_book_rounded
                          : Icons.auto_awesome_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Theme Design Style',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    MyApp.getThemeStyle(context) == ThemeStyle.paper
                        ? 'Paper Diary (Handwritten parchment)'
                        : 'Modern Sanctuary (Material 3)',
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
                      child: DropdownButton<ThemeStyle>(
                        value: MyApp.getThemeStyle(context),
                        dropdownColor: isDark
                            ? AppTheme.darkSurfaceContainer
                            : AppTheme.surfaceContainerLowest,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.primary,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: ThemeStyle.modern,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Modern',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeStyle.paper,
                            child: Row(
                              children: [
                                const Icon(Icons.menu_book_rounded, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Paper Theme',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (newStyle) {
                          if (newStyle == null ||
                              newStyle == MyApp.getThemeStyle(context)) {
                            return;
                          }

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogCtx) => AlertDialog(
                              title: Row(
                                children: [
                                  const Icon(
                                    Icons.restart_alt_rounded,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Restart Required'),
                                ],
                              ),
                              content: Text(
                                newStyle == ThemeStyle.paper
                                    ? 'Switching to the Paper Theme completely transforms the app from login to dashboard into an authentic, tactile lined-paper diary with fountain pen fonts and morph page transitions.\n\nRestart the app now to apply?'
                                    : 'Switching to the Modern Theme restores clean Material 3 surfaces, gradients, and modern typography.\n\nRestart the app now to apply?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Later'),
                                ),
                                FilledButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogCtx);
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                      'theme_style',
                                      newStyle == ThemeStyle.paper
                                          ? 'paper'
                                          : 'modern',
                                    );
                                    if (context.mounted) {
                                      MyApp.setThemeStyle(context, newStyle);
                                      MyApp.restartApp(context);
                                    }
                                  },
                                  child: const Text('Restart Now'),
                                ),
                              ],
                            ),
                          );
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Theme Accent Color',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Choose a palette color or pick your own',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                  trailing: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final current = MyApp.getPrimaryColor(context);
                      final picked = await showDialog<Color>(
                        context: context,
                        builder: (_) =>
                            ColorPickerDialog(initialColor: current),
                      );
                      if (picked != null && context.mounted) {
                        MyApp.setPrimaryColor(context, picked);
                      }
                    },
                    icon: const Icon(Icons.colorize_rounded, size: 16),
                    label: const Text('Picker'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in const [
                          Color(0xFF006972), // Signature Deep Teal
                          Color(0xFF0D9488), // Fresh Mint Teal
                          Color(0xFF1E40AF), // Deep Royal Indigo
                          Color(0xFF0284C7), // Sky Blue
                          Color(0xFF16A34A), // Emerald Green
                          Color(0xFFD97706), // Warm Amber
                          Color(0xFFBE123C), // Crimson Rose
                          Color(0xFF7C3AED), // Royal Purple
                          Color(0xFFE11D48), // Ruby Red
                          Color(0xFF475569), // Slate Monochrome
                        ])
                          GestureDetector(
                            onTap: () => MyApp.setPrimaryColor(context, c),
                            child: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      MyApp.getPrimaryColor(context).value ==
                                          c.value
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child:
                                  MyApp.getPrimaryColor(context).value ==
                                      c.value
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                      ],
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
                ValueListenableBuilder<Map<String, bool>>(
                  valueListenable:
                      FeatureFlagService.instance.permissionsNotifier,
                  builder: (context, _, _) {
                    final flags = FeatureFlagService.instance;
                    final activeRole = flags.isLocalOverrideActive
                        ? flags.roleName
                        : 'Server';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Role View Preview (Testing)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        flags.isLocalOverrideActive
                            ? 'Testing as ${flags.roleName} (Override Active)'
                            : 'Active: ${flags.roleName} (Server Default)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurfaceContainer
                              : AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                [
                                  'Admin',
                                  'Basic',
                                  'Demo',
                                  'Member',
                                ].contains(activeRole)
                                ? activeRole
                                : 'Server',
                            dropdownColor: isDark
                                ? AppTheme.darkSurfaceContainer
                                : AppTheme.surfaceContainerLowest,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.primary,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Basic',
                                child: Text('Basic (Focused Family)'),
                              ),
                              DropdownMenuItem(
                                value: 'Demo',
                                child: Text('Demo (SMS Auto-Pay)'),
                              ),
                              DropdownMenuItem(
                                value: 'Admin',
                                child: Text('Admin (Full Hub)'),
                              ),
                              DropdownMenuItem(
                                value: 'Member',
                                child: Text('Member (Personal Ledger)'),
                              ),
                              DropdownMenuItem(
                                value: 'Server',
                                child: Text('Server Default (Auto)'),
                              ),
                            ],
                            onChanged: (val) async {
                              if (val == null) return;
                              if (val == 'Server') {
                                await FeatureFlagService.instance
                                    .clearLocalOverride();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Switched to Server Role (Auto)',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                await FeatureFlagService.instance
                                    .setLocalRoleOverride(val);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Switched to $val View Preview!',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
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
                      color: const Color(0xFF0F766E).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Color(0xFF0F766E),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Notifications',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Voice alerts, salary & bill reminders, permissions',
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
                        builder: (context) =>
                            const NotificationSettingsScreen(),
                      ),
                    );
                  },
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
                      color: const Color(0xFF0284C7).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Expense Categories',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Customize categories for app & home screen widget',
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
                        builder: (context) => const CategoryPreferencesScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rule_folder_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Payee & Screenshot Rules',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Map phone numbers or names to fixed categories & Home Loan',
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
                        builder: (context) => const PayeeRulesScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // App Information & Feature Guides Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              l10n.appInformation,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppTheme.darkOnSurfaceVariant
                    : AppTheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
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
                      color: AppTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l10n.aboutApp,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    l10n.aboutAppSubtitle,
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
                        builder: (context) => const AboutAppScreen(),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: isDark
                        ? const Color(0xFF2C3233)
                        : AppTheme.outlineVariant.withOpacity(0.15),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: WhatsNewService.instance.hasUnreadNotifier,
                  builder: (context, hasUnread, _) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.new_releases_rounded,
                          color: Color(0xFF16A34A),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            l10n.whatsNew,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        l10n.whatsNewSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasUnread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppTheme.outlineVariant,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WhatsNewScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'The Heritage Ledger • Version ${WhatsNewService.currentVersion} • Offline First',
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
