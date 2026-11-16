import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'utils.dart';

Future<void> showQuickActions(BuildContext context) async {
  final type = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _QuickActionSheet(),
  );
  if (type == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TransactionForm(type: type),
  );
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet();

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'expense',
        'Pengeluaran',
        Icons.north_east_rounded,
        const Color(0xFFD16D54),
      ),
      (
        'income',
        'Pemasukan',
        Icons.south_west_rounded,
        const Color(0xFF43865A),
      ),
      (
        'transfer',
        'Transfer',
        Icons.swap_horiz_rounded,
        const Color(0xFF5280C3),
      ),
    ];
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Mau catat apa?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...options.map(
              (option) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: option.$4.withValues(alpha: 0.13),
                    child: Icon(option.$3, color: option.$4),
                  ),
                  title: Text(
                    option.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, option.$1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({super.key, required this.type});

  final String type;

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  int? _walletId;
  int? _targetWalletId;
  int? _categoryId;
  bool _saving = false;

  bool get _isTransfer => widget.type == 'transfer';
  bool get _isOutflow => widget.type == 'expense' || _isTransfer;
  String get _title => switch (widget.type) {
    'income' => 'Catat pemasukan',
    'transfer' => 'Transfer antar dompet',
    _ => 'Catat pengeluaran',
  };

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final wallets = state.activeWallets;
    _walletId = wallets.isEmpty ? null : wallets.first.id;
    final otherWallets = wallets.where((wallet) => wallet.id != _walletId);
    _targetWalletId = otherWallets.isEmpty ? null : otherWallets.first.id;
    final categories = widget.type == 'income'
        ? state.activeIncomeCategories
        : state.activeExpenseCategories;
    _categoryId = categories.isEmpty ? null : categories.first.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final wallets = state.activeWallets;
    final categories = widget.type == 'income'
        ? state.activeIncomeCategories
        : state.activeExpenseCategories;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              _SelectField<int>(
                label: _isOutflow ? 'Dompet sumber' : 'Dompet tujuan',
                value: _walletId,
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem(
                        value: wallet.id,
                        child: Text(
                          '${wallet.name} · ${formatRupiah(wallet.balance)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _walletId = value),
              ),
              if (_isTransfer) ...[
                const SizedBox(height: 12),
                _SelectField<int>(
                  label: 'Dompet tujuan transfer',
                  value: _targetWalletId,
                  items: wallets
                      .where((wallet) => wallet.id != _walletId)
                      .map(
                        (wallet) => DropdownMenuItem(
                          value: wallet.id,
                          child: Text(
                            '${wallet.name} · ${formatRupiah(wallet.balance)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _targetWalletId = value),
                ),
                if (wallets.length < 2)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Transfer memerlukan setidaknya dua dompet aktif.',
                      style: TextStyle(color: Color(0xFFB9473F), fontSize: 12),
                    ),
                  ),
              ],
              if (!_isTransfer) ...[
                const SizedBox(height: 12),
                _SelectField<int>(
                  label: 'Kategori',
                  value: _categoryId,
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                if (categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Belum ada kategori aktif untuk transaksi ini.',
                      style: TextStyle(color: Color(0xFFB9473F), fontSize: 12),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('Tanggal: ${formatDate(_date)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  counterText: '',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _saving ||
                          wallets.isEmpty ||
                          (_isTransfer && wallets.length < 2) ||
                          (!_isTransfer && categories.isEmpty)
                      ? null
                      : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan transaksi'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      helpText: 'Pilih tanggal transaksi',
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Masukkan nominal lebih dari nol.');
      return;
    }
    if (_walletId == null) {
      _showError('Pilih dompet.');
      return;
    }
    if (_isTransfer && _targetWalletId == _walletId) {
      _showError('Dompet sumber dan tujuan harus berbeda.');
      return;
    }
    if (!_isTransfer && _categoryId == null) {
      _showError('Pilih kategori.');
      return;
    }

    var allowNegative = false;
    if (_isOutflow) {
      final source = state.activeWallets.firstWhere(
        (wallet) => wallet.id == _walletId,
      );
      if (amount > source.balance) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Saldo tidak mencukupi'),
            content: const Text(
              'Saldo dompet tidak mencukupi. Lanjutkan transaksi dan biarkan saldo minus?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batalkan'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
        allowNegative = true;
      }
    }

    setState(() => _saving = true);
    try {
      await state.addEntry(
        type: widget.type,
        amount: amount,
        date: DateTime(_date.year, _date.month, _date.day, 12),
        walletId: _walletId!,
        targetWalletId: _isTransfer ? _targetWalletId : null,
        categoryId: _isTransfer ? null : _categoryId,
        note: _noteController.text,
        allowNegative: allowNegative,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil disimpan.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Transaksi gagal disimpan: $error');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SelectField<T> extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: items.any((item) => item.value == value) ? value : null,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: items,
    onChanged: onChanged,
  );
}
