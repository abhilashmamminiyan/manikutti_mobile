import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AiAdvisorCard extends StatefulWidget {
  const AiAdvisorCard({super.key});

  @override
  State<AiAdvisorCard> createState() => _AiAdvisorCardState();
}

class _AiAdvisorCardState extends State<AiAdvisorCard> {
  bool _isLoading = false;
  String? _adviceText;
  List<dynamic>? _topCategories;
  double? _totalExpenses;
  String? _errorMessage;
  bool _isCached = false;
  int? _nextRefreshInMinutes;

  Future<void> _fetchAdvice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.instance.getAiExpenseAdvice();
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        setState(() {
          _adviceText = result['advice'] as String?;
          _topCategories = result['topCategories'] as List<dynamic>?;
          _isCached = result['cached'] == true;
          _nextRefreshInMinutes = result['nextRefreshInMinutes'] as int?;
          if (result['totalExpenses'] != null) {
            _totalExpenses = (result['totalExpenses'] as num).toDouble();
          }
          _isLoading = false;
        });
        if (_adviceText != null) {
          _showAdviceBottomSheet(context);
        }
      } else {
        setState(() {
          _errorMessage =
              result?['error'] ?? 'നിർദ്ദേശങ്ങൾ ലഭ്യമാക്കാൻ കഴിഞ്ഞില്ല.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ഇന്റർനെറ്റ് കണക്ഷൻ പരിശോധിക്കുക.';
        _isLoading = false;
      });
    }
  }

  void _showAdviceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceContainer
                    : AppTheme.surfaceContainerLowest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: AppTheme.editorialShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'മണിക്കുട്ടി AI ഉപദേശങ്ങൾ',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              'വ്യക്തിഗത സാമ്പത്തിക നിർദ്ദേശങ്ങൾ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppTheme.darkOnSurfaceVariant
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Scrollable Advice Body
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (_totalExpenses != null && _totalExpenses! > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryContainer.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.secondary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.insights_rounded,
                                  color: AppTheme.secondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'വിശകലനം ചെയ്ത ആകെ ചെലവ്: ₹${_totalExpenses!.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppTheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Top categories chips
                        if (_topCategories != null &&
                            _topCategories!.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'കൂടുതൽ ചെലവായ വിഭാഗങ്ങൾ:',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _topCategories!.map((cat) {
                              final name = cat['category']?.toString() ?? '';
                              final amt = cat['amount']?.toString() ?? '0';
                              return Chip(
                                label: Text(
                                  '$name: ₹$amt',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: isDark
                                    ? const Color(0xFF233235)
                                    : AppTheme.primary.withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: BorderSide.none,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (_isCached) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bolt,
                                  size: 16,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '15 മിനിറ്റ് കാഷെ ചെയ്ത വിവരങ്ങൾ (അടുത്ത അപ്ഡേറ്റ്: ${_nextRefreshInMinutes ?? 15} മിനിറ്റിൽ)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Formatted advice text
                        SelectableText(
                          _adviceText ?? 'നിർദ്ദേശങ്ങൾ ലഭ്യമല്ല.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            fontSize: 14.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF162527), const Color(0xFF1E3236)]
              : [const Color(0xFFE8F7F8), const Color(0xFFF3FAF9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
        ),
        boxShadow: AppTheme.ambientCardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI ഫിനാൻഷ്യൽ അഡ്വൈസർ',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      'സിനിമ, ഒ.ടി.ടി, ഫുഡ് ചിലവുകൾ കുറയ്ക്കാൻ മലയാളത്തിൽ നിർദ്ദേശങ്ങൾ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkOnSurfaceVariant
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchAdvice,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _adviceText == null
                          ? Icons.lightbulb_outline
                          : Icons.visibility_rounded,
                      size: 18,
                    ),
              label: Text(
                _isLoading
                    ? 'വിശകലനം ചെയ്യുന്നു...'
                    : _adviceText == null
                    ? 'നിർദ്ദേശങ്ങൾ നേടുക (AI Insights)'
                    : 'നിർദ്ദേശങ്ങൾ വീണ്ടും കാണുക',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
