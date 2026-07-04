import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _urlController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  String? _verificationToken;
  bool _isOtpStep = false;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final url = await ApiService.instance.getBaseUrl();
    _urlController.text = url;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // Handle setting/changing the base API URL
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure Backend URL', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.bold)),
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
                const SnackBar(content: Text('API Base URL updated successfully.')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOTP() async {
    final otp = _otpController.text.trim();
    final email = _emailController.text.trim();
    if (otp.isEmpty || otp.length < 6 || _verificationToken == null) {
      setState(() => _errorMessage = 'Please enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await ApiService.instance.verifyOTP(email, otp, _verificationToken!);
      if (success) {
        // Run initial synchronization cycle in background
        SyncService.instance.syncData();
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // App Logo Card
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 48,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to Manikutti',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF191C1D),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isOtpStep 
                  ? 'Enter the 6-digit code sent to your email.'
                  : 'Track your personal & family expenses in one sacred space.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // Error Alert
              if (_errorMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w500),
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _successMessage,
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Input Form
              if (!_isOtpStep) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Enter your email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSendOTP,
                  child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Send Verification Code'),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyOTP,
                  child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Verify & Continue'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isOtpStep = false;
                      _otpController.clear();
                      _errorMessage = '';
                      _successMessage = '';
                    });
                  },
                  child: const Text('Change email address'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
