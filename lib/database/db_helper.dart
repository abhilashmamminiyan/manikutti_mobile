import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/mobile_recharge_model.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('manikutti.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT NOT NULL,
        isPaid INTEGER NOT NULL,
        type TEXT NOT NULL,
        addedBy TEXT,
        familyCode TEXT,
        synced INTEGER NOT NULL,
        bankAccount TEXT
      )
    ''');
    await _createMobileRechargesTable(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMobileRechargesTable(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE transactions ADD COLUMN bankAccount TEXT');
    }
  }

  Future _createMobileRechargesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mobile_recharges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phoneNumber TEXT NOT NULL,
        operator TEXT NOT NULL,
        planLastRecharged REAL NOT NULL,
        planDescription TEXT,
        validityTill TEXT NOT NULL,
        lastRechargedDate TEXT,
        reminderDaysBefore INTEGER NOT NULL DEFAULT 1,
        notifyExpiry INTEGER NOT NULL DEFAULT 1,
        note TEXT,
        logExpense INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<void> batchInsertTransactions(
    List<TransactionModel> transactions,
  ) async {
    if (transactions.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final t in transactions) {
      batch.insert('transactions', t.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> markAsSynced(int id) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TransactionModel>> getLastTransactions(int count) async {
    if (count <= 0) return [];
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      orderBy: 'date DESC, id DESC',
      limit: count,
    );
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<int> deleteZeroOrNegativeTransactions() async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'amount <= 0');
  }

  Future<int> deleteLastTransactions(int count) async {
    if (count <= 0) return 0;
    final lastItems = await getLastTransactions(count);
    if (lastItems.isEmpty) return 0;

    final db = await instance.database;
    int deleted = 0;
    for (final item in lastItems) {
      if (item.id != null) {
        await db.delete('transactions', where: 'id = ?', whereArgs: [item.id]);
        deleted++;
      }
    }
    return deleted;
  }

  Future<int> deleteSyncedTransactions() async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'synced = ?', whereArgs: [1]);
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // --- Mobile Recharges CRUD ---

  Future<int> insertMobileRecharge(MobileRecharge recharge) async {
    final db = await instance.database;
    final map = recharge.toMap();
    map.remove('id'); // let SQLite autoincrement
    return await db.insert('mobile_recharges', map);
  }

  Future<List<MobileRecharge>> getAllMobileRecharges() async {
    final db = await instance.database;
    final result = await db.query(
      'mobile_recharges',
      orderBy: 'validityTill ASC',
    );
    return result.map((json) => MobileRecharge.fromMap(json)).toList();
  }

  Future<MobileRecharge?> getMobileRecharge(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'mobile_recharges',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return MobileRecharge.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateMobileRecharge(MobileRecharge recharge) async {
    final db = await instance.database;
    return await db.update(
      'mobile_recharges',
      recharge.toMap(),
      where: 'id = ?',
      whereArgs: [recharge.id],
    );
  }

  Future<int> deleteMobileRecharge(int id) async {
    final db = await instance.database;
    return await db.delete(
      'mobile_recharges',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
