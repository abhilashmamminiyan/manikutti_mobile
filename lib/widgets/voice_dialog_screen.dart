import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/voice_expense_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'spiral_voice_waves.dart';

class VoiceDialogScreen extends StatefulWidget {
  final String? initialQuery;

  const VoiceDialogScreen({super.key, this.initialQuery});

  @override
  State<VoiceDialogScreen> createState() => _VoiceDialogScreenState();
}

class _VoiceDialogScreenState extends State<VoiceDialogScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isInit = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _words = '';
  String _selectedLocale =
      'ml_IN'; // Default to Malayalam, with toggle to en_IN
  String? _errorMessage;
  VoiceActionResult? _actionResult;

  static const MethodChannel _channel =
      MethodChannel('com.abhilash.manikutti/voice_dialog');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
    _initSpeechOrProcessQuery();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onNewQuery') {
      final query = call.arguments as String?;
      if (!mounted) return;
      if (query != null && query.trim().isNotEmpty) {
        if (_isListening) {
          await _speech.stop();
        }
        setState(() {
          _words = query.trim();
          _isProcessing = true;
          _actionResult = null;
          _errorMessage = null;
        });
        await _processTranscript(_words);
      } else {
        if (!_isListening && !_isProcessing) {
          _startListening();
        }
      }
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _speech.stop();
    super.dispose();
  }


  Future<void> _initSpeechOrProcessQuery() async {
    // Warm up NotificationService and notification channel
    unawaited(NotificationService.instance.initialize());

    // 1. If triggered by Google Assistant with a captured query, process headlessly and close
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      setState(() {
        _words = widget.initialQuery!.trim();
        _isProcessing = true;
      });
      await _processTranscript(_words);
      return;
    }

    // 2. Otherwise initialize mic to listen over home screen
    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (!mounted) return;
          // If words were already spoken before Android's silence timeout, process them!
          if (_words.trim().isNotEmpty &&
              _actionResult == null &&
              !_isProcessing) {
            _processTranscript(_words);
            return;
          }
          setState(() {
            _isListening = false;
            // Never show red error banner on simple initial silence timeout
            if (err.errorMsg.contains('timeout') ||
                err.errorMsg.contains('no_match')) {
              _errorMessage = null;
            } else {
              _errorMessage = err.errorMsg;
            }
          });
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (_words.trim().isNotEmpty &&
                  _actionResult == null &&
                  !_isProcessing) {
                _processTranscript(_words);
              }
            }
          }
        },
      );

      if (mounted) {
        setState(() {
          _isInit = available;
        });
        if (available) {
          // Give a smooth 350ms buffer for activity window entrance animation
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && !_isListening && !_isProcessing) {
              _startListening();
            }
          });
        } else {
          _errorMessage = 'Microphone permission not granted.';
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Speech init error: $e';
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (!_isInit) return;
    setState(() {
      _isListening = true;
      _errorMessage = null;
      _actionResult = null;
      _words = '';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _words = result.recognizedWords;
            });
            if (result.finalResult &&
                result.recognizedWords.trim().isNotEmpty &&
                _actionResult == null &&
                !_isProcessing) {
              _processTranscript(result.recognizedWords);
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: _selectedLocale,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _errorMessage = 'Mic error: $e';
        });
      }
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_words.trim().isNotEmpty && _actionResult == null) {
      await _processTranscript(_words);
    }
  }

  Future<void> _processTranscript(String transcript) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await VoiceExpenseService.instance
          .processAndSaveVoiceExpense(transcript);
      if (mounted) {
        if (!result.success) {
          setState(() {
            _errorMessage = result.message;
            _isProcessing = false;
          });
          return;
        }

        setState(() {
          _actionResult = result;
          _isProcessing = false;
        });

        // Auto close after 1.5 seconds to return to home screen
        Timer(const Duration(milliseconds: 1500), () {
          _closeDialog();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed: $e';
          _isProcessing = false;
        });
      }
    }
  }

  void _closeDialog() {
    SystemNavigator.pop();
  }

  void _toggleLocale() {
    setState(() {
      _selectedLocale = _selectedLocale == 'ml_IN' ? 'en_IN' : 'ml_IN';
    });
    if (_isListening) {
      _speech.stop();
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss on tapping backdrop
          GestureDetector(
            onTap: _closeDialog,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Floating Dialog Center/Bottom
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.96),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.16),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFF60A5FA),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Manikutti Voice',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      // Language chip
                      InkWell(
                        onTap: _toggleLocale,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            _selectedLocale == 'ml_IN' ? 'മലയാളം' : 'English',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Content
                  if (_actionResult != null && _actionResult!.success)
                    _buildSuccessView()
                  else
                    _buildListeningView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningView() {
    return Column(
      children: [
        // Branded Manikutti Spiral Voice Waves with Emblem in center
        SpiralVoiceWaves(
          isListening: _isListening,
          isProcessing: _isProcessing,
          onTap: () {
            if (_isListening) {
              _stopListening();
            } else if (!_isProcessing) {
              _startListening();
            }
          },
        ),
        const SizedBox(height: 10),

        // Status text
        Text(
          _isProcessing
              ? 'Analyzing with Gemini AI...'
              : (_isListening
                    ? (_selectedLocale == 'ml_IN'
                          ? 'കേൾക്കുന്നു... സംസാരിക്കൂ'
                          : 'Listening... Speak now')
                    : 'Tap mic to speak'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _isListening ? Colors.redAccent : Colors.white70,
          ),
        ),
        const SizedBox(height: 12),

        // Spoken transcript box
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            _words.isEmpty
                ? (_selectedLocale == 'ml_IN'
                      ? 'ഉദാ: "100 roopakku petrol adichu"'
                      : 'e.g. "100 rupees for petrol"')
                : _words,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontStyle: _words.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: _words.isEmpty ? Colors.white38 : Colors.white,
              fontWeight: _words.isEmpty ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessView() {
    final result = _actionResult;
    if (result == null) return const SizedBox.shrink();

    if (result.isDelete) {
      return Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.shade700,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${result.deletedCount} Deleted',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.message,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Removed from local DB & cloud • Closing...',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      );
    }

    final tx = result.transaction;
    if (tx == null) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade600,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          '₹${tx.amount.toStringAsFixed(0)} Saved',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${tx.note} • ${tx.category}',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Saved to offline SQLite • Closing...',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
