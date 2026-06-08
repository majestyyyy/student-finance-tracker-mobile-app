import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton manager for the on-device SQLite financial store.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _databaseName = 'student_finance.db';
  static const int _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        type_label TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wallet_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        is_expense INTEGER NOT NULL,
        timestamp_label TEXT NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE CASCADE
      )
    ''');

    await _seedInitialWallets(db);
  }

  Future<void> _seedInitialWallets(Database db) async {
    final countResult = await db.rawQuery('SELECT COUNT(*) AS count FROM wallets');
    final count = Sqflite.firstIntValue(countResult) ?? 0;
    if (count > 0) {
      return;
    }

    const seedWallets = [
      {
        'name': 'Daily Allowance',
        'account_type': 'cash',
        'type_label': 'Cash',
        'balance': 250.0,
      },
      {
        'name': 'Savings Vault',
        'account_type': 'savings',
        'type_label': 'Bank',
        'balance': 4500.0,
      },
      {
        'name': 'Digital Maya',
        'account_type': 'digital_bank',
        'type_label': 'E-Wallet',
        'balance': 1280.5,
      },
    ];

    final batch = db.batch();
    for (final wallet in seedWallets) {
      batch.insert('wallets', wallet);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getWallets() async {
    final db = await database;
    return db.query(
      'wallets',
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        t.id,
        t.wallet_id,
        t.title,
        t.amount,
        t.is_expense,
        t.timestamp_label,
        w.name AS wallet_name
      FROM transactions t
      INNER JOIN wallets w ON w.id = t.wallet_id
      ORDER BY t.id DESC
    ''');
  }

  Future<double> sumTransactionAmounts({required bool isExpense}) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE is_expense = ?
      ''',
      [isExpense ? 1 : 0],
    );
    return _parseDouble(result.first['total']);
  }

  Future<int> insertWallet({
    required String name,
    required String accountType,
    required String typeLabel,
    required double initialBalance,
  }) async {
    final db = await database;
    return db.insert(
      'wallets',
      {
        'name': name,
        'account_type': accountType,
        'type_label': typeLabel,
        'balance': double.parse(initialBalance.toStringAsFixed(2)),
      },
    );
  }

  Future<void> insertTransaction({
    required int walletId,
    required String title,
    required double amount,
    required bool isExpense,
    required String timestampLabel,
  }) async {
    final db = await database;
    final normalizedAmount = double.parse(amount.toStringAsFixed(2));

    await db.transaction((txn) async {
      await txn.insert(
        'transactions',
        {
          'wallet_id': walletId,
          'title': title,
          'amount': normalizedAmount,
          'is_expense': isExpense ? 1 : 0,
          'timestamp_label': timestampLabel,
        },
      );

      final walletRows = await txn.query(
        'wallets',
        columns: ['balance'],
        where: 'id = ?',
        whereArgs: [walletId],
        limit: 1,
      );

      if (walletRows.isEmpty) {
        throw StateError('Wallet $walletId not found');
      }

      final currentBalance = _parseDouble(walletRows.first['balance']);
      final updatedBalance = isExpense
          ? currentBalance - normalizedAmount
          : currentBalance + normalizedAmount;

      await txn.update(
        'wallets',
        {'balance': double.parse(updatedBalance.toStringAsFixed(2))},
        where: 'id = ?',
        whereArgs: [walletId],
      );
    });
  }

  Future<void> deleteTransaction({required int id}) async {
    final db = await database;

    await db.transaction((txn) async {
      final transactionRows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (transactionRows.isEmpty) {
        throw StateError('Transaction $id not found');
      }

      final row = transactionRows.first;
      final walletId = row['wallet_id'] as int;
      final amount = _parseDouble(row['amount']);
      final isExpense = (row['is_expense'] as int) == 1;

      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      final walletRows = await txn.query(
        'wallets',
        columns: ['balance'],
        where: 'id = ?',
        whereArgs: [walletId],
        limit: 1,
      );

      if (walletRows.isEmpty) {
        throw StateError('Wallet $walletId not found');
      }

      final currentBalance = _parseDouble(walletRows.first['balance']);
      final updatedBalance = isExpense
          ? currentBalance + amount
          : currentBalance - amount;

      await txn.update(
        'wallets',
        {'balance': double.parse(updatedBalance.toStringAsFixed(2))},
        where: 'id = ?',
        whereArgs: [walletId],
      );
    });
  }

  static double _parseDouble(Object? value) {
    if (value == null) {
      return 0.0;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    if (value is String) {
      return double.parse(value);
    }
    return double.parse(value.toString());
  }
}
