import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../theme.dart';

/// Snowball/avalanche payoff planner over existing liabilities — mirrors web
/// /debt-payoff. Reads liabilities directly (no new ledger); min payments are
/// stored on liabilities.min_payment (v41); actual payments happen on the
/// Liabilities screen via the repayment RPC.
class DebtPayoffScreen extends StatefulWidget {
  const DebtPayoffScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DebtPayoffScreen> createState() => _DebtPayoffScreenState();
}

class _SimDebt {
  _SimDebt(this.row) : balance = (row['remaining_balance'] as num?)?.toDouble() ?? 0;
  final Map<String, dynamic> row;
  double balance;
  int? paidOffMonth;
  String get id => row['id'];
  String get name => row['name'] ?? '';
  double get rate => (row['interest_rate'] as num?)?.toDouble() ?? 0;
  double get remaining => (row['remaining_balance'] as num?)?.toDouble() ?? 0;
  double? get minPayment => (row['min_payment'] as num?)?.toDouble();
  double get effectiveMin => minPayment ?? _fallbackMin(remaining);
}

double _fallbackMin(double balance) {
  final threePct = balance * 0.03;
  final twelfth = balance / 12;
  return threePct > twelfth ? threePct : twelfth;
}

class _SimResult {
  _SimResult(this.months, this.totalInterest, this.order);
  final int months;
  final double totalInterest;
  final List<_SimDebt> order;
}

_SimResult _simulate(List<Map<String, dynamic>> rows, String strategy, double extraMonthly) {
  final order = rows.map(_SimDebt.new).toList();
  if (strategy == 'snowball') {
    order.sort((a, b) => a.balance.compareTo(b.balance));
  } else {
    order.sort((a, b) => b.rate.compareTo(a.rate));
  }
  var month = 0;
  var totalInterest = 0.0;
  var freedMin = 0.0;
  while (order.any((d) => d.balance > 0.5) && month < 600) {
    month++;
    final pool = extraMonthly + freedMin;
    for (final d in order) {
      if (d.balance <= 0.5) continue;
      final interest = d.balance * (d.rate / 12 / 100);
      totalInterest += interest;
      var payment = d.effectiveMin;
      if (payment > d.balance + interest) payment = d.balance + interest;
      d.balance = d.balance + interest - payment;
      if (d.balance <= 0.5) {
        d.balance = 0;
        d.paidOffMonth = month;
        freedMin += payment;
      }
    }
    final target = order.where((d) => d.balance > 0.5).firstOrNull;
    if (target != null && pool > 0) {
      final applied = pool < target.balance ? pool : target.balance;
      target.balance -= applied;
      if (target.balance <= 0.5) {
        target.balance = 0;
        target.paidOffMonth = month;
        freedMin += target.minPayment ?? 0;
      }
    }
  }
  return _SimResult(month, totalInterest, order);
}

