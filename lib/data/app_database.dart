import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<void> close() async {
    final opened = _database;
    _database = null;
    if (opened != null) await opened.close();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), 'asep_beruang.db');
    _database = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE wallets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            balance INTEGER NOT NULL DEFAULT 0,
            icon TEXT NOT NULL DEFAULT 'account_balance_wallet',
            is_active INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL CHECK(type IN ('expense', 'income')),
            icon TEXT NOT NULL,
            color TEXT NOT NULL DEFAULT '#5B8C5A',
            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL CHECK(type IN ('expense', 'income', 'transfer')),
            amount INTEGER NOT NULL CHECK(amount > 0),
            date TEXT NOT NULL,
            wallet_id INTEGER NOT NULL,
            target_wallet_id INTEGER,
            category_id INTEGER,
            note TEXT,
            FOREIGN KEY(wallet_id) REFERENCES wallets(id),
            FOREIGN KEY(target_wallet_id) REFERENCES wallets(id),
            FOREIGN KEY(category_id) REFERENCES categories(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            amount_limit INTEGER NOT NULL CHECK(amount_limit > 0),
            month_year TEXT NOT NULL,
            UNIQUE(category_id, month_year),
            FOREIGN KEY(category_id) REFERENCES categories(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE daily_logs (
            date TEXT PRIMARY KEY,
            status TEXT NOT NULL CHECK(
              status IN ('transaction_recorded', 'no_expense_checked')
            )
          )
        ''');
        await db.execute('''
          CREATE TABLE budget_months (
            month_year TEXT PRIMARY KEY
          )
        ''');
        await db.execute('CREATE INDEX idx_trans_date ON transactions(date)');
        await db.execute(
          'CREATE INDEX idx_trans_wallet ON transactions(wallet_id)',
        );
        await db.execute(
          'CREATE INDEX idx_trans_category ON transactions(category_id)',
        );
        await db.execute(
          'CREATE INDEX idx_budget_cat_month ON budgets(category_id, month_year)',
        );

        await db.insert('wallets', {
          'name': 'Cash / Tunai',
          'balance': 0,
          'icon': 'account_balance_wallet',
        });
        for (final item in const [
          ('Gaji', 'income', 'payments', '#41A27A'),
          ('Hadiah', 'income', 'redeem', '#E3A331'),
          ('Lain-lain', 'income', 'more_horiz', '#8291A6'),
          ('Makanan & Minuman', 'expense', 'restaurant', '#F08B54'),
          ('Transportasi', 'expense', 'directions_car', '#5686D5'),
          ('Belanja', 'expense', 'shopping_bag', '#BD6AB0'),
          ('Tagihan', 'expense', 'receipt_long', '#E1B649'),
          ('Lain-lain', 'expense', 'more_horiz', '#8291A6'),
        ]) {
          await db.insert('categories', {
            'name': item.$1,
            'type': item.$2,
            'icon': item.$3,
            'color': item.$4,
          });
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE wallets ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('UPDATE wallets SET sort_order = id');
        }
      },
    );
    return _database!;
  }

  Future<List<Map<String, Object?>>> wallets({bool activeOnly = true}) async {
    final db = await database;
    return db.query(
      'wallets',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order, id',
    );
  }

  Future<List<Map<String, Object?>>> categories(
    String type, {
    bool activeOnly = true,
  }) async {
    final db = await database;
    return db.query(
      'categories',
      where: activeOnly ? 'type = ? AND is_active = 1' : 'type = ?',
      whereArgs: [type],
      orderBy: 'id',
    );
  }

  Future<List<Map<String, Object?>>> entries({
    String? type,
    String? month,
    int limit = 100,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (type != null) {
      where.add('t.type = ?');
      args.add(type);
    }
    if (month != null) {
      where.add("substr(t.date, 1, 7) = ?");
      args.add(month);
    }
    return db.rawQuery(
      '''
      SELECT t.*, w.name AS wallet_name, tw.name AS target_wallet_name,
             c.name AS category_name
      FROM transactions t
      LEFT JOIN wallets w ON w.id = t.wallet_id
      LEFT JOIN wallets tw ON tw.id = t.target_wallet_id
      LEFT JOIN categories c ON c.id = t.category_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY t.date DESC, t.id DESC
      LIMIT ?
    ''',
      [...args, limit],
    );
  }

  Future<Map<String, Object?>> summary(String month) async {
    final db = await database;
    final balance = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) AS total FROM wallets WHERE is_active = 1',
    );
    final flow = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
      FROM transactions WHERE substr(date, 1, 7) = ?
      ''',
      [month],
    );
    final budgetLimit = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_limit), 0) AS budget_limit
      FROM budgets WHERE month_year = ?
      ''',
      [month],
    );
    final budgetRealization = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(t.amount), 0) AS spent
      FROM transactions t
      WHERE t.type = 'expense'
        AND substr(t.date, 1, 7) = ?
        AND t.category_id IN (
          SELECT category_id FROM budgets WHERE month_year = ?
        )
      ''',
      [month, month],
    );
    final overBudget = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM (
        SELECT b.category_id, b.amount_limit, COALESCE(SUM(t.amount), 0) AS spent
        FROM budgets b
        LEFT JOIN transactions t
          ON t.category_id = b.category_id
          AND t.type = 'expense'
          AND substr(t.date, 1, 7) = b.month_year
        WHERE b.month_year = ?
        GROUP BY b.category_id, b.amount_limit
        HAVING COALESCE(SUM(t.amount), 0) > b.amount_limit
      )
      ''',
      [month],
    );
    return {
      'balance': balance.first['total'],
      'income': flow.first['income'],
      'expense': flow.first['expense'],
      'budget_limit': budgetLimit.first['budget_limit'],
      'budget_spent': budgetRealization.first['spent'],
      'over_budget_count': overBudget.first['count'],
    };
  }

  Future<List<Map<String, Object?>>> budgets(String month) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT b.category_id, c.name AS category_name, c.icon AS category_icon,
             c.color AS category_color, b.amount_limit,
             COALESCE(SUM(t.amount), 0) AS spent
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      LEFT JOIN transactions t
        ON t.category_id = b.category_id
        AND t.type = 'expense'
        AND substr(t.date, 1, 7) = b.month_year
      WHERE b.month_year = ?
      GROUP BY b.category_id, c.name, c.icon, c.color, b.amount_limit
      ORDER BY c.name
      ''',
      [month],
    );
  }

  Future<void> ensureBudgetCarryOver(String month) async {
    final db = await database;
    final previous = await _previousMonth(month);
    await db.transaction((txn) async {
      final initialized = await txn.query(
        'budget_months',
        where: 'month_year = ?',
        whereArgs: [month],
        limit: 1,
      );
      if (initialized.isNotEmpty) return;
      await txn.insert('budget_months', {'month_year': month});
      await txn.rawInsert(
        '''
        INSERT INTO budgets(category_id, amount_limit, month_year)
        SELECT old.category_id, old.amount_limit, ?
        FROM budgets old
        WHERE old.month_year = ?
        ''',
        [month, previous],
      );
    });
  }

  Future<int> saveWallet({
    int? id,
    required String name,
    required String icon,
    int initialBalance = 0,
  }) async {
    final db = await database;
    final values = {'name': name.trim(), 'icon': icon};
    if (id == null) {
      final maxOrder = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) FROM wallets'),
      )!;
      return db.insert('wallets', {
        ...values,
        'balance': initialBalance,
        'sort_order': maxOrder + 1,
      });
    }
    return db.update('wallets', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderWallets(List<int> walletIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var index = 0; index < walletIds.length; index++) {
        await txn.update(
          'wallets',
          {'sort_order': index},
          where: 'id = ? AND is_active = 1',
          whereArgs: [walletIds[index]],
        );
      }
    });
  }

  Future<int> saveCategory({
    int? id,
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    final db = await database;
    final values = {
      'name': name.trim(),
      'type': type,
      'icon': icon,
      'color': color,
    };
    if (id == null) return db.insert('categories', values);
    return db.update('categories', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteWallet(int id) async {
    final db = await database;
    final used = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM transactions WHERE wallet_id = ? OR target_wallet_id = ?',
        [id, id],
      ),
    );
    if (used! > 0) {
      await db.update(
        'wallets',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.delete('wallets', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    final used = Sqflite.firstIntValue(
      await db.rawQuery(
        '''
      SELECT (SELECT COUNT(*) FROM transactions WHERE category_id = ?) +
             (SELECT COUNT(*) FROM budgets WHERE category_id = ?)
      ''',
        [id, id],
      ),
    );
    if (used! > 0) {
      await db.update(
        'categories',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> addEntry({
    required String type,
    required int amount,
    required DateTime date,
    required int walletId,
    int? targetWalletId,
    int? categoryId,
    String? note,
    required bool allowNegative,
  }) async {
    if (amount <= 0) throw ArgumentError('Nominal harus lebih dari nol.');
    if (type != 'expense' && type != 'income' && type != 'transfer') {
      throw ArgumentError('Jenis transaksi tidak dikenal.');
    }
    if (type == 'transfer' &&
        (targetWalletId == null || walletId == targetWalletId)) {
      throw ArgumentError('Pilih dua dompet yang berbeda untuk transfer.');
    }
    if (type != 'transfer' && categoryId == null) {
      throw ArgumentError('Kategori transaksi wajib dipilih.');
    }

    final db = await database;
    await db.transaction((txn) async {
      final source = await txn.query(
        'wallets',
        columns: ['balance', 'is_active'],
        where: 'id = ?',
        whereArgs: [walletId],
        limit: 1,
      );
      if (source.isEmpty || source.first['is_active'] != 1) {
        throw StateError('Dompet sumber tidak tersedia.');
      }

      if (type == 'expense' || type == 'transfer') {
        final balance = source.first['balance'] as int;
        if (amount > balance && !allowNegative) {
          throw StateError('Saldo dompet tidak mencukupi.');
        }
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance - ? WHERE id = ?',
          [amount, walletId],
        );
      }
      if (type == 'income') {
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance + ? WHERE id = ?',
          [amount, walletId],
        );
      } else if (type == 'transfer') {
        final target = await txn.query(
          'wallets',
          columns: ['id', 'is_active'],
          where: 'id = ?',
          whereArgs: [targetWalletId],
          limit: 1,
        );
        if (target.isEmpty || target.first['is_active'] != 1) {
          throw StateError('Dompet tujuan tidak tersedia.');
        }
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance + ? WHERE id = ?',
          [amount, targetWalletId],
        );
      }

      await txn.insert('transactions', {
        'type': type,
        'amount': amount,
        'date': date.toIso8601String(),
        'wallet_id': walletId,
        'target_wallet_id': targetWalletId,
        'category_id': categoryId,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
      });
      await txn.insert('daily_logs', {
        'date': _dateKey(date),
        'status': 'transaction_recorded',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> markNoExpense(DateTime date) async {
    final db = await database;
    await db.insert('daily_logs', {
      'date': _dateKey(date),
      'status': 'no_expense_checked',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updateEntry({
    required int id,
    required String type,
    required int amount,
    required DateTime date,
    required int walletId,
    int? targetWalletId,
    int? categoryId,
    String? note,
    required bool allowNegative,
  }) async {
    _validateEntry(type, amount, walletId, targetWalletId, categoryId);
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isEmpty) throw StateError('Transaksi tidak ditemukan.');
      final old = existing.single;
      await _reverseEntry(txn, old);

      final sourceRows = await txn.query(
        'wallets',
        columns: ['balance'],
        where: 'id = ?',
        whereArgs: [walletId],
        limit: 1,
      );
      if (sourceRows.isEmpty) throw StateError('Dompet sumber tidak tersedia.');
      final sourceBalance = sourceRows.single['balance'] as int;
      if ((type == 'expense' || type == 'transfer') &&
          amount > sourceBalance &&
          !allowNegative) {
        throw StateError('Saldo dompet tidak mencukupi.');
      }
      if (type == 'transfer') {
        final targets = await txn.query(
          'wallets',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [targetWalletId],
          limit: 1,
        );
        if (targets.isEmpty) throw StateError('Dompet tujuan tidak tersedia.');
      }

      await _applyEntry(
        txn,
        type: type,
        amount: amount,
        walletId: walletId,
        targetWalletId: targetWalletId,
      );
      await txn.update(
        'transactions',
        {
          'type': type,
          'amount': amount,
          'date': date.toIso8601String(),
          'wallet_id': walletId,
          'target_wallet_id': targetWalletId,
          'category_id': categoryId,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      final oldDate = _dateKey(DateTime.parse(old['date'] as String));
      final newDate = _dateKey(date);
      await txn.insert('daily_logs', {
        'date': newDate,
        'status': 'transaction_recorded',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (oldDate != newDate) await _refreshDailyLog(txn, oldDate);
    });
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.single;
      await _reverseEntry(txn, row);
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      await _refreshDailyLog(
        txn,
        _dateKey(DateTime.parse(row['date'] as String)),
      );
    });
  }

  void _validateEntry(
    String type,
    int amount,
    int walletId,
    int? targetWalletId,
    int? categoryId,
  ) {
    if (amount <= 0) throw ArgumentError('Nominal harus lebih dari nol.');
    if (type != 'expense' && type != 'income' && type != 'transfer') {
      throw ArgumentError('Jenis transaksi tidak dikenal.');
    }
    if (type == 'transfer' &&
        (targetWalletId == null || walletId == targetWalletId)) {
      throw ArgumentError('Pilih dua dompet yang berbeda untuk transfer.');
    }
    if (type != 'transfer' && categoryId == null) {
      throw ArgumentError('Kategori transaksi wajib dipilih.');
    }
  }

  Future<void> _reverseEntry(
    Transaction txn,
    Map<String, Object?> row,
  ) async {
    final amount = row['amount'] as int;
    final walletId = row['wallet_id'] as int;
    final type = row['type'] as String;
    if (type == 'income') {
      await txn.rawUpdate('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);
    } else {
      await txn.rawUpdate('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);
      if (type == 'transfer') {
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance - ? WHERE id = ?',
          [amount, row['target_wallet_id']],
        );
      }
    }
  }

  Future<void> _applyEntry(
    Transaction txn, {
    required String type,
    required int amount,
    required int walletId,
    int? targetWalletId,
  }) async {
    if (type == 'income') {
      await txn.rawUpdate('UPDATE wallets SET balance = balance + ? WHERE id = ?', [amount, walletId]);
    } else {
      await txn.rawUpdate('UPDATE wallets SET balance = balance - ? WHERE id = ?', [amount, walletId]);
      if (type == 'transfer') {
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance + ? WHERE id = ?',
          [amount, targetWalletId],
        );
      }
    }
  }

  Future<void> _refreshDailyLog(Transaction txn, String date) async {
    final remaining = Sqflite.firstIntValue(
      await txn.rawQuery(
        "SELECT COUNT(*) FROM transactions WHERE substr(date, 1, 10) = ?",
        [date],
      ),
    )!;
    if (remaining > 0) {
      await txn.insert('daily_logs', {
        'date': date,
        'status': 'transaction_recorded',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await txn.delete(
        'daily_logs',
        where: "date = ? AND status = 'transaction_recorded'",
        whereArgs: [date],
      );
    }
  }

  Future<int> streak() async {
    final db = await database;
    final rows = await db.query('daily_logs', columns: ['date']);
    final logged = rows.map((row) => row['date'] as String).toSet();
    var cursor = DateTime.now();
    var key = _dateKey(cursor);
    if (!logged.contains(key)) {
      cursor = cursor.subtract(const Duration(days: 1));
      key = _dateKey(cursor);
    }
    var count = 0;
    while (logged.contains(key)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
      key = _dateKey(cursor);
    }
    return count;
  }

  Future<void> saveBudget({
    required int categoryId,
    required int amount,
    required String month,
  }) async {
    if (amount <= 0) throw ArgumentError('Budget harus lebih dari nol.');
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('budget_months', {
        'month_year': month,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('budgets', {
        'category_id': categoryId,
        'amount_limit': amount,
        'month_year': month,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> deleteBudget(int categoryId, String month) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('budget_months', {
        'month_year': month,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.delete(
        'budgets',
        where: 'category_id = ? AND month_year = ?',
        whereArgs: [categoryId, month],
      );
    });
  }

  Future<List<Map<String, Object?>>> exportEntries(String type) async {
    final db = await database;
    if (type == 'transfer') {
      return db.rawQuery('''
        SELECT t.date, w.name AS wallet_name, tw.name AS target_wallet_name,
               t.note, t.amount
        FROM transactions t
        JOIN wallets w ON w.id = t.wallet_id
        JOIN wallets tw ON tw.id = t.target_wallet_id
        WHERE t.type = 'transfer'
        ORDER BY t.date
      ''');
    }
    return db.rawQuery(
      '''
      SELECT t.date, c.name AS category_name, w.name AS wallet_name,
             t.note, t.amount
      FROM transactions t
      JOIN wallets w ON w.id = t.wallet_id
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.type = ?
      ORDER BY t.date
    ''',
      [type],
    );
  }

  Future<String> _previousMonth(String month) {
    final parts = month.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]) - 1);
    return Future.value(
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}',
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
