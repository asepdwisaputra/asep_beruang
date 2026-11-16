import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'models.dart';
import 'utils.dart';
import 'mascot.dart';
import 'transaction_form.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenBudgets});

  final VoidCallback onOpenBudgets;

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
    builder: (context, state, _) {
      final ratio = state.summary.budgetLimit == 0
          ? 0.0
          : state.summary.budgetSpent / state.summary.budgetLimit;
      final sleeping = state.summary.overBudgetCount > 0 || state.streak == 0;
      final cautious = ratio >= 0.75 && ratio < 1;
      final mood = sleeping
          ? BearMood.sleepy
          : cautious
          ? BearMood.careful
          : BearMood.happy;
      final message = sleeping
          ? state.summary.overBudgetCount > 0
                ? 'Yuk, cek lagi anggaran yang terlewat.'
                : 'Ayo mulai catat hari ini, kita bangun streak baru!'
          : cautious
          ? 'Hati-hati ya, anggaran mulai menipis.'
          : 'Keuanganmu terpantau. Semangat terus!';
      return RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            _MascotCard(mood: mood, message: message, streak: state.streak),
            const SizedBox(height: 16),
            _BalanceCard(
              balance: state.summary.totalBalance,
              income: state.summary.income,
              expense: state.summary.expense,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Anggaran bulan ini',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: onOpenBudgets,
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
            if (state.currentBudgets.isEmpty)
              _EmptyCard(
                icon: Icons.pie_chart_outline_rounded,
                title: 'Belum ada anggaran',
                subtitle: 'Atur batas pengeluaran per kategori.',
                action: 'Buat anggaran',
                onTap: onOpenBudgets,
              )
            else ...[
              _BudgetOverviewCard(
                spent: state.summary.budgetSpent,
                limit: state.summary.budgetLimit,
                overCount: state.summary.overBudgetCount,
              ),
              const SizedBox(height: 10),
              ...state.currentBudgets
                  .take(3)
                  .map(
                    (budget) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BudgetRow(budget: budget),
                    ),
                  ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await state.markNoExpenseToday();
                  if (context.mounted) {
                    _showMessage(
                      context,
                      'Catatan aktivitas hari ini tersimpan.',
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    _showMessage(context, 'Gagal menyimpan: $error');
                  }
                }
              },
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Hari ini tidak ada pengeluaran'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Aktivitas terbaru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Ekspor Excel ke Download',
                  onPressed: () => _export(context, state),
                  icon: const Icon(Icons.file_download_outlined),
                ),
              ],
            ),
            if (state.entries.isEmpty)
              const _EmptyCard(
                icon: Icons.receipt_long_rounded,
                title: 'Belum ada transaksi',
                subtitle: 'Tekan tombol + untuk mulai mencatat.',
              )
            else
              ...state.entries.take(5).map((entry) => EntryTile(entry: entry)),
            const SizedBox(height: 16),
            _ExportButton(onPressed: () => _export(context, state)),
          ],
        ),
      );
    },
  );
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
    builder: (context, state, _) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Transaksi tersimpan di perangkat ini',
                  style: TextStyle(color: Color(0xFF74736D)),
                ),
              ),
              IconButton(
                tooltip: 'Ekspor Excel',
                onPressed: () => _export(context, state),
                icon: const Icon(Icons.file_download_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.entries.isEmpty
              ? const Center(
                  child: _EmptyCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'Belum ada aktivitas',
                    subtitle: 'Transaksi yang kamu catat akan muncul di sini.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: state.refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    itemCount: state.entries.length,
                    itemBuilder: (context, index) =>
                        EntryTile(entry: state.entries[index]),
                  ),
                ),
        ),
      ],
    ),
  );
}

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
    builder: (context, state, _) => Column(
      children: [
        _MonthPicker(month: state.selectedMonth, onChange: state.changeMonth),
        Expanded(
          child: state.budgets.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _BudgetOverviewCard(spent: 0, limit: 0, overCount: 0),
                    const SizedBox(height: 16),
                    _EmptyCard(
                      icon: Icons.savings_outlined,
                      title: 'Belum ada anggaran',
                      subtitle: 'Budget bersifat opsional. Mulai dari kategori yang paling penting.',
                      action: 'Tambah kategori budget',
                      onTap: () => showBudgetEditor(context),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    _BudgetOverviewCard(
                      spent: state.budgetSummary.budgetSpent,
                      limit: state.budgetSummary.budgetLimit,
                      overCount: state.budgetSummary.overBudgetCount,
                    ),
                    const SizedBox(height: 12),
                    ...state.budgets.map(
                      (budget) => _BudgetManageCard(budget: budget),
                    ),
                    const SizedBox(height: 12),
                    _ExportButton(onPressed: () => _export(context, state)),
                  ],
                ),
        ),
      ],
    ),
  );
}

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
    builder: (context, state, _) {
      final wallets = state.activeWallets;
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
        _WalletTotalCard(
          balance: state.summary.totalBalance,
          walletCount: state.activeWallets.length,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Dompet aktif',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => showWalletEditor(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (wallets.length > 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Tekan dan tahan ikon seret untuk mengubah urutan.',
              style: TextStyle(fontSize: 12, color: Color(0xFF77766F)),
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: wallets.length,
          onReorder: (oldIndex, newIndex) async {
            final reordered = [...wallets];
            if (newIndex > oldIndex) newIndex -= 1;
            final wallet = reordered.removeAt(oldIndex);
            reordered.insert(newIndex, wallet);
            await state.reorderWallets(reordered);
          },
          itemBuilder: (context, index) {
            final wallet = wallets[index];
            return Card(
              key: ValueKey(wallet.id),
              child: ListTile(
                leading: _IconBubble(
                  icon: iconFromName(wallet.icon),
                  color: const Color(0xFF548860),
                ),
                title: Text(wallet.name),
                subtitle: Text(formatRupiah(wallet.balance)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          await showWalletEditor(context, wallet: wallet);
                        } else {
                          await _confirmDelete(
                            context,
                            title: 'Hapus dompet?',
                            message: 'Dompet dengan riwayat transaksi akan dinonaktifkan agar catatan lama tetap utuh.',
                            onDelete: () => state.deleteWallet(wallet.id),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Ubah nama')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.drag_handle_rounded, color: Color(0xFF77766F)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (state.activeWallets.isEmpty)
          const _EmptyCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Belum ada dompet aktif',
            subtitle: 'Tambahkan dompet untuk mulai mencatat transaksi.',
          ),
        ],
      );
    },
  );
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kelola kategori')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => showCategoryEditor(context),
      icon: const Icon(Icons.add),
      label: const Text('Kategori'),
    ),
    body: Consumer<AppState>(
      builder: (context, state, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const Text(
            'Pengeluaran',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          ...state.categories
              .where((category) => category.type == 'expense')
              .map((category) => _CategoryTile(category: category)),
          const SizedBox(height: 16),
          const Text(
            'Pemasukan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          ...state.categories
              .where((category) => category.type == 'income')
              .map((category) => _CategoryTile(category: category)),
        ],
      ),
    ),
  );
}

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lencana rahasia')),
    body: Consumer<AppState>(
      builder: (context, state, _) {
        final hasBudget = state.currentBudgets.isNotEmpty;
        final badges = [
          _BadgeData(
            icon: Icons.edit_note_rounded,
            title: 'Pencatat Pemula',
            description: 'Pertahankan streak selama 3 hari.',
            unlocked: state.streak >= 3,
          ),
          _BadgeData(
            icon: Icons.local_fire_department_rounded,
            title: 'Api Semangat',
            description: 'Pertahankan streak selama 7 hari.',
            unlocked: state.streak >= 7,
          ),
          _BadgeData(
            icon: Icons.shield_rounded,
            title: 'Anti Jebol',
            description: 'Punya budget bulan ini dan tidak melewatinya.',
            unlocked: hasBudget && state.summary.overBudgetCount == 0,
          ),
          _BadgeData(
            icon: Icons.receipt_long_rounded,
            title: 'Rajin Mencatat',
            description: 'Simpan sedikitnya 10 aktivitas.',
            unlocked: state.entries.length >= 10,
          ),
        ];
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Terus lakukan kebiasaan baik. Lencana tersimpan lokal di perangkatmu.',
              style: TextStyle(color: Color(0xFF74736D)),
            ),
            const SizedBox(height: 14),
            ...badges.map(
              (badge) => Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: badge.unlocked
                        ? const Color(0xFFFFE7AD)
                        : const Color(0xFFE9E8E3),
                    child: Icon(
                      badge.icon,
                      color: badge.unlocked
                          ? const Color(0xFF9A6B18)
                          : Colors.grey,
                    ),
                  ),
                  title: Text(
                    badge.unlocked ? badge.title : 'Lencana rahasia',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    badge.unlocked
                        ? badge.description
                        : 'Selesaikan tantangan untuk membukanya.',
                  ),
                  trailing: Icon(
                    badge.unlocked ? Icons.check_circle : Icons.lock_outline,
                    color: badge.unlocked ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _BadgeData {
  const _BadgeData({
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;
}

class _MascotCard extends StatelessWidget {
  const _MascotCard({
    required this.mood,
    required this.message,
    required this.streak,
  });

  final BearMood mood;
  final String message;
  final int streak;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFFE8F3DE), Color(0xFFF7F3D9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: BearMascot(
            key: ValueKey(mood),
            size: 76,
            mood: mood,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFE88732),
                    size: 19,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$streak ${streak == 1 ? 'hari' : 'hari'} beruntun',
                    style: const TextStyle(
                      color: Color(0xFF6D4826),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A5142),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
  });

  final int balance;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF315D43),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total saldo dompet aktif',
            style: TextStyle(color: Color(0xFFD8E9D8)),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _FlowValue(
                  label: 'Pemasukan',
                  value: income,
                  icon: Icons.south_west_rounded,
                  color: const Color(0xFFBDE7BB),
                ),
              ),
              Expanded(
                child: _FlowValue(
                  label: 'Pengeluaran',
                  value: expense,
                  icon: Icons.north_east_rounded,
                  color: const Color(0xFFFFD1B5),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _FlowValue extends StatelessWidget {
  const _FlowValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              formatRupiah(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BudgetOverviewCard extends StatelessWidget {
  const _BudgetOverviewCard({
    required this.spent,
    required this.limit,
    required this.overCount,
  });

  final int spent;
  final int limit;
  final int overCount;

  @override
  Widget build(BuildContext context) {
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final over = overCount > 0;
    final progressColor = over
        ? const Color(0xFFB9473F)
        : ratio >= 0.75
        ? const Color(0xFFE1A33B)
        : const Color(0xFF568960);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Realisasi budget',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  limit == 0 ? 'Belum diatur' : '${(ratio * 100).round()}%',
                  style: TextStyle(
                    color: progressColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: limit == 0 ? 0 : ratio.clamp(0, 1),
                minHeight: 10,
                backgroundColor: const Color(0xFFEDEBE4),
                color: progressColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatRupiah(spent)} dari ${formatRupiah(limit)}',
                    style: const TextStyle(color: Color(0xFF77766F)),
                  ),
                ),
                if (over)
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 17,
                        color: Color(0xFFB9473F),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Melewati budget',
                        style: TextStyle(
                          color: Color(0xFFB9473F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});

  final BudgetItem budget;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(budget.categoryColor);
    final over = budget.spent > budget.amountLimit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _IconBubble(icon: iconFromName(budget.categoryIcon), color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    budget.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: budget.progress.clamp(0, 1),
                      minHeight: 6,
                      color: over ? const Color(0xFFB9473F) : color,
                      backgroundColor: const Color(0xFFF0EEE8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatRupiah(budget.amountLimit),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: over ? const Color(0xFFB9473F) : const Color(0xFF55534D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetManageCard extends StatelessWidget {
  const _BudgetManageCard({required this.budget});

  final BudgetItem budget;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        _BudgetRow(budget: budget),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => showBudgetEditor(context, budget: budget),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Ubah'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final state = context.read<AppState>();
                  await _confirmDelete(
                    context,
                    title: 'Hapus anggaran?',
                    message:
                        'Anggaran ${budget.categoryName} untuk bulan ini akan dihapus.',
                    onDelete: () => state.deleteBudget(budget.categoryId),
                  );
                },
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('Hapus'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.month, required this.onChange});

  final DateTime month;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          onPressed: () => onChange(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          formatMonth(month),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          onPressed: () => onChange(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _WalletTotalCard extends StatelessWidget {
  const _WalletTotalCard({required this.balance, required this.walletCount});

  final int balance;
  final int walletCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF315D43),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$walletCount dompet aktif',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          formatRupiah(balance),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategoryItem category;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: _IconBubble(
        icon: iconFromName(category.icon),
        color: colorFromHex(category.color),
      ),
      title: Text(category.name),
      subtitle: category.isActive ? null : const Text('Nonaktif'),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          final state = context.read<AppState>();
          if (action == 'edit') {
            await showCategoryEditor(context, category: category);
          } else {
            await _confirmDelete(
              context,
              title: 'Hapus kategori?',
              message: 'Kategori dengan transaksi atau budget akan dinonaktifkan agar riwayat tetap utuh.',
              onDelete: () => state.deleteCategory(category.id),
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Ubah')),
          PopupMenuItem(value: 'delete', child: Text('Hapus')),
        ],
      ),
    ),
  );
}

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final transfer = entry.type == 'transfer';
    final income = entry.type == 'income';
    final color = transfer
        ? const Color(0xFF5280C3)
        : income
        ? const Color(0xFF43865A)
        : const Color(0xFFD16D54);
    final title = transfer
        ? '${entry.walletName} → ${entry.targetWalletName ?? 'Dompet'}'
        : entry.categoryName ?? 'Transaksi';
    final subtitle = [
      formatDate(entry.date),
      if (!transfer) entry.walletName,
      if (entry.note?.isNotEmpty == true) entry.note!,
    ].join(' • ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _IconBubble(
          icon: transfer
              ? Icons.swap_horiz_rounded
              : income
              ? Icons.south_west_rounded
              : Icons.north_east_rounded,
          color: color,
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
          '${income
              ? '+'
              : transfer
              ? ''
              : '−'}${formatRupiah(entry.amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Kelola transaksi',
              onSelected: (action) async {
                if (action == 'edit') {
                  await showEditEntry(context, entry);
                } else {
                  await _confirmDelete(
                    context,
                    title: 'Hapus transaksi?',
                    message: 'Transaksi dihapus dan saldo dompet terkait diperbarui.',
                    onDelete: () => context.read<AppState>().deleteEntry(entry.id),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Ubah transaksi')),
                PopupMenuItem(value: 'delete', child: Text('Hapus transaksi')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: color.withValues(alpha: 0.13),
    foregroundColor: color,
    child: Icon(icon, size: 20),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const BearMascot(size: 70),
          const SizedBox(height: 8),
          Icon(icon, size: 18, color: const Color(0xFF75917A)),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF77766F)),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onTap, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.file_download_outlined),
    label: const Text('Ekspor laporan Excel ke Download'),
  );
}

class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({this.budget});

  final BudgetItem? budget;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  final _amountController = TextEditingController();
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.budget?.categoryId;
    if (widget.budget != null) {
      _amountController.text = widget.budget!.amountLimit.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories = [...state.activeExpenseCategories];
    final currentCategory = widget.budget == null
        ? null
        : state.categories
              .where((category) => category.id == widget.budget!.categoryId)
              .firstOrNull;
    if (currentCategory != null &&
        categories.every((category) => category.id != currentCategory.id)) {
      categories.add(currentCategory);
    }
    return AlertDialog(
      title: Text(widget.budget == null ? 'Tambah anggaran' : 'Ubah anggaran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            decoration: const InputDecoration(
              labelText: 'Kategori pengeluaran',
            ),
            items: categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                )
                .toList(),
            onChanged: widget.budget != null
                ? null
                : (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Batas anggaran',
              prefixText: 'Rp ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving || categories.isEmpty ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final categoryId = _categoryId;
    final amount = int.tryParse(_amountController.text.replaceAll('.', ''));
    if (categoryId == null || amount == null || amount <= 0) {
      _showMessage(context, 'Pilih kategori dan isi budget lebih dari nol.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().saveBudget(
        categoryId: categoryId,
        amount: amount,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(context, 'Gagal menyimpan anggaran: $error');
      }
    }
  }
}

class _WalletEditor extends StatefulWidget {
  const _WalletEditor({this.wallet});

  final Wallet? wallet;

  @override
  State<_WalletEditor> createState() => _WalletEditorState();
}

class _WalletEditorState extends State<_WalletEditor> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.wallet?.name ?? '';
    _balanceController.text = widget.wallet == null
        ? ''
        : widget.wallet!.balance.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.wallet == null ? 'Tambah dompet' : 'Ubah dompet'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama dompet'),
        ),
        if (widget.wallet == null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _balanceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Saldo awal',
              prefixText: 'Rp ',
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'Saldo berubah otomatis mengikuti transaksi.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Simpan'),
      ),
    ],
  );

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final balanceText = _balanceController.text.trim();
    final parsedBalance = widget.wallet == null
        ? (balanceText.isEmpty
              ? 0
              : int.tryParse(balanceText.replaceAll('.', '')))
        : 0;
    final balance = parsedBalance ?? 0;
    if (name.isEmpty ||
        balance < 0 ||
        (widget.wallet == null && parsedBalance == null)) {
      _showMessage(
        context,
        'Nama dompet wajib diisi dan saldo tidak boleh minus.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().saveWallet(
        id: widget.wallet?.id,
        name: name,
        icon: 'account_balance_wallet',
        initialBalance: balance,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(context, 'Gagal menyimpan dompet: $error');
      }
    }
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({this.category});

  final CategoryItem? category;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final _nameController = TextEditingController();
  late String _type;
  late String _icon;
  late String _color;
  bool _saving = false;

  static const _choices = <(String, IconData, String)>[
    ('restaurant', Icons.restaurant_rounded, '#F08B54'),
    ('directions_car', Icons.directions_car_rounded, '#5686D5'),
    ('shopping_bag', Icons.shopping_bag_rounded, '#BD6AB0'),
    ('receipt_long', Icons.receipt_long_rounded, '#E1B649'),
    ('payments', Icons.payments_rounded, '#41A27A'),
    ('redeem', Icons.redeem_rounded, '#E3A331'),
    ('savings', Icons.savings_rounded, '#5B8C5A'),
    ('home', Icons.home_rounded, '#8B7AD1'),
    ('school', Icons.school_rounded, '#5D9EA6'),
    ('pets', Icons.pets_rounded, '#BC8064'),
    ('flight', Icons.flight_rounded, '#5686D5'),
    ('more_horiz', Icons.more_horiz_rounded, '#8291A6'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.category?.name ?? '';
    _type = widget.category?.type ?? 'expense';
    _icon = widget.category?.icon ?? 'restaurant';
    _color = widget.category?.color ?? '#F08B54';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.category == null ? 'Tambah kategori' : 'Ubah kategori'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Jenis'),
          items: const [
            DropdownMenuItem(value: 'expense', child: Text('Pengeluaran')),
            DropdownMenuItem(value: 'income', child: Text('Pemasukan')),
          ],
          onChanged: widget.category != null
              ? null
              : (value) => setState(() => _type = value ?? 'expense'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _icon,
          decoration: const InputDecoration(labelText: 'Ikon'),
          items: _choices
              .map(
                (choice) => DropdownMenuItem(
                  value: choice.$1,
                  child: Row(
                    children: [
                      Icon(choice.$2, size: 19),
                      const SizedBox(width: 8),
                      Text(choice.$1.replaceAll('_', ' ')),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            final choice = _choices.firstWhere((item) => item.$1 == value);
            setState(() {
              _icon = value;
              _color = choice.$3;
            });
          },
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Simpan'),
      ),
    ],
  );

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(context, 'Nama kategori wajib diisi.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().saveCategory(
        id: widget.category?.id,
        name: name,
        type: _type,
        icon: _icon,
        color: _color,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(context, 'Gagal menyimpan kategori: $error');
      }
    }
  }
}

void showBudgetEditor(BuildContext context, {BudgetItem? budget}) {
  showDialog<void>(
    context: context,
    builder: (_) => _BudgetEditor(budget: budget),
  );
}

Future<void> showWalletEditor(BuildContext context, {Wallet? wallet}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _WalletEditor(wallet: wallet),
  );
}

Future<void> showCategoryEditor(
  BuildContext context, {
  CategoryItem? category,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _CategoryEditor(category: category),
  );
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onDelete,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await onDelete();
  } catch (error) {
    if (context.mounted) _showMessage(context, 'Gagal menghapus: $error');
  }
}

Future<void> _export(BuildContext context, AppState state) async {
  try {
    final fileName = await state.exportWorkbook();
    if (context.mounted) {
      _showMessage(context, 'Laporan tersimpan di Download/$fileName');
    }
  } catch (error) {
    if (context.mounted) _showMessage(context, 'Ekspor Excel gagal: $error');
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
