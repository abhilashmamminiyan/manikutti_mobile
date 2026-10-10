import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SetupAppLockScreen extends StatefulWidget {
  const SetupAppLockScreen({super.key});

  @override
  State<SetupAppLockScreen> createState() => _SetupAppLockScreenState();
}

class _SetupAppLockScreenState extends State<SetupAppLockScreen> {
  bool _isLockEnabled = false;
  final TextEditingController _pinController = TextEditingController();
  String _errorMessage = '';
  bool _hasSavedPin = false;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final savedPin = await ApiService.instance.getPin();
    final hasPin = savedPin != null && savedPin.length == 4;

    setState(() {
      _isLockEnabled = hasPin;
      _hasSavedPin = hasPin;
    });
  }

  Future<void> _toggleLock(bool value) async {
    if (!value) {
      // Disabling lock
      await ApiService.instance.clearPin();
      setState(() {
        _isLockEnabled = false;
        _hasSavedPin = false;
        _pinController.clear();
        _errorMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App Lock disabled.')));
      }
    } else {
      setState(() {
        _isLockEnabled = true;
      });
    }
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() {
        _errorMessage = 'PIN must be exactly 4 digits.';
      });
      return;
    }

    await ApiService.instance.savePin(pin);

    setState(() {
      _errorMessage = '';
      _hasSavedPin = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App Lock enabled successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Security & App Lock',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceContainerLowest
                    : AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.ambientCardShadow,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2C3233)
                      : AppTheme.outlineVariant.withOpacity(0.18),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: AppTheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sanctuary Protection',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Require 4-digit PIN or Biometrics on app launch',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppTheme.darkOnSurfaceVariant
                                    : AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isLockEnabled,
                        onChanged: _toggleLock,
                        activeColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isLockEnabled && !_hasSavedPin) ...[
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceContainerLowest
                      : AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.ambientCardShadow,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2C3233)
                        : AppTheme.outlineVariant.withOpacity(0.18),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CREATE SECURITY PIN',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 16.0,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        errorText: _errorMessage.isEmpty ? null : _errorMessage,
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _savePin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(
                          'Save PIN & Secure App',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isLockEnabled && _hasSavedPin) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF10B981),
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'App Lock is Active',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your 4-digit PIN is stored securely in encrypted storage.',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkOnSurfaceVariant
                                  : AppTheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
