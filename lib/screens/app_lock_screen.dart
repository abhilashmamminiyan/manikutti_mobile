import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlock;

  const AppLockScreen({super.key, required this.onUnlock});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _pinController = TextEditingController();

  String _savedPin = '';
  String _userEmail = '';
  String _errorMessage = '';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _loadPinAndAuthenticate();
  }

  Future<void> _loadPinAndAuthenticate() async {
    final pin = await ApiService.instance.getPin();
    final email = await ApiService.instance.getUserEmail();
    if (pin != null && pin.length == 4) {
      _savedPin = pin;
    }
    if (email != null) {
      setState(() {
        _userEmail = email;
      });
    }

    // Automatically trigger biometrics if available
    _authenticateWithBiometrics();
  }

  Future<void> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
      });
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        authenticated = await auth.authenticate(
          localizedReason: 'Please authenticate to unlock Manikutti Finance',
          persistAcrossBackgrounding: true,
          biometricOnly: false,
        );
      }
    } on PlatformException catch (e) {
      print('Biometric error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }

    if (authenticated) {
      widget.onUnlock();
    }
  }

  void _verifyPin() {
    final enteredPin = _pinController.text.trim();
    if (enteredPin == _savedPin) {
      widget.onUnlock();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _pinController.clear();
      });
    }
  }

  Future<void> _handleForgotPin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset PIN / Relogin'),
        content: const Text(
          'Do you want to clear saved credentials and log in again using Email & OTP?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reset & Relogin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.instance.clearAuth();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
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

    return PopScope(
      canPop: false, // Prevent back button from bypassing lock
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sanctuary Brand Lock Emblem
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceContainerLowest : AppTheme.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.editorialShadow,
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.12),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primary.withOpacity(0.15),
                                AppTheme.primaryContainer.withOpacity(0.25),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock_person_rounded,
                              size: 32,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryContainer.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'SANCTUARY LOCKED',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (_userEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _userEmail,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Enter your 4-digit PIN to access your ledger',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // PIN Container Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceContainerLowest : AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppTheme.ambientCardShadow,
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C3233) : AppTheme.outlineVariant.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                            prefixIcon: const Icon(Icons.pin_rounded, color: AppTheme.primary),
                          ),
                          onChanged: (value) {
                            if (value.length == 4) {
                              _verifyPin();
                            }
                          },
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
                            onPressed: _verifyPin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            child: Text(
                              'Unlock Sanctuary',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                              icon: const Icon(Icons.fingerprint_rounded, size: 22, color: AppTheme.primary),
                              label: Text(
                                'Biometrics',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _handleForgotPin,
                              child: Text(
                                'Forgot PIN?',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.outline,
                                  fontWeight: FontWeight.w600,
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
            ),
          ),
        ),
      ),
    );
  }
}
