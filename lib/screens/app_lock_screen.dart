import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

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
    return PopScope(
      canPop: false, // Prevent back button from bypassing lock
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 24),
                const Text(
                  'App Locked',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                if (_userEmail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _userEmail,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Enter your 4-digit Security PIN to unlock',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8.0),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _errorMessage.isEmpty ? null : _errorMessage,
                    counterText: "", // Hide character counter
                  ),
                  onChanged: (value) {
                    if (value.length == 4) {
                      _verifyPin();
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _verifyPin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Unlock', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _isAuthenticating
                          ? null
                          : _authenticateWithBiometrics,
                      icon: const Icon(Icons.fingerprint, size: 24),
                      label: const Text('Biometrics'),
                    ),
                    TextButton(
                      onPressed: _handleForgotPin,
                      child: const Text('Forgot PIN?'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
