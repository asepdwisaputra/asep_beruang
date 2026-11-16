import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'data/app_database.dart';
import 'screens.dart';
import 'transaction_form.dart';
import 'mascot.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(AppDatabase.instance),
      child: const AsepBeruangApp(),
    ),
  );
}

class AsepBeruangApp extends StatelessWidget {
  const AsepBeruangApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5A8D62);
    return MaterialApp(
      title: 'Asep Beruang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          primary: seed,
          surface: const Color(0xFFFFFCF6),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFCF6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFCF6),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFECE9E1)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F5EF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.loadError != null) {
          return _StartupError(message: state.loadError!);
        }
        if (!state.isReady) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFCF6), Color(0xFFEAF2E3)],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: 340,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Color(0x1A315D43), blurRadius: 28, offset: Offset(0, 12))],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BearMascot(size: 112),
                        SizedBox(height: 14),
                        Text('Asep Beruang', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF315D43))),
                        SizedBox(height: 6),
                        Text('Teman baik dompetmu', style: TextStyle(color: Color(0xFF77766F))),
                        SizedBox(height: 24),
                        SizedBox(width: 150, child: LinearProgressIndicator(minHeight: 6, borderRadius: BorderRadius.all(Radius.circular(9)))),
                        SizedBox(height: 12),
                        Text('Menyiapkan catatan keuangan...', style: TextStyle(fontSize: 12, color: Color(0xFF77766F))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return const AppShell();
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Asep Beruang belum dapat dibuka',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.read<AppState>().initialize(),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final _titles = const ['Beranda', 'Aktivitas', 'Anggaran', 'Dompet'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onOpenBudgets: () => setState(() => _tab = 2)),
      const HistoryScreen(),
      const BudgetsScreen(),
      const WalletsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_tab],
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (_tab == 0)
              const Text(
                'Teman baik dompetmu',
                style: TextStyle(fontSize: 12, color: Color(0xFF77766F)),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kategori',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CategoriesScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Lencana',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BadgesScreen()),
            ),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: 'quick_add',
        tooltip: 'Tambah transaksi',
        onPressed: () => showQuickActions(context),
        backgroundColor: const Color(0xFFF5B544),
        foregroundColor: const Color(0xFF352811),
        elevation: 5,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavButton(
              icon: Icons.home_rounded,
              label: 'Beranda',
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0),
            ),
            _NavButton(
              icon: Icons.receipt_long_rounded,
              label: 'Aktivitas',
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1),
            ),
            const SizedBox(width: 54),
            _NavButton(
              icon: Icons.pie_chart_rounded,
              label: 'Anggaran',
              selected: _tab == 2,
              onTap: () => setState(() => _tab = 2),
            ),
            _NavButton(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Dompet',
              selected: _tab == 3,
              onTap: () => setState(() => _tab = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 21,
            color: selected ? const Color(0xFF4F8059) : Colors.grey,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF4F8059) : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}
