import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _invTypes = {
  'stocks': '📊 Stocks',
  'mutual_funds': '📁 Mutual Funds',
  'fdr': '🏦 FDR',
  'dps': '💳 DPS',
  'crypto': '🪙 Crypto',
};

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  List<Investment>? _investments;
  final Map<String, List<InvestmentContribution>> _contributions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inv = await widget.state.fetchInvestments();
    if (mounted) setState(() => _investments = inv);
  }

  double? _xirrFor(Investment inv) {
    final rows = _contributions[inv.id];
    if (rows == null || rows.length < 2) return null;
    return calculateXIRR(inv.currentValue, rows);
  }

  Future<void> _openHistory(Investment inv) async {
    var rows = _contributions[inv.id] ?? await widget.state.fetchInvestmentContributions(inv.id);
    _contributions[inv.id] = rows;
    if (!mounted) return;
    setState(() {});

    final amount = TextEditingController();
    var type = 'contribution';
    var pickedDate = DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${inv.name} — Contribution History', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('At least 2 entries give an accurate XIRR; until then the CAGR estimate is used.',
                    style: TextStyle(fontSize: 11, color: kFg38)),
                const SizedBox(height: 12),
                ...rows.map((c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${c.date.day}/${c.date.month}/${c.date.year}', style: const TextStyle(fontSize: 13)),
                      subtitle: Text(c.type, style: TextStyle(fontSize: 11, color: kFg38)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '${c.type == 'withdrawal' ? '−' : '+'}${taka(c.amount)}',
                          style: TextStyle(color: c.type == 'withdrawal' ? kOrange : kEmerald, fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 15, color: kFg24),
                          onPressed: () async {
                            await widget.state.deleteInvestmentContribution(c.id);
                            rows = await widget.state.fetchInvestmentContributions(inv.id);
                            _contributions[inv.id] = rows;
                            setSheet(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                      ]),
                    )),
                if (rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('No contributions logged yet.', style: TextStyle(fontSize: 12, color: kFg38))),
                const Divider(),
                Row(children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${pickedDate.day}/${pickedDate.month}/${pickedDate.year}', style: const TextStyle(fontSize: 13)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext, initialDate: pickedDate,
                          firstDate: DateTime(2000), lastDate: DateTime.now(),
                        );
                        if (picked != null) setSheet(() => pickedDate = picked);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: type,
                      dropdownColor: kCard,
                      items: const [
                        DropdownMenuItem(value: 'contribution', child: Text('Contribution')),
                        DropdownMenuItem(value: 'withdrawal', child: Text('Withdrawal')),
                      ],
                      onChanged: (v) => setSheet(() => type = v ?? 'contribution'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kCyan),
                    onPressed: () async {
                      final amt = double.tryParse(amount.text.trim());
                      if (amt == null || amt <= 0) return;
                      await widget.state.addInvestmentContribution(inv.id, date: pickedDate, amount: amt, type: type);
                      amount.clear();
                      rows = await widget.state.fetchInvestmentContributions(inv.id);
                      _contributions[inv.id] = rows;
                      setSheet(() {});
                      if (mounted) setState(() {});
                    },
                    child: const Text('Add'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForm({Investment? edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final invested = TextEditingController(text: edit == null ? '' : edit.investedAmount.toString());
    final current = TextEditingController(text: edit == null ? '' : edit.currentValue.toString());
    String type = edit?.type ?? 'stocks';
    DateTime purchaseDate = edit?.purchaseDate ?? DateTime.now();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(edit == null ? 'New Investment' : 'Edit Investment',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. GP Shares')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _invTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setSheet(() => type = v ?? 'stocks'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: invested,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Invested Amount (৳)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: current,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Current Value (৳)'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 18, color: kCyan),
                  title: const Text('Purchase Date', style: TextStyle(fontSize: 13.5)),
                  subtitle: Text('${purchaseDate.day}/${purchaseDate.month}/${purchaseDate.year}',
                      style: TextStyle(fontSize: 12, color: kFg38)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: purchaseDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => purchaseDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: edit == null ? 'Add Investment' : 'Save',
                  onPressed: () {
                    if (name.text.trim().isEmpty ||
                        double.tryParse(invested.text.trim()) == null ||
                        double.tryParse(current.text.trim()) == null) {
                      return;
                    }
                    Navigator.pop(sheetContext, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await widget.state.upsertInvestment(
        id: edit?.id,
        name: name.text.trim(),
        type: type,
        investedAmount: double.parse(invested.text.trim()),
        currentValue: double.parse(current.text.trim()),
        purchaseDate: purchaseDate,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final invs = _investments;
    final invested = invs?.fold<double>(0, (s, i) => s + i.investedAmount) ?? 0;
    final current = invs?.fold<double>(0, (s, i) => s + i.currentValue) ?? 0;
    final pl = current - invested;

    return Scaffold(
      appBar: AppBar(title: const Text('Investments', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: invs == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [
                          Text('Invested', style: TextStyle(fontSize: 11, color: kFg38)),
                          Text(taka(invested), style: const TextStyle(fontWeight: FontWeight.bold, color: kCyan)),
                        ]),
                        Column(children: [
                          Text('Current', style: TextStyle(fontSize: 11, color: kFg38)),
                          Text(taka(current), style: const TextStyle(fontWeight: FontWeight.bold, color: kPurple)),
                        ]),
                        Column(children: [
                          Text('P/L', style: TextStyle(fontSize: 11, color: kFg38)),
                          Text('${pl >= 0 ? '+' : ''}${taka(pl)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: pl >= 0 ? kEmerald : kRed)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (invs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('📈  No investments yet', style: TextStyle(color: kFg.withValues(alpha: 0.35)))),
                  )
                else
                  ...invs.map((inv) {
                    final up = inv.profitLoss >= 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => _openForm(edit: inv),
                          leading: Icon(up ? Icons.trending_up : Icons.trending_down, color: up ? kEmerald : kRed),
                          title: Text(inv.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(_invTypes[inv.type] ?? inv.type,
                              style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35))),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(taka(inv.currentValue),
                                      style: const TextStyle(
                                          fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text('${up ? '+' : ''}${taka(inv.profitLoss)} (${inv.roi}%)',
                                      style: TextStyle(fontSize: 11, color: up ? kEmerald : kRed)),
                                  Builder(builder: (_) {
                                    final xirr = _xirrFor(inv);
                                    final ret = xirr ?? inv.cagr;
                                    if (ret == null) return const SizedBox.shrink();
                                    return Text(
                                      '${xirr != null ? 'XIRR' : 'CAGR'} ${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(1)}%'
                                      '${xirr == null && inv.type == 'dps' ? ' ~' : ''}',
                                      style: TextStyle(fontSize: 10, color: kFg38),
                                    );
                                  }),
                                ],
                              ),
                              IconButton(
                                icon: Icon(Icons.history, size: 18, color: kFg38),
                                tooltip: 'Contribution history',
                                onPressed: () => _openHistory(inv),
                              ),
                              PopupMenuButton<String>(
                                color: kCard,
                                icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                                onSelected: (v) async {
                                  if (v == 'edit') _openForm(edit: inv);
                                  if (v == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Delete "${inv.name}"?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel')),
                                          TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Delete', style: TextStyle(color: kRed))),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await widget.state.deleteInvestment(inv.id);
                                      _load();
                                    }
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