class _DebtPayoffScreenState extends State<DebtPayoffScreen> {
  List<Map<String, dynamic>>? _debts;
  String _strategy = 'avalanche';
  double _extra = 0;
  final _extraCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _strategy = prefs.getString('debt_payoff_strategy') ?? 'avalanche';
        _extra = prefs.getDouble('debt_payoff_extra') ?? 0;
        _extraCtl.text = _extra == 0 ? '' : _extra.toStringAsFixed(0);
      });
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.state.entityRows('liabilities');
      if (mounted) {
        setState(() => _debts = rows
            .where((r) =>
                r['counterparty'] == null &&
                r['type'] != 'loan_given' &&
                ((r['remaining_balance'] as num?)?.toDouble() ?? 0) > 0)
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _debts = []);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('debt_payoff_strategy', _strategy);
    await prefs.setDouble('debt_payoff_extra', _extra);
  }

  Future<void> _editMinPayment(Map<String, dynamic> debt) async {
    final ctl = TextEditingController(
        text: debt['min_payment'] == null ? '' : (debt['min_payment'] as num).toStringAsFixed(0));
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(debt['name'] ?? '', style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Minimum payment (৳/month)',
              helperText: 'Blank = ~3% of balance is assumed'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await widget.state.updateEntityRow('liabilities', debt['id'],
          {'min_payment': ctl.text.trim().isEmpty ? null : double.tryParse(ctl.text.trim())});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final debts = _debts;
    final baseline = debts != null && debts.isNotEmpty ? _simulate(debts, _strategy, 0) : null;
    final withExtra =
        debts != null && debts.isNotEmpty && _extra > 0 ? _simulate(debts, _strategy, _extra) : null;
    final shown = withExtra ?? baseline;
    final totalDebt =
        (debts ?? []).fold<double>(0, (s, d) => s + ((d['remaining_balance'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Debt Payoff', style: TextStyle(fontWeight: FontWeight.bold))),
      body: debts == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : RefreshIndicator(
              color: kCyan,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (debts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No active debts — loans with a remaining balance show up here.',
                              textAlign: TextAlign.center, style: TextStyle(color: kFg38))),
                    )
                  else ...[
                    Row(children: [
                      Expanded(child: _stat('Total Debt', taka(totalDebt), kRed)),
                      const SizedBox(width: 10),
                      Expanded(child: _stat('Debt-Free In', '${shown!.months} mo', kEmerald)),
                    ]),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('🔥 Avalanche', style: TextStyle(fontSize: 12)),
                                  selected: _strategy == 'avalanche',
                                  selectedColor: kRed.withValues(alpha: 0.2),
                                  onSelected: (_) => setState(() {
                                    _strategy = 'avalanche';
                                    _persist();
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Text('❄️ Snowball', style: TextStyle(fontSize: 12)),
                                  selected: _strategy == 'snowball',
                                  selectedColor: kCyan.withValues(alpha: 0.2),
                                  onSelected: (_) => setState(() {
                                    _strategy = 'snowball';
                                    _persist();
                                  }),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                                _strategy == 'avalanche'
                                    ? 'Highest interest rate first — least total interest.'
                                    : 'Smallest balance first — quick wins for motivation.',
                                style: TextStyle(fontSize: 11, color: kFg38)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _extraCtl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Extra payment per month (৳)'),
                              onChanged: (v) => setState(() {
                                _extra = double.tryParse(v) ?? 0;
                                _persist();
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (withExtra != null && baseline != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'With ${taka(_extra)}/month extra: debt-free in ${withExtra.months} months instead of '
                            '${baseline.months}, saving ${taka(baseline.totalInterest - withExtra.totalInterest)} in interest.',
                            style: const TextStyle(fontSize: 12.5, color: kEmerald, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('PAYOFF ORDER',
                        style: TextStyle(
                            fontSize: 11, letterSpacing: 1.2, color: kFg38, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...shown.order.asMap().entries.map((entry) {
                      final d = entry.value;
                      return Card(
                        child: ListTile(
                          leading: Text('#${entry.key + 1}',
                              style: TextStyle(fontSize: 13, color: kFg38, fontWeight: FontWeight.w600)),
                          title: Text(d.name, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${taka(d.remaining)} · ${d.rate}%/yr · min ${taka(d.effectiveMin)}'
                            '${d.minPayment == null ? ' (assumed)' : ''}',
                            style: TextStyle(fontSize: 11.5, color: kFg38),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(d.paidOffMonth == null ? '—' : 'Month ${d.paidOffMonth}',
                                  style: const TextStyle(
                                      fontSize: 12, color: kEmerald, fontWeight: FontWeight.w600)),
                              Text('paid off', style: TextStyle(fontSize: 10, color: kFg38)),
                            ],
                          ),
                          onTap: () => _editMinPayment(d.row),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    Text('Tap a debt to set its real minimum payment. Log actual payments on the Liabilities screen.',
                        style: TextStyle(fontSize: 11, color: kFg38)),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: kFg38)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
