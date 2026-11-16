import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:asep_beruang/data/app_database.dart';
import 'package:asep_beruang/utils.dart';

void main() {
  late Directory databaseDirectory;
  final database = AppDatabase.instance;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseDirectory = await Directory.systemTemp.createTemp(
      'asep_beruang_test_',
    );
    await databaseFactory.setDatabasesPath(databaseDirectory.path);
  });

  tearDownAll(() async {
    await database.close();
    await databaseDirectory.delete(recursive: true);
  });

  test(
    'seeds defaults, applies transfers atomically, and tracks budgets',
    () async {
      final db = await database.database;
      final wallets = await database.wallets();
      final incomeCategories = await database.categories('income');
      final expenseCategories = await database.categories('expense');
      expect(wallets, hasLength(1));
      expect(wallets.first['name'], 'Cash / Tunai');
      expect(incomeCategories, hasLength(3));
      expect(expenseCategories, hasLength(5));

      final cashId = wallets.first['id'] as int;
      final bankId = await database.saveWallet(
        name: 'Tabungan',
        icon: 'account_balance_wallet',
      );
      final today = DateTime.now();
      final month = formatMonthKey(today);
      final previous = formatMonthKey(DateTime(today.year, today.month - 1));
      final expenseCategoryId = expenseCategories.first['id'] as int;
      final incomeCategoryId = incomeCategories.first['id'] as int;

      await database.addEntry(
        type: 'income',
        amount: 50000,
        date: today,
        walletId: cashId,
        categoryId: incomeCategoryId,
        allowNegative: false,
      );
      await database.markNoExpense(today);
      await database.addEntry(
        type: 'transfer',
        amount: 20000,
        date: today,
        walletId: cashId,
        targetWalletId: bankId,
        allowNegative: false,
      );
      final log = await db.query(
        'daily_logs',
        where: 'date = ?',
        whereArgs: [today.toIso8601String().substring(0, 10)],
      );
      expect(log.single['status'], 'transaction_recorded');

      await expectLater(
        database.addEntry(
          type: 'expense',
          amount: 25000,
          date: today,
          walletId: bankId,
          categoryId: expenseCategoryId,
          allowNegative: false,
        ),
        throwsStateError,
      );
      final entriesAfterRejection = await database.entries(limit: 100);
      expect(entriesAfterRejection, hasLength(2));

      await database.addEntry(
        type: 'expense',
        amount: 25000,
        date: today,
        walletId: bankId,
        categoryId: expenseCategoryId,
        allowNegative: true,
      );
      await database.saveBudget(
        categoryId: expenseCategoryId,
        amount: 100000,
        month: previous,
      );
      await database.ensureBudgetCarryOver(month);
      await database.ensureBudgetCarryOver(month);

      final budgetRows = await database.budgets(month);
      expect(budgetRows, hasLength(1));
      expect(budgetRows.single['amount_limit'], 100000);
      var summary = await database.summary(month);
      expect(summary['budget_limit'], 100000);
      expect(summary['budget_spent'], 25000);
      expect(summary['over_budget_count'], 0);

      await database.saveBudget(
        categoryId: expenseCategoryId,
        amount: 20000,
        month: month,
      );
      summary = await database.summary(month);
      expect(summary['over_budget_count'], 1);

      await database.deleteBudget(expenseCategoryId, month);
      await database.ensureBudgetCarryOver(month);
      expect(await database.budgets(month), isEmpty);
      summary = await database.summary(month);
      expect(summary['balance'], 25000);
      expect(summary['income'], 50000);
      expect(summary['expense'], 25000);
      expect(summary['budget_limit'], 0);
      expect(summary['budget_spent'], 0);
      expect(summary['over_budget_count'], 0);

      final transferRows = await database.exportEntries('transfer');
      expect(transferRows, hasLength(1));
    },
  );
}
