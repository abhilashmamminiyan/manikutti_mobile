import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/transaction_model.dart';
import '../services/voice_expense_service.dart';
import '../theme/app_theme.dart';
import '../screens/add_transaction_screen.dart';
import 'spiral_voice_waves.dart';

class VoiceLoggingSheet extends StatefulWidget {
  final String? initialQuery;
  final VoidCallback? onExpenseAdded;

  const VoiceLoggingSheet({super.key, this.initialQuery, this.onExpenseAdded});

  static Future<void> show(
    BuildContext context, {
    String? initialQuery,
    VoidCallback? onExpenseAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceLoggingSheet(
        initialQuery: initialQuery,
        onExpenseAdded: onExpenseAdded,
      ),
    );
  }

  @override
  State<VoiceLoggingSheet> createState() => _VoiceLoggingSheetState();
}

class _VoiceLoggingSheetState extends State<VoiceLoggingSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isInit = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _words = '';
  String _selectedLocale =
      'ml_IN'; // Default to Malayalam, with quick toggle to en_IN
  String? _errorMessage;
  TransactionModel? _savedTransaction;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      // Process pre-supplied voice text directly (e.g. from Google Assistant)
      setState(() {
        _words = widget.initialQuery!.trim();
      });
      await _processTranscript(_words);
      return;
    }

    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _errorMessage = err.errorMsg;
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (_words.trim().isNotEmpty &&
                  _savedTransaction == null &&
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
          _startListening();
        } else {
          _errorMessage =
              'Microphone permission not granted or speech recognition unavailable.';
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing speech: $e';
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (!_isInit) return;
    setState(() {
      _isListening = true;
      _errorMessage = null;
      _savedTransaction = null;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _words = result.recognizedWords;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
        localeId: _selectedLocale,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _errorMessage = 'Listening failed: $e';
        });
      }
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_words.trim().isNotEmpty && _savedTransaction == null) {
      await _processTranscript(_words);
    }
  }

  Future<void> _processTranscript(String transcript) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final tx = await VoiceExpenseService.instance.processAndSaveVoiceExpense(
        transcript,
      );
      if (mounted) {
        setState(() {
          _savedTransaction = tx;
          _isProcessing = false;
        });
        widget.onExpenseAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to parse expense: $e';
          _isProcessing = false;
        });
      }
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header with language toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Manikutti Voice AI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Language toggle chip
              InkWell(
                onTap: _toggleLocale,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _selectedLocale == 'ml_IN' ? 'മലയാളം' : 'English',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Animation or Success Display
          if (_savedTransaction != null) ...[
            _buildSuccessCard(theme, isDark),
          ] else ...[
            _buildRecordingUI(theme, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingUI(ThemeData theme, bool isDark) {
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
        const SizedBox(height: 12),

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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _isListening
                ? Colors.redAccent
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
        const SizedBox(height: 14),

        // Live recognized words container
        Container(
          width: double.infinity,
          constraints: const Duration(milliseconds: 200) == Duration.zero
              ? null
              : const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Text(
            _words.isEmpty
                ? (_selectedLocale == 'ml_IN'
                      ? 'ഉദാ: "100 roopakku petrol adichu" അല്ലെങ്കിൽ "ചായ 40 രൂപ"'
                      : 'e.g. "100 rupees for petrol" or "Dinner 1200"')
                : _words,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontStyle: _words.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: _words.isEmpty
                  ? (isDark ? Colors.white38 : Colors.black38)
                  : (isDark ? Colors.white : Colors.black87),
              fontWeight: _words.isEmpty ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],

        const SizedBox(height: 16),

        // Stop / Process button if user spoke something
        if (_words.isNotEmpty && !_isProcessing)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _processTranscript(_words),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Log Expense Now',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSuccessCard(ThemeData theme, bool isDark) {
    final tx = _savedTransaction!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense Recorded Successfully!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : Colors.green.shade900,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Saved offline & widget updated',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : Colors.green.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.note,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.black12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tx.category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tx.bankAccount ?? 'SBI',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '₹${tx.amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const AddTransactionScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Edit in Form'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
