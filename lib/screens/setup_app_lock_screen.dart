import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_lock_enabled', false);
      await prefs.remove('app_lock_pin');
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
      // Prompt user to enter a new PIN before enabling
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
    return Scaffold(
      appBar: AppBar(title: const Text('App Lock Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text(
                'Enable App Lock',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Require a 4-digit PIN or Biometric unlock when opening the app.',
              ),
              value: _isLockEnabled,
              onChanged: _toggleLock,
            ),
            const SizedBox(height: 24),
            if (_isLockEnabled && !_hasSavedPin) ...[
              const Text('Enter a 4-digit PIN', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '****',
                  errorText: _errorMessage.isEmpty ? null : _errorMessage,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePin,
                  child: const Text('Save PIN & Enable Lock'),
                ),
              ),
            ] else if (_isLockEnabled && _hasSavedPin) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'App Lock is active. Your PIN is saved securely.',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
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
