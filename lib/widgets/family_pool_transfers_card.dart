import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class FamilyPoolTransfersCard extends StatelessWidget {
  final List<dynamic> familyMembers;
  final List<dynamic> monthlyExpenses;
  final List<dynamic> transfers;
  final double targetMonthlyShare;
  final VoidCallback onRecordTransfer;
  final Function(int id)? onDeleteTransfer;

  const FamilyPoolTransfersCard({
    super.key,
    required this.familyMembers,
    required this.monthlyExpenses,
    required this.transfers,
    this.targetMonthlyShare = 12500.0,
    required this.onRecordTransfer,
    this.onDeleteTransfer,
  });

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  bool _isThisMonth(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return false;
    final now = DateTime.now();
    return parsed.toLocal().month == now.month &&
        parsed.toLocal().year == now.year;
  }

  String _memberDisplayName(dynamic m) {
    final nick = (m['nickname'] ?? '').toString().trim();
    if (nick.isNotEmpty) return nick;
    final email = (m['email'] ?? '').toString().trim();
    return email.isNotEmpty ? email.split('@').first : 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter transfers to current calendar month
    final monthlyTransfers = transfers
        .where((t) => _isThisMonth(t['date']?.toString()))
        .toList();

    // Compute each member's contribution this month:
    // = (Direct Monthly Dues marked Paid by them) + (Pool Transfers sent by them)
    final Map<String, double> paidDirectByMember = {};
    final Map<String, double> sentTransfersByMember = {};
    final Map<String, double> receivedTransfersByMember = {};

    for (final m in familyMembers) {
      final name = _memberDisplayName(m);
      paidDirectByMember[name.toLowerCase()] = 0.0;
      sentTransfersByMember[name.toLowerCase()] = 0.0;
      receivedTransfersByMember[name.toLowerCase()] = 0.0;
    }

    for (final due in monthlyExpenses) {
      if (!_isThisMonth(due['lastPaidDate']?.toString())) continue;
      final paidBy = (due['lastPaidBy'] ?? '').toString().trim().toLowerCase();
      if (paidBy.isEmpty) continue;
      final amt = (due['amount'] as num?)?.toDouble() ?? 0.0;
      final key = paidBy.contains('@') ? paidBy.split('@').first : paidBy;
      paidDirectByMember[key] = (paidDirectByMember[key] ?? 0.0) + amt;
    }

    for (final tr in monthlyTransfers) {
      final from = (tr['fromMember'] ?? '').toString().trim().toLowerCase();
      final to = (tr['toMember'] ?? '').toString().trim().toLowerCase();
      final amt = (tr['amount'] as num?)?.toDouble() ?? 0.0;
      if (from.isNotEmpty) {
        sentTransfersByMember[from] = (sentTransfersByMember[from] ?? 0.0) + amt;
      }
      if (to.isNotEmpty) {
        receivedTransfersByMember[to] =
            (receivedTransfersByMember[to] ?? 0.0) + amt;
      }
    }

    final memberNames = <String>{
      for (final m in familyMembers) _memberDisplayName(m),
      for (final tr in monthlyTransfers) ...[
        if ((tr['fromMember'] ?? '').toString().trim().isNotEmpty)
          (tr['fromMember'] ?? '').toString().trim(),
        if ((tr['toMember'] ?? '').toString().trim().isNotEmpty)
          (tr['toMember'] ?? '').toString().trim(),
      ],
    }.toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurfaceContainerLowest
            : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.ambientCardShadow,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C3233)
              : AppTheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Pool & Inter-Payments',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monthly share tracker (${_currency.format(targetMonthlyShare)}/member) & transfers',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppTheme.darkOnSurfaceVariant
                            : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onRecordTransfer,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text(
                  'Transfer',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          if (memberNames.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: memberNames.map((name) {
                final k = name.toLowerCase();
                final direct = paidDirectByMember[k] ?? 0.0;
                final sent = sentTransfersByMember[k] ?? 0.0;
                final received = receivedTransfersByMember[k] ?? 0.0;
                // Net out-of-pocket contribution = direct payments - pool money received + transfers sent
                final netContribution = (direct - received + sent).clamp(
                  0.0,
                  double.infinity,
                );
                final progress = targetMonthlyShare > 0
                    ? (netContribution / targetMonthlyShare).clamp(0.0, 1.0)
                    : 0.0;
                final met = netContribution >= targetMonthlyShare - 500;

                return Container(
                  width: 155,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceContainer
                        : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: met
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : AppTheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            met
                                ? Icons.check_circle_rounded
                                : Icons.timelapse_rounded,
                            size: 14,
                            color: met
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE65100),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_currency.format(netContribution)} / ${_currency.format(targetMonthlyShare)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: met
                              ? const Color(0xFF10B981)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            met ? const Color(0xFF10B981) : AppTheme.primary,
                          ),
                        ),
                      ),
                      if (sent > 0 || received > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          [
                            if (sent > 0) 'Sent ${_currency.format(sent)}',
                            if (received > 0)
                              'Pool +${_currency.format(received)}',
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (monthlyTransfers.isEmpty)
            Text(
              'No inter-member transfers logged this month (e.g. Ajesh → Nisha ₹3,750, Abhilash → Nisha ₹12,500).',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            )
          else
            Column(
              children: monthlyTransfers.take(6).map((tr) {
                final id = tr['id'] as int?;
                final from = (tr['fromMember'] ?? '').toString();
                final to = (tr['toMember'] ?? '').toString();
                final amt = (tr['amount'] as num?)?.toDouble() ?? 0.0;
                final note = (tr['note'] ?? '').toString();
                final dateStr = (tr['date'] ?? '').toString();
                final parsedDate = DateTime.tryParse(dateStr)?.toLocal();
                final formattedDate = parsedDate != null
                    ? DateFormat('MMM d').format(parsedDate)
                    : '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$from → $to',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              [
                                if (formattedDate.isNotEmpty) formattedDate,
                                if (note.isNotEmpty) note,
                              ].join(' • '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _currency.format(amt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF006972),
                        ),
                      ),
                      if (id != null && onDeleteTransfer != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onDeleteTransfer!(id),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
