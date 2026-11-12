import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../services/screenshot_payee_rule_service.dart';
import '../theme/app_theme.dart';

class PayeeRulesScreen extends StatefulWidget {
  const PayeeRulesScreen({super.key});

  @override
  State<PayeeRulesScreen> createState() => _PayeeRulesScreenState();
}

class _PayeeRulesScreenState extends State<PayeeRulesScreen> {
  List<ScreenshotPayeeRule> _rules = [];
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rules = await ScreenshotPayeeRuleService.instance.getRules();
    final cats = await CategoryService.instance.getExpenseCategories();
    final merged = <String>{
      ...cats,
      'Savings',
      'Emergency Fund',
      'Home Loan',
      'Loan/EMI',
      'Family Transfer',
      'Other',
    }.toList();

    if (mounted) {
      setState(() {
        _rules = rules;
        _categories = merged;
        _loading = false;
      });
    }
  }

  Future<void> _showRuleDialog([ScreenshotPayeeRule? existing]) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final patternsCtrl = TextEditingController(
      text: existing?.matchPatterns.join(', ') ?? '',
    );
    final noteCtrl = TextEditingController(text: existing?.customNote ?? '');
    final dueCtrl = TextEditingController(text: existing?.linkedDueTitle ?? '');
    final transferToCtrl = TextEditingController(
      text: existing?.transferToMember ?? '',
    );

    String category = existing?.category ?? 'Savings';
    if (!_categories.contains(category)) {
      _categories.add(category);
    }
    ScreenshotLedgerTarget target =
        existing?.target ?? ScreenshotLedgerTarget.personal;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? 'Add Frequent Payee Rule'
                          : 'Edit Payee Rule',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Match any phone number, UPI ID, or name found in a payment screenshot so it always picks the right category & ledger.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: labelCtrl,
                      decoration: InputDecoration(
                        labelText: 'Payee Label (e.g. Athulya or Mom Nisha)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: patternsCtrl,
                      decoration: InputDecoration(
                        labelText:
                            'Phone Number / UPI ID / Name (comma-separated)',
                        hintText: 'e.g. 9876543210, athulya@okaxis, Athulya',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: 'Fixed Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => category = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ScreenshotLedgerTarget>(
                      initialValue: target,
                      decoration: InputDecoration(
                        labelText: 'Save Destination',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: ScreenshotLedgerTarget.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => target = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dueCtrl,
                      decoration: InputDecoration(
                        labelText: 'Auto-mark Monthly Due as Paid (optional)',
                        hintText: 'e.g. Home loan, Bajaj Personal Loan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: transferToCtrl,
                      decoration: InputDecoration(
                        labelText: 'Record Family Transfer To (optional)',
                        hintText:
                            'e.g. Nisha (records inter-member pool transfer)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        labelText: 'Default Note (optional)',
                        hintText: 'e.g. Monthly Emergency Fund to Athulya',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () async {
                        final label = labelCtrl.text.trim();
                        final patterns = patternsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (label.isEmpty || patterns.isEmpty) {
                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter both a label and at least one phone number, UPI ID, or name.',
                              ),
                            ),
                          );
                          return;
                        }

                        final rule = ScreenshotPayeeRule(
                          id:
                              existing?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          label: label,
                          matchPatterns: patterns,
                          category: category,
                          target: target,
                          linkedDueTitle: dueCtrl.text.trim().isEmpty
                              ? null
                              : dueCtrl.text.trim(),
                          transferToMember: transferToCtrl.text.trim().isEmpty
                              ? null
                              : transferToCtrl.text.trim(),
                          customNote: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        );

                        await ScreenshotPayeeRuleService.instance.saveRule(
                          rule,
                        );
                        await CategoryService.instance.addCategory(category);
                        if (modalCtx.mounted) Navigator.pop(modalCtx);
                        await _loadData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Payee Rule',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payee & Screenshot Rules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRuleDialog(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rule_folder_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Payee Rules Configured Yet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Save frequent phone numbers, UPI IDs, or names (e.g. Athulya → Savings, Nisha → Home Loan) so shared screenshots always pick the exact category & ledger automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _showRuleDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Rule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: _rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final rule = _rules[idx];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.person_pin_circle_outlined,
                        color: AppTheme.primary,
                      ),
                    ),
                    title: Text(
                      rule.label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Matches: ${rule.matchPatterns.join(', ')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(
                                rule.category,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text(
                                rule.target.displayName,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (rule.linkedDueTitle != null)
                              Chip(
                                label: Text(
                                  'Marks Paid: ${rule.linkedDueTitle}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showRuleDialog(rule),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            await ScreenshotPayeeRuleService.instance
                                .deleteRule(rule.id);
                            await _loadData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
