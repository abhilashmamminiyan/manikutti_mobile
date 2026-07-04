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
    try {
      remotePersonal = await apiService.fetchTransactions('Personal_Expenses');
    } catch (e) {
      print('[SyncService] Failed to pull personal expenses: $e');
    }

    // Fetch family transactions (if joined)
    List<dynamic> remoteFamily = [];
    try {
      final familyInfo = await apiService.getFamilyInfo();
      if (familyInfo != null && familyInfo['familyCode'] != null) {
        remoteFamily = await apiService.fetchTransactions('Family_Expenses');
      }
    } catch (e) {
      print('[SyncService] Failed to pull family expenses: $e');
    }

    // Fetch local transactions to perform comparison
    final localList = await dbHelper.getAllTransactions();

    // Helper to check if a remote transaction is already in local list
    bool isAlreadyLocal(Map<String, dynamic> remote, String type) {
      final remoteDateStr = remote['date']?.toString() ?? '';
      final remoteAmount = (remote['amount'] as num).toDouble();
      final remoteCategory = remote['category'] ?? '';
      final remoteNote = remote['note'] ?? '';

      final remoteParsed = DateTime.tryParse(remoteDateStr)?.toUtc();

      return localList.any((local) {
        if (local.amount != remoteAmount ||
            local.category != remoteCategory ||
            local.note != remoteNote ||
            local.type != type) {
          return false;
        }

        // Compare timestamps in UTC to normalize timezone differences
        final localParsed = DateTime.tryParse(local.date)?.toUtc();
        if (localParsed != null && remoteParsed != null) {
          // Allow up to 5 seconds difference to account for minor round-trips
          final diff = localParsed.difference(remoteParsed).inSeconds.abs();
          return diff <= 5;
        }

        // Fallback string compare
        return local.date == remoteDateStr;
      });
    }

    // Process personal remote items
    for (final item in remotePersonal) {
      final type = item['type'] == 'Income' ? 'Income' : 'Expense';
      if (!isAlreadyLocal(item, type)) {
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
    }

    // Process family remote items
    for (final item in remoteFamily) {
      if (!isAlreadyLocal(item, 'Family')) {
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
  }
}
