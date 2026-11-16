import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'data/app_database.dart';
import 'models.dart';
import 'utils.dart';

class AppState extends ChangeNotifier {
  AppState(this._database);

  static const _exportChannel = MethodChannel('com.asepberuang.app/downloads');
  final AppDatabase _database;

  bool isReady = false;
  String? loadError;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Wallet> wallets = [];
  List<CategoryItem> categories = [];
  List<LedgerEntry> entries = [];
  List<BudgetItem> budgets = [];
  List<BudgetItem> currentBudgets = [];
  MonthlySummary summary = const MonthlySummary(
    totalBalance: 0,
    income: 0,
    expense: 0,
    budgetLimit: 0,
    budgetSpent: 0,
    overBudgetCount: 0,
  );
  MonthlySummary budgetSummary = const MonthlySummary(
    totalBalance: 0,
    income: 0,
    expense: 0,
    budgetLimit: 0,
    budgetSpent: 0,
    overBudgetCount: 0,
  );
  int streak = 0;

  List<Wallet> get activeWallets =>
      wallets.where((wallet) => wallet.isActive).toList();
  List<CategoryItem> get activeExpenseCategories => categories
      .where((category) => category.isActive && category.type == 'expense')
      .toList();
  List<CategoryItem> get activeIncomeCategories => categories
      .where((category) => category.isActive && category.type == 'income')
      .toList();

  String get monthKey =>
      '${selectedMonth.year.toString().padLeft(4, '0')}-${selectedMonth.month.toString().padLeft(2, '0')}';
  String get currentMonthKey => formatMonthKey(DateTime.now());

  Future<void> initialize() async {
    loadError = null;
    isReady = false;
    try {
      await _database.database;
      await refresh();
      isReady = true;
    } catch (error) {
      loadError = error.toString();
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await _database.ensureBudgetCarryOver(currentMonthKey);
    if (monthKey != currentMonthKey) {
      await _database.ensureBudgetCarryOver(monthKey);
    }
    final results = await Future.wait([
      _database.wallets(activeOnly: false),
      _database.categories('expense', activeOnly: false),
      _database.categories('income', activeOnly: false),
      _database.entries(limit: 100),
      _database.budgets(monthKey),
      _database.budgets(currentMonthKey),
      _database.summary(monthKey),
      _database.summary(currentMonthKey),
      _database.streak(),
    ]);
    wallets = (results[0] as List<Map<String, Object?>>)
        .map(Wallet.fromMap)
        .toList();
    categories = [
      ...(results[1] as List<Map<String, Object?>>).map(CategoryItem.fromMap),
      ...(results[2] as List<Map<String, Object?>>).map(CategoryItem.fromMap),
    ];
    entries = (results[3] as List<Map<String, Object?>>)
        .map(LedgerEntry.fromMap)
        .toList();
    budgets = (results[4] as List<Map<String, Object?>>)
        .map(_budgetFromMap)
        .toList();
    currentBudgets = (results[5] as List<Map<String, Object?>>)
        .map(_budgetFromMap)
        .toList();
    budgetSummary = _summaryFromMap(results[6] as Map<String, Object?>);
    summary = _summaryFromMap(results[7] as Map<String, Object?>);
    streak = results[8] as int;
    notifyListeners();
  }

  BudgetItem _budgetFromMap(Map<String, Object?> row) => BudgetItem(
    categoryId: row['category_id'] as int,
    categoryName: row['category_name'] as String,
    categoryIcon: row['category_icon'] as String,
    categoryColor: row['category_color'] as String,
    amountLimit: row['amount_limit'] as int,
    spent: row['spent'] as int,
  );

  MonthlySummary _summaryFromMap(Map<String, Object?> values) => MonthlySummary(
    totalBalance: values['balance'] as int,
    income: values['income'] as int,
    expense: values['expense'] as int,
    budgetLimit: values['budget_limit'] as int,
    budgetSpent: values['budget_spent'] as int,
    overBudgetCount: values['over_budget_count'] as int,
  );

  Future<void> changeMonth(int offset) async {
    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + offset);
    await refresh();
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
    await _database.addEntry(
      type: type,
      amount: amount,
      date: date,
      walletId: walletId,
      targetWalletId: targetWalletId,
      categoryId: categoryId,
      note: note,
      allowNegative: allowNegative,
    );
    await refresh();
  }

