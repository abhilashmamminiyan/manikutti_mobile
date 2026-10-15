import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

/// Service to manage confirmed bank balances and compute active account balances
class BankBalanceService {
  static final BankBalanceService instance = BankBalanceService._internal();
  BankBalanceService._internal();

  static const String _prefixBalance = 'bank_verified_balance_';
  static const String _prefixDate = 'bank_verified_date_';

  final Map<String, double> _cachedBalances = {};
  final Map<String, DateTime> _cachedDates = {};
  bool _initialized = false;

  /// Whether the service cache has been initialized from SharedPreferences
  bool get isInitialized => _initialized;

  /// Initialize in-memory cache from SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final bank in TransactionModel.supportedBanks) {
        final b = prefs.getDouble('$_prefixBalance$bank');
        if (b != null) _cachedBalances[bank] = b;

        final dStr = prefs.getString('$_prefixDate$bank');
        if (dStr != null && dStr.isNotEmpty) {
          final d = DateTime.tryParse(dStr)?.toLocal();
          if (d != null) _cachedDates[bank] = d;
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[BankBalanceService] Error in init: $e');
    }
  }

  /// Get cached balance synchronously (available after init or set)
  double? getCachedBalance(String bank) => _cachedBalances[bank];

  /// Get cached date synchronously (available after init or set)
  DateTime? getCachedDate(String bank) => _cachedDates[bank];

  /// Save a verified balance (e.g. from an uploaded statement's closing balance or manual user adjustment)
  Future<void> setVerifiedBalance(
    String bank,
    double balance,
    DateTime asOfDate,
  ) async {
    _cachedBalances[bank] = balance;
    _cachedDates[bank] = asOfDate;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_prefixBalance$bank', balance);
      await prefs.setString(
        '$_prefixDate$bank',
        asOfDate.toUtc().toIso8601String(),
      );
      debugPrint(
        '[BankBalanceService] Set verified balance for $bank: ₹$balance as of $asOfDate',
      );
    } catch (e) {
      debugPrint('[BankBalanceService] Error saving verified balance: $e');
    }
  }

  /// Get the verified baseline balance for a given bank (if any)
  Future<double?> getVerifiedBalance(String bank) async {
    if (_cachedBalances.containsKey(bank)) return _cachedBalances[bank];
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getDouble('$_prefixBalance$bank');
      if (val != null) _cachedBalances[bank] = val;
      return val;
    } catch (e) {
      return null;
    }
  }

  /// Get the date of the verified baseline balance
  Future<DateTime?> getVerifiedDate(String bank) async {
    if (_cachedDates.containsKey(bank)) return _cachedDates[bank];
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_prefixDate$bank');
      if (str != null && str.isNotEmpty) {
        final dt = DateTime.tryParse(str)?.toLocal();
        if (dt != null) {
          _cachedDates[bank] = dt;
          return dt;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Clear verified balance for testing or reset
  Future<void> clearVerifiedBalance(String bank) async {
    _cachedBalances.remove(bank);
    _cachedDates.remove(bank);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefixBalance$bank');
      await prefs.remove('$_prefixDate$bank');
    } catch (_) {}
  }

  /// Compute the live, accurate balance of a bank account:
  /// - If a verified baseline balance exists as of [verifiedDate]:
  ///     Current Balance = verifiedBalance + sum(Credits after verifiedDate) - sum(Debits after verifiedDate)
  /// - If no verified baseline exists:
  ///     Current Balance = sum(All historical Credits for this bank) - sum(All historical Debits for this bank)
  double calculateBankBalance({
    required String bank,
    required List<TransactionModel> transactions,
    double? verifiedBalance,
    DateTime? verifiedDate,
  }) {
    // If not passed explicitly, use cached values
    final effectiveBal = verifiedBalance ?? _cachedBalances[bank];
    final effectiveDate = verifiedDate ?? _cachedDates[bank];

    if (effectiveBal != null && effectiveDate != null) {
      double running = effectiveBal;

      for (final t in transactions) {
        final tBank = (t.bankAccount != null && t.bankAccount!.isNotEmpty)
            ? t.bankAccount!
            : TransactionModel.bankSbi;
        if (tBank != bank) continue;

        final tDate = DateTime.tryParse(t.date)?.toLocal();
        if (tDate == null) continue;

        // Only count transactions logged AFTER the verified statement/anchor date
        if (tDate.isAfter(effectiveDate)) {
          if (t.type == TransactionModel.typeIncome) {
            running += t.amount;
          } else if (t.type == TransactionModel.typeExpense ||
              t.type == TransactionModel.typeFamily) {
            running -= t.amount;
          } else if (t.isTransfer) {
            if (t.category.toLowerCase().contains('income') ||
                t.note.toLowerCase().contains('received') ||
                t.note.toLowerCase().contains('from')) {
              running += t.amount;
            } else {
              running -= t.amount;
            }
          }
        }
      }
      return running;
    }

    // Fallback: all-time net
    double running = 0.0;
    for (final t in transactions) {
      final tBank = (t.bankAccount != null && t.bankAccount!.isNotEmpty)
          ? t.bankAccount!
          : TransactionModel.bankSbi;
      if (tBank != bank) continue;

      if (t.type == TransactionModel.typeIncome) {
        running += t.amount;
      } else if (t.type == TransactionModel.typeExpense ||
          t.type == TransactionModel.typeFamily) {
        running -= t.amount;
      } else if (t.isTransfer) {
        if (t.category.toLowerCase().contains('income') ||
            t.note.toLowerCase().contains('received') ||
            t.note.toLowerCase().contains('from')) {
          running += t.amount;
        } else {
          running -= t.amount;
        }
      }
    }
    return running;
  }
}
