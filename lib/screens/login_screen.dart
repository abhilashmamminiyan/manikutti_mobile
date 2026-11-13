import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'dashboard_screen.dart';
import 'app_lock_screen.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final String? initialAccessCode;
  final bool autoSubmitAccessCode;

  const LoginScreen({
    super.key,
    this.initialAccessCode,
    this.autoSubmitAccessCode = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final _urlController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _useFamilyCodeMode = true;
  String _errorMessage = '';
  String _successMessage = '';
  String? _verificationToken;
  bool _isOtpStep = false;
  bool _isPinStep = false;
  bool _hasSavedPin = false;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
    _checkSavedCredentials();
    final initialCode = widget.initialAccessCode?.trim();
    if (initialCode != null && initialCode.isNotEmpty) {
      _useFamilyCodeMode = true;
      _accessCodeController.text = initialCode.toUpperCase();
      if (widget.autoSubmitAccessCode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleFamilyCodeLogin();
        });
      }
    }
  }

  Future<void> _checkSavedCredentials() async {
    final email = await ApiService.instance.getUserEmail();
    final hasPin = await ApiService.instance.hasPin();
    if (mounted) {
      setState(() {
        if (email != null &&
            email.isNotEmpty &&
            _emailController.text.isEmpty) {
          _emailController.text = email;
        }
        _hasSavedPin = hasPin;
      });
    }
  }

  Future<void> _loadBaseUrl() async {
    final url = await ApiService.instance.getBaseUrl();
    _urlController.text = url;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _accessCodeController.dispose();
    _urlController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  // Handle setting/changing the base API URL
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Configure Backend URL',
          style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the Vercel app URL or local development server address.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Base API URL',
                hintText: 'https://manikutti.vercel.app',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.instance.setBaseUrl(_urlController.text.trim());
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('API Base URL updated successfully.'),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFamilyCodeLogin() async {
    final code = _accessCodeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _errorMessage = 'Please enter your family access code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final result = await ApiService.instance.loginWithFamilyCode(code);
      SyncService.instance.syncData();
      final hasSavedPin = await ApiService.instance.hasPin();
      final name = (result['nickname']?.toString().trim().isNotEmpty ?? false)
          ? result['nickname'].toString().trim()
          : 'Welcome';

      if (mounted) {
        if (hasSavedPin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          setState(() {
            _isPinStep = true;
            _successMessage =
                'Hi $name! Set a 4-digit PIN to protect your section.';
          });
        }
      }
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final token = await ApiService.instance.sendOTP(email);
      if (token != null) {
        setState(() {
          _verificationToken = token;
          _isOtpStep = true;
          _successMessage = 'Verification code sent to $email.';
        });
      }
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOTP() async {
    final otp = _otpController.text.trim();
    final email = _emailController.text.trim();
    if (otp.isEmpty || otp.length < 6 || _verificationToken == null) {
      setState(
        () => _errorMessage = 'Please enter the 6-digit verification code.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await ApiService.instance.verifyOTP(
        email,
        otp,
        _verificationToken!,
      );
      if (success) {
        // Run initial synchronization cycle in background
        SyncService.instance.syncData();

        final hasSavedPin = await ApiService.instance.hasPin();

        if (mounted) {
          if (hasSavedPin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          } else {
            setState(() {
              _isOtpStep = false;
              _isPinStep = true;
              _successMessage =
                  'Email verified! Set up a 4-digit PIN for instant app access.';
            });
          }
        }
      }
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSavePin() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _errorMessage = 'Please enter a valid 4-digit PIN.');
      return;
    }

    if (pin != confirmPin) {
      setState(() => _errorMessage = 'PINs do not match. Please re-enter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await ApiService.instance.savePin(pin);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to save PIN: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPaper = AppTheme.isPaper(context);

    return Scaffold(
      backgroundColor: isPaper
          ? (isDark ? AppTheme.paperDarkBackground : AppTheme.paperSurface)
          : null,
      appBar: AppBar(
        actions: kDebugMode
            ? [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showSettingsDialog,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Sanctuary / Diary Brand Emblem
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: isPaper
                        ? (isDark
                            ? AppTheme.paperDarkCard
                            : AppTheme.paperCard)
                        : (isDark
                            ? AppTheme.darkSurfaceContainerLowest
                            : AppTheme.surfaceContainerLowest),
                    shape: isPaper ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isPaper ? BorderRadius.circular(20) : null,
                    boxShadow: isPaper
                        ? AppTheme.paperCardShadow
                        : AppTheme.editorialShadow,
                    border: Border.all(
                      color: isPaper
                          ? AppTheme.paperLeatherMid
                          : AppTheme.primary.withOpacity(0.12),
                      width: isPaper ? 2 : 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: isPaper
                            ? LinearGradient(
                                colors: [
                                  AppTheme.paperTabBlue.withOpacity(0.4),
                                  AppTheme.paperTabPeach.withOpacity(0.3),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  AppTheme.primary.withOpacity(0.15),
                                  AppTheme.primaryContainer.withOpacity(0.25),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        shape: isPaper ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: isPaper ? BorderRadius.circular(14) : null,
                      ),
                      child: Center(
                        child: Icon(
                          isPaper
                              ? Icons.menu_book_rounded
                              : Icons.account_balance_wallet_rounded,
                          size: 36,
                          color: isPaper ? AppTheme.paperInkNavy : AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Editorial / Diary Headings
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPaper
                        ? AppTheme.paperTabBlue.withOpacity(0.6)
                        : AppTheme.secondaryContainer.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(isPaper ? 8 : 20),
                    border: isPaper
                        ? Border.all(color: const Color(0xFFBCD7EF))
                        : null,
                  ),
                  child: Text(
                    isPaper ? 'EXECUTIVE CASHBOOK & DIARY' : 'HERITAGE SANCTUARY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isPaper
                          ? const Color(0xFF15365A)
                          : AppTheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPaper ? 'The Paper Ledger' : 'Manikutti',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isPinStep
                    ? (isPaper
                        ? 'Lock your personal diary with a 4-digit PIN'
                        : 'Secure your financial sanctuary with a 4-digit PIN')
                    : _isOtpStep
                    ? 'Enter the 6-digit verification code sent to your email'
                    : (isPaper
                        ? 'Every rupee written in pen on your daily ledger.'
                        : 'Personal & family wealth ledger, thoughtfully unified.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 32),

              // Form Container Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isPaper
                      ? (isDark ? AppTheme.paperDarkCard : AppTheme.paperCard)
                      : (isDark
                          ? AppTheme.darkSurfaceContainerLowest
                          : AppTheme.surfaceContainerLowest),
                  borderRadius: BorderRadius.circular(isPaper ? 14 : 24),
                  boxShadow: isPaper
                      ? AppTheme.paperCardShadow
                      : AppTheme.ambientCardShadow,
                  border: Border.all(
                    color: isPaper
                        ? const Color(0xFFE2DDD5)
                        : (isDark
                            ? const Color(0xFF2C3233)
                            : AppTheme.outlineVariant.withOpacity(0.2)),
                    width: isPaper ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error Alert
                    if (_errorMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.error.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Success Alert
                    if (_successMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF00897B).withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Color(0xFF00897B),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _successMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF00897B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Input Form
                    if (_isPinStep) ...[
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 14,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Create 4-Digit Security PIN',
                          hintText: '••••',
                          counterText: '',
                          prefixIcon: Icon(Icons.lock_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 14,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Confirm 4-Digit PIN',
                          hintText: '••••',
                          counterText: '',
                          prefixIcon: Icon(Icons.check_circle_outline_rounded),
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
                          onPressed: _isLoading ? null : _handleSavePin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Save PIN & Access Sanctuary'),
                        ),
                      ),
                    ] else if (!_isOtpStep) ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Family Code'),
                            icon: Icon(Icons.vpn_key_outlined, size: 16),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Email OTP'),
                            icon: Icon(Icons.alternate_email_rounded, size: 16),
                          ),
                        ],
                        selected: {_useFamilyCodeMode},
                        onSelectionChanged: (s) {
                          setState(() {
                            _useFamilyCodeMode = s.first;
                            _errorMessage = '';
                            _successMessage = '';
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_useFamilyCodeMode) ...[
                        TextField(
                          controller: _accessCodeController,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Family Access Code',
                            hintText: 'e.g. M7K9P2',
                            prefixIcon: Icon(Icons.qr_code_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Enter the code shared by your family Admin (or tap your WhatsApp invite link). No email verification needed.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 20),
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
                            onPressed: _isLoading
                                ? null
                                : _handleFamilyCodeLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('Join Family Dashboard'),
                          ),
                        ),
                      ] else ...[
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'name@family.com',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                            onPressed: _isLoading ? null : _handleSendOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('Continue with Email'),
                          ),
                        ),
                      ],
                      if (_hasSavedPin) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.fingerprint_rounded,
                            color: AppTheme.primary,
                          ),
                          label: Text(
                            'Quick Unlock with PIN',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: AppTheme.primary.withOpacity(0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AppLockScreen(
                                  onUnlock: () {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DashboardScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 12,
                        ),
                        decoration: const InputDecoration(
                          hintText: '••••••',
                          counterText: '',
                          prefixIcon: Icon(Icons.lock_clock_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                          onPressed: _isLoading ? null : _handleVerifyOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Verify & Enter'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isOtpStep = false;
                            _isPinStep = false;
                            _otpController.clear();
                            _errorMessage = '';
                            _successMessage = '';
                          });
                        },
                        child: Text(
                          'Use a different email address',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Editorial Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppTheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'End-to-End Encrypted & Offline First',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