  Future<void> markNoExpenseToday() async {
    await _database.markNoExpense(DateTime.now());
    await refresh();
  }

  Future<void> saveWallet({
    int? id,
    required String name,
    required String icon,
    int initialBalance = 0,
  }) async {
    await _database.saveWallet(
      id: id,
      name: name,
      icon: icon,
      initialBalance: initialBalance,
    );
    await refresh();
  }

  Future<void> deleteWallet(int id) async {
    await _database.deleteWallet(id);
    await refresh();
  }

  Future<void> saveCategory({
    int? id,
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    await _database.saveCategory(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
    );
    await refresh();
  }

  Future<void> deleteCategory(int id) async {
    await _database.deleteCategory(id);
    await refresh();
  }

  Future<void> saveBudget({
    required int categoryId,
    required int amount,
  }) async {
    await _database.saveBudget(
      categoryId: categoryId,
      amount: amount,
      month: monthKey,
    );
    await refresh();
  }

  Future<void> deleteBudget(int categoryId) async {
    await _database.deleteBudget(categoryId, monthKey);
    await refresh();
  }

  Future<String> exportWorkbook() async {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');
    final summarySheet = workbook['Ringkasan'];
    summarySheet.appendRow([
      TextCellValue('Laporan Asep Beruang'),
      TextCellValue(currentMonthKey),
    ]);
    summarySheet.appendRow([
      TextCellValue('Saldo dompet aktif'),
      IntCellValue(summary.totalBalance),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total aset'),
      IntCellValue(summary.totalBalance),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total pemasukan'),
      IntCellValue(summary.income),
    ]);
    summarySheet.appendRow([
      TextCellValue('Total pengeluaran'),
      IntCellValue(summary.expense),
    ]);
    summarySheet.appendRow([
      TextCellValue('Selisih arus kas'),
      IntCellValue(summary.income - summary.expense),
    ]);
    summarySheet.appendRow([
      TextCellValue('Realisasi budget'),
      TextCellValue(
        '${formatRupiah(summary.budgetSpent)} / ${formatRupiah(summary.budgetLimit)}',
      ),
    ]);
    summarySheet.appendRow([
      TextCellValue('Status realisasi budget'),
      TextCellValue(
        summary.budgetLimit == 0
            ? 'Belum diatur'
            : summary.overBudgetCount > 0
            ? 'Melewati budget'
            : 'Dalam batas',
      ),
    ]);

    await _appendSheet(
      workbook,
      'Daftar Pengeluaran',
      ['Tanggal', 'Kategori', 'Dompet', 'Catatan', 'Nominal'],
      await _database.exportEntries('expense'),
      ['date', 'category_name', 'wallet_name', 'note', 'amount'],
    );
    await _appendSheet(
      workbook,
      'Daftar Pemasukan',
      ['Tanggal', 'Kategori', 'Dompet', 'Catatan', 'Nominal'],
      await _database.exportEntries('income'),
      ['date', 'category_name', 'wallet_name', 'note', 'amount'],
    );
    await _appendSheet(
      workbook,
      'Riwayat Transfer',
      ['Tanggal', 'Dompet Asal', 'Dompet Tujuan', 'Catatan', 'Nominal'],
      await _database.exportEntries('transfer'),
      ['date', 'wallet_name', 'target_wallet_name', 'note', 'amount'],
    );

    final bytes = workbook.save();
    if (bytes == null) throw StateError('Gagal membuat file Excel.');
    final temp = await getTemporaryDirectory();
    final fileName = 'Asep_Beruang_$currentMonthKey.xlsx';
    final file = File('${temp.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    try {
      final savedName = await _exportChannel.invokeMethod<String>(
        'saveToDownloads',
        {'path': file.path, 'fileName': fileName},
      );
      if (savedName == null || savedName.isEmpty) {
        throw StateError('Android tidak mengembalikan nama file hasil ekspor.');
      }
      return savedName;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _appendSheet(
    Excel workbook,
    String name,
    List<String> headers,
    List<Map<String, Object?>> rows,
    List<String> columns,
  ) async {
    final sheet = workbook[name];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow(
        columns.map((column) {
          final value = row[column];
          if (column == 'amount') return IntCellValue(value as int);
          if (column == 'date' && value is String) {
            return TextCellValue(value.substring(0, 10));
          }
          return TextCellValue(value?.toString() ?? '');
        }).toList(),
      );
    }
  }
}
