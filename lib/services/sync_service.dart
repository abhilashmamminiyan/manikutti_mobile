import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';
import 'api_service.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  bool _isSyncing = false;

  SyncService._init();

  bool get isSyncing => _isSyncing;

  Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none) && connectivityResult.isNotEmpty;
  }

  // Run the full sync cycle (push local unsynced -> pull remote)
  Future<void> syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      if (!await isConnected()) {
        print('[SyncService] No internet connection. Skipping sync.');
        return;
      }

      print('[SyncService] Starting sync cycle...');
      await pushLocalChanges();
      await pullRemoteChanges();
      print('[SyncService] Sync cycle complete!');
    } catch (e) {
      print('[SyncService] Sync failed with error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Push unsynced SQLite records to Google Sheets
  Future<void> pushLocalChanges() async {
    final dbHelper = DbHelper.instance;
    final apiService = ApiService.instance;
    
    final unsyncedList = await dbHelper.getUnsyncedTransactions();
    if (unsyncedList.isEmpty) return;

    print('[SyncService] Pushing ${unsyncedList.length} unsynced transactions...');
    
    // Retrieve family code once if we have family transactions
    String? familyCode;
    if (unsyncedList.any((t) => t.type == 'Family')) {
      familyCode = await apiService.getCachedFamilyCode();
      if (familyCode == null) {
        final info = await apiService.getFamilyInfo();
        familyCode = info?['familyCode'];
      }
    }

    for (final transaction in unsyncedList) {
      try {
        final isFamily = transaction.type == 'Family';
        final sheetName = isFamily ? 'Family_Expenses' : 'Personal_Expenses';
        
        final expensePayload = {
          'date': transaction.date,
          'amount': transaction.amount,
          'category': transaction.category,
          'note': transaction.note,
          'isPaid': transaction.isPaid,
          'type': isFamily ? 'Expense' : transaction.type, // 'Expense' or 'Income'
        };

        final success = await apiService.createTransaction(
          sheetName: sheetName,
          expense: expensePayload,
          familyCode: isFamily ? familyCode : null,
        );

        if (success) {
          await dbHelper.markAsSynced(transaction.id!);
          print('[SyncService] Transaction #${transaction.id} synced successfully.');
        }
      } catch (e) {
        print('[SyncService] Failed to push transaction #${transaction.id}: $e');
      }
    }
  }

  // Pull remote Google Sheets records and merge with SQLite
  Future<void> pullRemoteChanges() async {
    final dbHelper = DbHelper.instance;
    final apiService = ApiService.instance;
    final email = await apiService.getUserEmail();
    
    if (email == null) return;

    print('[SyncService] Pulling remote transactions...');

    // Fetch personal transactions
    List<dynamic> remotePersonal = [];
    bool personalSuccess = false;
    try {
      remotePersonal = await apiService.fetchTransactions('Personal_Expenses');
      personalSuccess = true;
    } catch (e) {
      print('[SyncService] Failed to pull personal expenses: $e');
    }

    // Fetch family transactions (if joined)
    List<dynamic> remoteFamily = [];
    bool familySuccess = false;
    bool hasFamily = false;
    try {
      final familyInfo = await apiService.getFamilyInfo();
      if (familyInfo != null && familyInfo['familyCode'] != null) {
        hasFamily = true;
        remoteFamily = await apiService.fetchTransactions('Family_Expenses');
        familySuccess = true;
      } else {
        // No family joined, so treat family pull as successful
        familySuccess = true;
      }
    } catch (e) {
      print('[SyncService] Failed to pull family expenses: $e');
    }

    // Flush and align with Google Sheets ONLY if the remote pull succeeded!
    // This protects local data in case of temporary network dropouts during pull.
    if (personalSuccess && familySuccess) {
      // 1. Clear all local synced transactions
      await dbHelper.deleteSyncedTransactions();

      // 2. Insert fresh personal remote items
      for (final item in remotePersonal) {
        final type = item['type'] == 'Income' ? 'Income' : 'Expense';
        await dbHelper.insertTransaction(TransactionModel(
          date: item['date'],
          amount: (item['amount'] as num).toDouble(),
          category: item['category'] ?? 'General',
          note: item['note'] ?? '',
          isPaid: item['isPaid'] == true,
          type: type,
          synced: true,
        ));
      }

      // 3. Insert fresh family remote items
      if (hasFamily) {
        for (final item in remoteFamily) {
          await dbHelper.insertTransaction(TransactionModel(
            date: item['date'],
            amount: (item['amount'] as num).toDouble(),
            category: item['category'] ?? 'General',
            note: item['note'] ?? '',
            isPaid: true,
            type: 'Family',
            addedBy: item['addedBy'],
            familyCode: item['familyCode'],
            synced: true,
          ));
        }
      }
      print('[SyncService] Local database successfully aligned with Google Sheets.');
    }
  }
}
