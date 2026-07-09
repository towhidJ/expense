import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'transactions_screen.dart' show TxTile;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Tx>? _monthTxs;
  String? _entityId;
  double _assetsValue = 0;
  double _investmentsValue = 0;
  double _liabilitiesValue = 0; // debts minus receivables

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final results = await Future.wait([
      widget.state.fetchTransactions(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      ),
      widget.state.fetchAssets(),
      widget.state.fetchInvestments(),
      widget.state.fetchLiabilities(),
    ]);
    if (mounted) {
      final assets = results[1] as List<Asset>;
      final investments = results[2] as List<Investment>;
      final (liabilities, _) = results[3] as (List<Liability>, List<Repayment>);
      setState(() {
        _monthTxs = results[0] as List<Tx>;
        _assetsValue = assets.fold(0, (s, a) => s + a.currentValue);
        _investmentsValue = investments.fold(0, (s, i) => s + i.currentValue);
        _liabilitiesValue = liabilities.fold(
            0, (s, l) => s + (l.isReceivable ? -l.remainingBalance : l.remainingBalance));
        _entityId = widget.state.currentEntity?.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reload when the workspace switches under us.
    if (_entityId != null && _entityId != widget.state.currentEntity?.id) {
      _monthTxs = null;
      _load();
    }
    final st = widget.state;
    final txs = _monthTxs;
    final cash = st.accounts.fold<double>(0, (s, a) => s + a.currentBalance);
    final income = txs?.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount) ?? 0;
    final expense = txs?.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount) ?? 0;
    final savingsRate = income > 0 ? ((income - expense) / income * 100) : 0.0;
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    return RefreshIndicator(
      color: kCyan,
      onRefresh: () async {
        await st.refreshAccounts();
        await _load();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(
            title: 'Net Worth',
            value: taka(cash + _assetsValue + _investmentsValue - _liabilitiesValue),
            icon: Icons.workspace_premium_outlined,
            color: kPurple,
            subtitle: 'Cash + assets + investments − liabilities',
          ),
          const SizedBox(height: 12),
          _StatCard(
            title: 'Cash Position',
            value: taka(cash),
            icon: Icons.account_balance,
            color: kCyan,
            subtitle: '${st.accounts.length} accounts • ${st.currentEntity?.name ?? ''} workspace',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Income',
                  value: taka(income),
                  icon: Icons.trending_up,
                  color: kEmerald,
                  subtitle: monthLabel,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Expenses',
                  value: taka(expense),
                  icon: Icons.trending_down,
                  color: kRed,
                  subtitle: monthLabel,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(
            title: 'Savings Rate (Month)',
            value: '${savingsRate.toStringAsFixed(1)}%',
            icon: Icons.savings_outlined,
            color: kPurple,
            subtitle: 'Net ${taka(income - expense)}',
          ),
          const SizedBox(height: 24),
          const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (txs == null)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator(color: kCyan)),
            )
          else if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: Text('No transactions this month',
                    style: TextStyle(color: kFg.withValues(alpha: 0.3))),
              ),
            )
          else
            ...txs.take(8).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TxTile(tx: t),
                )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.compact = false,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: kFg.withValues(alpha: 0.4))),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value,
                        style: TextStyle(
                            fontSize: compact ? 18 : 22, fontWeight: FontWeight.bold, color: color)),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.3))),
                  ],
                ],
              ),
            ),
            if (!compact)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}
