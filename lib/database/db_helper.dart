import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';

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
      version: 1,
      onCreate: _createDB,
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
        synced INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
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
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
