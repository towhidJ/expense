import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _liabilityTypes = {
  'loan_taken': '🏦 Loan Taken',
  'loan_given': '🤝 Loan Given',
  'credit_card': '💳 Credit Card',
  'installment': '📆 Installment / EMI',
};

class LiabilitiesScreen extends StatefulWidget {
  const LiabilitiesScreen({super.key, required this.state});
  final AppState state;

  @override
  State<LiabilitiesScreen> createState() => _LiabilitiesScreenState();
}

class _LiabilitiesScreenState extends State<LiabilitiesScreen> {
  List<Liability>? _liabilities;
  List<Repayment> _repayments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (l, r) = await widget.state.fetchLiabilities();
    if (mounted) {
      setState(() {
        _liabilities = l;
        _repayments = r;
      });
    }
  }

  Future<void> _openAdd() async {
    final name = TextEditingController();
    final principal = TextEditingController();
    final interest = TextEditingController(text: '0');
    String type = 'loan_taken';
    String? accountId;
    DateTime? dueDate;

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
                const Text('New Liability / Loan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Loan from City Bank')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _liabilityTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setSheet(() => type = v ?? 'loan_taken'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: principal,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Principal Amount (৳)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: interest,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Interest Rate % (optional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: const InputDecoration(
                    labelText: 'Received into account (optional)',
                    helperText: 'If picked, the money is added to that account',
                    helperMaxLines: 2,
                  ),
                  items: widget.state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: dueDate ?? DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setSheet(() => dueDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Due Date (optional)'),
                    child: Text(dueDate == null ? '—' : DateFormat('MMM d, yyyy').format(dueDate!)),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Add Liability',
                  onPressed: () {
                    if (name.text.trim().isEmpty || double.tryParse(principal.text.trim()) == null) return;
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
      await widget.state.addLiability(
        name: name.text.trim(),
        type: type,
        principal: double.parse(principal.text.trim()),
        interestRate: double.tryParse(interest.text.trim()) ?? 0,
        dueDate: dueDate,
        accountId: accountId,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openRepay(Liability l) async {
    String? accountId;
    final amount = TextEditingController();
    DateTime date = DateTime.now();
    final isReceivable = l.isReceivable;

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
                Text(isReceivable ? 'Receive Payment — ${l.name}' : 'Repay — ${l.name}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Remaining: ${taka(l.remainingBalance)}',
                    style: TextStyle(fontSize: 12, color: kFg54)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: InputDecoration(labelText: isReceivable ? 'Receive into account' : 'Pay from account'),
                  items: widget.state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                      .toList(),
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('MMM d, yyyy').format(date)),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: isReceivable ? 'Record Received Payment' : 'Record Repayment',
                  onPressed: () {
                    final amt = double.tryParse(amount.text.trim());
                    if (accountId == null || amt == null || amt <= 0) return;
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
      await widget.state.repayLiability(
        liabilityId: l.id,
        accountId: accountId!,
        amount: double.parse(amount.text.trim()),
        date: date,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final liabilities = _liabilities;
    final debts = liabilities?.where((l) => !l.isReceivable).fold<double>(0, (s, l) => s + l.remainingBalance) ?? 0;
    final receivables = liabilities?.where((l) => l.isReceivable).fold<double>(0, (s, l) => s + l.remainingBalance) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Liabilities', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: liabilities == null
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
                          Text('You Owe', style: TextStyle(fontSize: 11, color: kFg38)),
                          Text(taka(debts), style: const TextStyle(fontWeight: FontWeight.bold, color: kRed, fontSize: 16)),
                        ]),
                        Column(children: [
                          Text('Owed to You', style: TextStyle(fontSize: 11, color: kFg38)),
                          Text(taka(receivables),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: kEmerald, fontSize: 16)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (liabilities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('🛡️  No liabilities', style: TextStyle(color: kFg.withValues(alpha: 0.35)))),
                  )
                else
                  ...liabilities.map((l) {
                    final paid = l.principal > 0 ? ((l.principal - l.remainingBalance) / l.principal).clamp(0.0, 1.0) : 0.0;
                    final settled = l.remainingBalance <= 0;
                    final color = l.isReceivable ? kEmerald : kRed;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(l.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                        Text(
                                          '${_liabilityTypes[l.type] ?? l.type}'
                                          '${l.dueDate != null ? ' • due ${DateFormat('MMM d, yyyy').format(l.dueDate!)}' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11, color: kFg38),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(taka(l.remainingBalance),
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                                      Text('remaining', style: TextStyle(fontSize: 10, color: kFg38)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: paid,
                                  minHeight: 6,
                                  backgroundColor: kFg.withValues(alpha: 0.06),
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text('${(paid * 100).toStringAsFixed(0)}% of ${taka(l.principal)} settled',
                                      style: TextStyle(fontSize: 11, color: kFg38)),
                                  const Spacer(),
                                  if (!settled)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: kCyan,
                                      ),
                                      onPressed: () => _openRepay(l),
                                      child: Text(l.isReceivable ? 'Receive' : 'Repay',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(Icons.delete_outline, size: 18, color: kFg38),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Delete "${l.name}"?'),
                                          content: const Text('Account balances are NOT adjusted when deleting.'),
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
                                        try {
                                          await widget.state.deleteLiability(l.id);
                                          _load();
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                content: Text(
                                                    'Cannot delete: it has repayment history. ($e)')));
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                if (_repayments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Recent Repayments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._repayments.take(10).map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Card(
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.payments_outlined, color: kCyan, size: 18),
                            title: Text(
                              '${taka(r.amount)}${r.accountName.isNotEmpty ? ' • ${r.accountName}' : ''}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Text(DateFormat('MMM d, yyyy').format(r.date),
                                style: TextStyle(fontSize: 11, color: kFg38)),
                          ),
                        ),
                      )),
                ],
              ],
            ),
    );
  }
}
