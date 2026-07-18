import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../theme.dart';

/// Committee / Samity (rotating savings) tracker — mirrors web /committee.
/// Deposits post as expenses, the payout as income, via process_transaction.
class CommitteeScreen extends StatefulWidget {
  const CommitteeScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CommitteeScreen> createState() => _CommitteeScreenState();
}

class _CommitteeScreenState extends State<CommitteeScreen> {
  List<Map<String, dynamic>>? _committees;
  List<Map<String, dynamic>> _payments = [];
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.state.entityRows('committees'),
        widget.state.entityRows('committee_payments'),
      ]);
      if (!mounted) return;
      setState(() {
        _committees = results[0];
        _payments = results[1];
        if (_committees!.isNotEmpty &&
            (_activeId == null || !_committees!.any((c) => c['id'] == _activeId))) {
          _activeId = _committees!.first['id'];
        }
      });
    } catch (_) {
      if (mounted) setState(() => _committees = []);
    }
  }

  Map<String, dynamic>? get _active =>
      (_committees ?? []).where((c) => c['id'] == _activeId).firstOrNull;

  List<String> _months(Map<String, dynamic> c) {
    final start = DateTime.parse(c['start_date']);
    final count = (c['total_members'] as int?) ??
        ((DateTime.now().year - start.year) * 12 + DateTime.now().month - start.month + 1);
    return List.generate(count < 1 ? 1 : count, (i) {
      final d = DateTime(start.year, start.month + i, 1);
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-01';
    });
  }

  Future<void> _addCommittee() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final members = TextEditingController();
    DateTime start = DateTime.now();
    DateTime? turnMonth;
    bool busy = false;

    final saved = await showModalBottomSheet<bool>(
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
                const Text('New Committee', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (e.g. Office Samity)')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Monthly amount (৳)'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: members,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Total members'))),
                ]),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Start month', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(DateFormat('MMM yyyy').format(start), style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: start,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => start = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Your payout month', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(turnMonth == null ? 'Not set' : DateFormat('MMM yyyy').format(turnMonth!),
                      style: TextStyle(fontSize: 13, color: turnMonth == null ? kFg38 : kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: turnMonth ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => turnMonth = picked);
                  },
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: 'Save Committee',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (name.text.trim().isEmpty || amt == null || amt <= 0) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.insertEntityRow('committees', {
                        'name': name.text.trim(),
                        'monthly_amount': amt,
                        'total_members': int.tryParse(members.text.trim()),
                        'start_date':
                            '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-01',
                        'your_turn_month': turnMonth == null
                            ? null
                            : '${turnMonth!.year.toString().padLeft(4, '0')}-${turnMonth!.month.toString().padLeft(2, '0')}-01',
                      });
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _recordPayment(String month, String entryType) async {
    final c = _active!;
    final amount = TextEditingController(
        text: entryType == 'deposit' ? ((c['monthly_amount'] as num?)?.toStringAsFixed(0) ?? '') : '');
    String? accountId;
    String? categoryId;
    DateTime date = DateTime.now();
    bool busy = false;
    final isDeposit = entryType == 'deposit';
    final cats = widget.state.categories.where((x) => x.type == (isDeposit ? 'expense' : 'income')).toList();

    final saved = await showModalBottomSheet<bool>(
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
                Text('${isDeposit ? 'Deposit' : 'Payout'} — ${DateFormat('MMMM yyyy').format(DateTime.parse(month))}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (৳)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: accountId,
                  decoration: InputDecoration(labelText: isDeposit ? 'Pay from account' : 'Deposit to account'),
                  items: widget.state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: cats.map((x) => DropdownMenuItem(value: x.id, child: Text('${x.icon} ${x.name}'))).toList(),
                  onChanged: (v) => setSheet(() => categoryId = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(DateFormat('MMM d, yyyy').format(date), style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: 'Confirm',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (amt == null || amt <= 0 || accountId == null || categoryId == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Amount, account and category are required.')));
                      return;
                    }
                    setSheet(() => busy = true);
                    try {
                      final txId = await widget.state.processTransactionId(
                        accountId: accountId!,
                        categoryId: categoryId!,
                        type: isDeposit ? 'expense' : 'income',
                        amount: amt,
                        date: date,
                        description:
                            '${c['name']} — ${isDeposit ? 'monthly deposit' : 'payout'} (${DateFormat('MMMM yyyy').format(DateTime.parse(month))})',
                      );
                      await widget.state.insertEntityRow('committee_payments', {
                        'committee_id': c['id'],
                        'pay_month': month,
                        'amount': amt,
                        'entry_type': entryType,
                        'transaction_id': txId,
                      });
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                            content: Text(e.toString().contains('duplicate')
                                ? 'Already recorded for this month.'
                                : 'Error: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final committees = _committees;
    final c = _active;
    final payments = _payments.where((p) => p['committee_id'] == _activeId).toList();
    final deposited = _payments
        .where((p) => p['entry_type'] == 'deposit')
        .fold<double>(0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0));
    final received = _payments
        .where((p) => p['entry_type'] == 'payout')
        .fold<double>(0, (s, p) => s + ((p['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Committee / Samity', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCommittee,
        backgroundColor: kPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: committees == null
          ? const Center(child: CircularProgressIndicator(color: kPurple))
          : RefreshIndicator(
              color: kPurple,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  if (committees.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No committees yet — tap + to add a samity.',
                              style: TextStyle(color: kFg38))),
                    )
                  else ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: committees
                            .map((x) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text('👥 ${x['name']}', style: const TextStyle(fontSize: 12)),
                                    selected: _activeId == x['id'],
                                    selectedColor: kPurple.withValues(alpha: 0.2),
                                    onSelected: (_) => setState(() => _activeId = x['id']),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _stat('Deposited', taka(deposited), kPurple)),
                      const SizedBox(width: 10),
                      Expanded(child: _stat('Received', taka(received), kEmerald)),
                      const SizedBox(width: 10),
                      Expanded(child: _stat('Net', taka(received - deposited), kCyan)),
                    ]),
                    const SizedBox(height: 12),
                    if (c != null)
                      ..._months(c).map((m) {
                        final deposit = payments
                            .where((p) => p['pay_month'] == m && p['entry_type'] == 'deposit')
                            .firstOrNull;
                        final payout = payments
                            .where((p) => p['pay_month'] == m && p['entry_type'] == 'payout')
                            .firstOrNull;
                        final isTurn = c['your_turn_month'] == m;
                        return Card(
                          child: ListTile(
                            title: Row(children: [
                              Text(DateFormat('MMMM yyyy').format(DateTime.parse(m)),
                                  style: const TextStyle(fontSize: 13.5)),
                              if (isTurn) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: kOrange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: const Text('YOUR TURN',
                                      style: TextStyle(fontSize: 8.5, color: kOrange, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ]),
                            subtitle: Text(
                              deposit != null
                                  ? '✓ Deposited ${taka((deposit['amount'] as num?) ?? 0)}'
                                  : 'Deposit pending',
                              style: TextStyle(
                                  fontSize: 11.5, color: deposit != null ? kEmerald : kFg38),
                            ),
                            trailing: deposit == null
                                ? TextButton(
                                    onPressed: () => _recordPayment(m, 'deposit'),
                                    child: const Text('Pay', style: TextStyle(fontSize: 12.5, color: kPurple)))
                                : isTurn && payout == null
                                    ? TextButton(
                                        onPressed: () => _recordPayment(m, 'payout'),
                                        child: const Text('Payout',
                                            style: TextStyle(fontSize: 12.5, color: kEmerald)))
                                    : payout != null
                                        ? Text('✓ ${taka((payout['amount'] as num?) ?? 0)}',
                                            style: const TextStyle(fontSize: 12, color: kEmerald))
                                        : null,
                          ),
                        );
                      }),
                    if (c != null)
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Delete committee?'),
                                content: const Text('All its payment records go too. Linked transactions stay.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(dialogContext, true),
                                      child: const Text('Delete', style: TextStyle(color: kRed))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              try {
                                await widget.state.deleteEntityRow('committees', c['id']);
                                setState(() => _activeId = null);
                                _load();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                          },
                          child: Text('Delete this committee',
                              style: TextStyle(fontSize: 12, color: kRed.withValues(alpha: 0.7))),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: kFg38)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
