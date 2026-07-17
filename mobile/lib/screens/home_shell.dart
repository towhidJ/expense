import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../ota_update.dart';
import '../theme.dart';
import 'accounts_screen.dart';
import 'bazar_screen.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'premium_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _tab = 0;
  // Subtle crossfade when switching bottom-nav tabs; IndexedStack keeps each
  // tab's state alive, the controller only re-runs the fade.
  late final AnimationController _tabAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1);

  @override
  void initState() {
    super.initState();
    widget.state.load();
    // Silent OTA check once the first frame is up (dialog only if newer).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    _tabAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final titles = ['Dashboard', 'Transactions', 'Bazar', 'Accounts', 'More'];
        final isBazar = _tab == 2; // BazarScreen brings its own AppBar + FAB
        return Scaffold(
          appBar: isBazar
              ? null
              : AppBar(
                  title: Text(titles[_tab], style: const TextStyle(fontWeight: FontWeight.bold)),
                  actions: [
                    if (st.entities.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _WorkspaceChip(state: st),
                      ),
                  ],
                ),
          body: st.loading
              ? const Center(child: CircularProgressIndicator(color: kCyan))
              : FadeTransition(
                  opacity: CurvedAnimation(parent: _tabAnim, curve: Curves.easeOut),
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      DashboardScreen(state: st),
                      TransactionsScreen(state: st),
                      // Bazar is premium-gateable; PremiumScreen brings its own
                      // AppBar just like BazarScreen, so isBazar still applies.
                      st.isLocked('bazar')
                          ? PremiumScreen(state: st, lockedLabel: 'Bazar')
                          : BazarScreen(state: st),
                      AccountsScreen(state: st),
                      MoreScreen(state: st),
                    ],
                  ),
                ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) {
              if (i == _tab) return;
              setState(() => _tab = i);
              _tabAnim.forward(from: 0.3);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Transactions'),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_basket_outlined), label: 'Bazar'),
              BottomNavigationBarItem(icon: Icon(Icons.account_balance_outlined), label: 'Accounts'),
              BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Entity>(
      color: kCard,
      onSelected: state.switchEntity,
      itemBuilder: (context) => state.entities
          .map((e) => PopupMenuItem(
                value: e,
                child: Row(
                  children: [
                    Icon(
                      e.id == state.currentEntity?.id ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: e.id == state.currentEntity?.id ? kCyan : kFg24,
                    ),
                    const SizedBox(width: 8),
                    Text('${e.name} (${e.type})'),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: kFg.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kFg.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.work_outline, size: 14, color: kCyan),
            const SizedBox(width: 6),
            Text(state.currentEntity?.name ?? '—', style: const TextStyle(fontSize: 13)),
            Icon(Icons.arrow_drop_down, size: 18, color: kFg54),
          ],
        ),
      ),
    );
  }
}
