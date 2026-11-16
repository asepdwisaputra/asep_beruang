class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.balance,
    required this.icon,
    required this.isActive,
  });

  final int id;
  final String name;
  final int balance;
  final String icon;
  final bool isActive;

  factory Wallet.fromMap(Map<String, Object?> map) => Wallet(
    id: map['id'] as int,
    name: map['name'] as String,
    balance: map['balance'] as int,
    icon: map['icon'] as String,
    isActive: map['is_active'] as int == 1,
  );
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isActive,
  });

  final int id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final bool isActive;

  factory CategoryItem.fromMap(Map<String, Object?> map) => CategoryItem(
    id: map['id'] as int,
    name: map['name'] as String,
    type: map['type'] as String,
    icon: map['icon'] as String,
    color: map['color'] as String,
    isActive: map['is_active'] as int == 1,
  );
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.walletId,
    required this.targetWalletId,
    required this.categoryId,
    required this.note,
    required this.walletName,
    required this.targetWalletName,
    required this.categoryName,
  });

  final int id;
  final String type;
  final int amount;
  final DateTime date;
  final int walletId;
  final int? targetWalletId;
  final int? categoryId;
  final String? note;
  final String walletName;
  final String? targetWalletName;
  final String? categoryName;

  factory LedgerEntry.fromMap(Map<String, Object?> map) => LedgerEntry(
    id: map['id'] as int,
    type: map['type'] as String,
    amount: map['amount'] as int,
    date: DateTime.parse(map['date'] as String),
    walletId: map['wallet_id'] as int,
    targetWalletId: map['target_wallet_id'] as int?,
    categoryId: map['category_id'] as int?,
    note: map['note'] as String?,
    walletName: map['wallet_name'] as String? ?? 'Dompet dihapus',
    targetWalletName: map['target_wallet_name'] as String?,
    categoryName: map['category_name'] as String?,
  );
}

class BudgetItem {
  const BudgetItem({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amountLimit,
    required this.spent,
  });

  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final int amountLimit;
  final int spent;

  double get progress => amountLimit == 0 ? 0 : spent / amountLimit;
}

class MonthlySummary {
  const MonthlySummary({
    required this.totalBalance,
    required this.income,
    required this.expense,
    required this.budgetLimit,
    required this.budgetSpent,
    required this.overBudgetCount,
  });

  final int totalBalance;
  final int income;
  final int expense;
  final int budgetLimit;
  final int budgetSpent;
  final int overBudgetCount;
}
