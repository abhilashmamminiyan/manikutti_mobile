import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_logging_sheet.dart';


class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _systemNotificationsEnabled = true;

  // Toggle States
  bool _voiceExpenseEnabled = true;
  bool _salaryRemindersEnabled = true;
  bool _billRemindersEnabled = true;
  bool _familyAlertsEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check system permission when user returns from phone settings
      _checkSystemPermission();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final systemEnabled = await NotificationService.instance
        .areNotificationsEnabled();

    if (mounted) {
      setState(() {
        _systemNotificationsEnabled = systemEnabled;
        _voiceExpenseEnabled =
            prefs.getBool('key_voice_notifications_enabled') ?? true;
        _salaryRemindersEnabled =
            prefs.getBool('key_salary_notifications_enabled') ?? true;
        _billRemindersEnabled =
            prefs.getBool('key_bill_due_notifications_enabled') ?? true;
        _familyAlertsEnabled =
            prefs.getBool('key_payment_notifications_enabled') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkSystemPermission() async {
    final systemEnabled = await NotificationService.instance
        .areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _systemNotificationsEnabled = systemEnabled;
      });
    }
  }

  Future<void> _setPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _handleSendTest() async {
    if (!_systemNotificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Notifications are blocked in Android Settings. Please enable them first.',
          ),
          backgroundColor: Colors.amber.shade900,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () =>
                NotificationService.instance.openSystemNotificationSettings(),
          ),
        ),
      );
      return;
    }

    await NotificationService.instance.sendTestNotification();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🔔 Test notification sent! Check your notification drawer.',
          ),
          backgroundColor: Color(0xFF0F766E),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleSyncShortcuts() async {
    try {
      const channel = MethodChannel('com.abhilash.manikutti/settings');
      await channel.invokeMethod('publishShortcuts');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚡ Dynamic Shortcuts published for Google Assistant & OS!',
            ),
            backgroundColor: Color(0xFF0F766E),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish shortcuts: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. System Permission Status Card
                _buildSystemPermissionCard(theme, isDark),
                const SizedBox(height: 20),

                // 2. Notification Preferences Section Header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'NOTIFICATION PREFERENCES',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkOnSurfaceVariant
                          : AppTheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                // 3. Toggles Container
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
                      // Voice & Widget Confirmation Alerts
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Color(0xFF0F766E),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Voice & Widget Confirmations',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Show immediate alert in the shade when an expense is logged via voice or widget',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                        value: _voiceExpenseEnabled,
                        activeColor: const Color(0xFF0F766E),
                        onChanged: (val) {
                          setState(() => _voiceExpenseEnabled = val);
                          _setPreference(
                            'key_voice_notifications_enabled',
                            val,
                          );
                        },
                      ),
                      _buildDivider(isDark),

                      // Salary Prompt Reminders
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Salary Reminders',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Prompt on day 4 & 5 each month to record your incoming salary',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                        value: _salaryRemindersEnabled,
                        activeColor: const Color(0xFF0F766E),
                        onChanged: (val) {
                          setState(() => _salaryRemindersEnabled = val);
                          _setPreference(
                            'key_salary_notifications_enabled',
                            val,
                          );
                        },
                      ),
                      _buildDivider(isDark),

                      // Recharge & Bill Reminders
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Bills & Recharge Due Alerts',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Alert before validity expires for mobile recharges and recurring utilities',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                        value: _billRemindersEnabled,
                        activeColor: const Color(0xFF0F766E),
                        onChanged: (val) {
                          setState(() => _billRemindersEnabled = val);
                          _setPreference(
                            'key_bill_due_notifications_enabled',
                            val,
                          );
                        },
                      ),
                      _buildDivider(isDark),

                      // Family Shared Finance Alerts
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFF7C3AED),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Family Commitment Alerts',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Notify when a family commitment or dues are settled in the shared ledger',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.darkOnSurfaceVariant
                                : AppTheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                        value: _familyAlertsEnabled,
                        activeColor: const Color(0xFF0F766E),
                        onChanged: (val) {
                          setState(() => _familyAlertsEnabled = val);
                          _setPreference(
                            'key_payment_notifications_enabled',
                            val,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Test Notification Button Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Color(0xFF0F766E),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Verify Notification Delivery',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the button below to test whether your device receives and displays the voice expense confirmation in your Android notification shade.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant.withOpacity(0.7),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _handleSendTest,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text(
                            'Send Test Notification',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Google Assistant & Shortcuts Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: Color(0xFF3B82F6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Google Assistant & Deep Links',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Push dynamic shortcuts to your device so "Voice Expense" appears inside Google Assistant Settings > Shortcuts and responds to voice commands.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.onSurfaceVariant.withOpacity(0.7),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : Colors.black.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verified Deep Link URL:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              'https://manikutti.vercel.app/voice-dialog',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _handleSyncShortcuts,
                                icon: const Icon(Icons.sync_rounded, size: 16),
                                label: const Text(
                                  'Sync Shortcuts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  side: const BorderSide(
                                    color: Color(0xFF3B82F6),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  VoiceLoggingSheet.show(context);
                                },
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Test Voice UI',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSystemPermissionCard(ThemeData theme, bool isDark) {
    if (_systemNotificationsEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Notifications Active',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF14532D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Android permissions are granted. Alerts appear in your notification shade.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : const Color(0xFF166534),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFFD97706) : const Color(0xFFFCD34D),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notifications Blocked by Android',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF78350F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your device has disabled notifications for Manikutti. Voice confirmation alerts, salary reminders, and bill alerts will NOT appear in your notification shade until enabled.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : const Color(0xFF92400E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  NotificationService.instance.openSystemNotificationSettings();
                },
                icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                label: const Text(
                  'Enable in Android Settings',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: isDark
            ? const Color(0xFF2C3233)
            : AppTheme.outlineVariant.withOpacity(0.15),
      ),
    );
  }
}
