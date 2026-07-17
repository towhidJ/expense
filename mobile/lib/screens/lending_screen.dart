import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Dena-Paona: person-to-person lending ledger (liabilities with counterparty,
/// v34). Money moves through process_new_loan / process_loan_repayment.
class LendingScreen extends StatefulWidget {
  const LendingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<LendingScreen> createState() => _LendingScreenState();
}

class _PersonLedger {
  _PersonLedger(this.name);
  final String name;
  String? phone;
  final loans = <Liability>[];
  final repayments = <(Repayment, String)>[]; // (repayment, loan type)
  double receivable = 0;
  double payable = 0;
  double get net => receivable - payable;
}

class _LendingScreenState extends State<LendingScreen> {
  List<Liability>? _loans;
  List<Repayment> _repayments = [];
  bool _showSettled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (loans, reps) = await widget.state.fetchLending();
    if (mounted) {
      setState(() {
        _loans = loans;
        _repayments = reps;
      });
    }
  }

  List<_PersonLedger> get _people {
    final map = <String, _PersonLedger>{};
    for (final loan in _loans ?? <Liability>[]) {
      final key = (loan.counterparty ?? loan.name).trim().toLowerCase();
      final p = map.putIfAbsent(key, () => _PersonLedger(loan.counterparty ?? loan.name));
      p.loans.add(loan);
      if (p.phone == null && loan.phone.isNotEmpty) p.phone = loan.phone;
      if (loan.type == 'loan_given') {
        p.receivable += loan.remainingBalance;
      } else {
        p.payable += loan.remainingBalance;
      }
    }
    final loanIndex = {for (final l in _loans ?? <Liability>[]) l.id: l};
    for (final rep in _repayments) {
      final loan = loanIndex[rep.liabilityId];
      if (loan == null) continue;
      final key = (loan.counterparty ?? loan.name).trim().toLowerCase();
      map[key]?.repayments.add((rep, loan.type));
    }
    final list = map.values.toList()
      ..sort((a, b) => b.net.abs().compareTo(a.net.abs()));
    return list;
  }

  Future<void> _addLoan({String? person, String? phone}) async {
    final personCtl = TextEditingController(text: person ?? '');
    final phoneCtl = TextEditingController(text: phone ?? '');
    final amount = TextEditingController();
    final notes = TextEditingController();
    String direction = 'given';
    bool fromAccount = true;
    String? accountId;
    DateTime? dueDate;
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
                const Text('New Loan Entry', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ('given', '↗️ Ami Dilam (I lent)', kEmerald),
                    ('taken', '↘️ Ami Nilam (I borrowed)', kRed),
                  ].map((d) {
                    final sel = direction == d.$1;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: d.$1 == 'given' ? 8 : 0),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: sel ? d.$3.withValues(alpha: 0.15) : kFg.withValues(alpha: 0.04),
                            side: BorderSide(color: sel ? d.$3 : kFg12),
                            foregroundColor: sel ? d.$3 : kFg38,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => setSheet(() => direction = d.$1),
                          child: Text(d.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(controller: personCtl, decoration: const InputDecoration(labelText: 'Person name', hintText: 'e.g. Rahim Bhai')),
                const SizedBox(height: 12),
                TextField(controller: phoneCtl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Return date (optional)', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(dueDate == null ? 'Not set' : DateFormat('MMM d, yyyy').format(dueDate!),
                      style: TextStyle(fontSize: 13, color: dueDate == null ? kFg38 : kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setSheet(() => dueDate = picked);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    fromAccount
                        ? (direction == 'given' ? 'Paid from an account' : 'Received into an account')
                        : 'Past / opening balance (ledger only)',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  subtitle: Text(
                    fromAccount
                        ? 'Account balance will ${direction == 'given' ? 'decrease' : 'increase'}.'
                        : 'No account balance changes — for dena-paona from before the app.',
                    style: TextStyle(fontSize: 11, color: kFg38),
                  ),
                  value: fromAccount,
                  activeThumbColor: kCyan,
                  onChanged: (v) => setSheet(() => fromAccount = v),
                ),
                if (fromAccount)
                  DropdownButtonFormField<String>(
                    dropdownColor: kCard,
                    decoration: InputDecoration(
                        labelText: direction == 'given' ? 'Pay from account' : 'Deposit to account'),
                    items: widget.state.accounts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                        .toList(),
                    onChanged: (v) => setSheet(() => accountId = v),
                  ),
                const SizedBox(height: 12),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes', hintText: 'e.g. will return after Eid')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Loan',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (personCtl.text.trim().isEmpty || amt == null || amt <= 0) return;
                    if (fromAccount && accountId == null) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.addPersonLoan(
                        direction: direction,
                        person: personCtl.text.trim(),
                        phone: phoneCtl.text.trim(),
                        amount: amt,
                        accountId: fromAccount ? accountId : null,
                        dueDate: dueDate,
                        notes: notes.text.trim(),
                      );
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

  Future<void> _settle(Liability loan) async {
    final isGiven = loan.type == 'loan_given';
    final amount = TextEditingController(text: loan.remainingBalance.toStringAsFixed(0));
    final notes = TextEditingController();
    String? accountId;
    DateTime date = DateTime.now();
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
                Text(isGiven ? 'Receive Money' : 'Repay Money',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${isGiven ? 'From' : 'To'}: ${loan.counterparty ?? loan.name} (remaining ${taka(loan.remainingBalance)})',
                  style: TextStyle(fontSize: 13, color: kFg54),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: InputDecoration(labelText: isGiven ? 'Deposit to account' : 'Pay from account'),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(DateFormat('MMM d, yyyy').format(date), style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Confirm',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (accountId == null || amt == null || amt <= 0 || amt > loan.remainingBalance) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.repayLiability(
                        liabilityId: loan.id,
                        accountId: accountId!,
                        amount: amt,
                        date: date,
                        notes: notes.text.trim(),
                      );
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

  @override
  Widget build(BuildContext context) {
    final loans = _loans;
    final people = _people;
    final visible = people.where((p) => _showSettled || p.receivable > 0 || p.payable > 0).toList();
    final receivable = people.fold<double>(0, (s, p) => s + p.receivable);
    final payable = people.fold<double>(0, (s, p) => s + p.payable);
    final net = receivable - payable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dena-Paona', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showSettled = !_showSettled),
            child: Text(_showSettled ? 'Hide settled' : 'Show settled',
                style: TextStyle(fontSize: 12, color: kFg54)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addLoan(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: loans == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : RefreshIndicator(
              color: kCyan,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Row(children: [
                    Expanded(child: _stat("Paona (you'll get)", taka(receivable), kEmerald)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Dena (you owe)', taka(payable), kRed)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Net', '${net >= 0 ? '+' : '−'}${taka(net.abs())}', net >= 0 ? kCyan : kRed)),
                  ]),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No dena-paona recorded.\nTrack money you lent to or borrowed from people.',
                              textAlign: TextAlign.center, style: TextStyle(color: kFg38))),
                    ),
                  ...visible.map((p) => _personCard(p)),
                ],
              ),
            ),
    );
  }

  Widget _personCard(_PersonLedger p) {
    final shownLoans = _showSettled ? p.loans : p.loans.where((l) => l.remainingBalance > 0).toList();
    final hiddenSettled = p.loans.where((l) => l.remainingBalance <= 0).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: kCyan.withValues(alpha: 0.18),
                    child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                        style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        if (p.phone != null)
                          Text(p.phone!, style: TextStyle(fontSize: 11, color: kCyan.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  if (p.net != 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(taka(p.net.abs()),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: p.net > 0 ? kEmerald : kRed)),
                        Text(p.net > 0 ? 'you will receive' : 'you owe',
                            style: TextStyle(fontSize: 10, color: kFg38)),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('✓ SETTLED',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kEmerald)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...shownLoans.map((loan) {
                final isPaid = loan.remainingBalance <= 0;
                final isGiven = loan.type == 'loan_given';
                final overdue = !isPaid && loan.dueDate != null && loan.dueDate!.isBefore(DateTime.now());
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: kFg.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(isGiven ? Icons.call_made : Icons.call_received,
                            size: 15, color: isGiven ? kEmerald : kRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${isGiven ? 'Gave' : 'Took'} ${taka(loan.principal)}'
                                '${!isPaid && loan.remainingBalance != loan.principal ? ' · ${taka(loan.remainingBalance)} left' : ''}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              Text(
                                '${DateFormat('MMM d, yy').format(loan.createdAt.toLocal())}'
                                '${loan.dueDate != null ? ' · return ${DateFormat('MMM d').format(loan.dueDate!)}${overdue ? ' (overdue!)' : ''}' : ''}'
                                '${loan.notes.isNotEmpty ? ' · ${loan.notes}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, color: overdue ? kRed : kFg38),
                              ),
                            ],
                          ),
                        ),
                        if (isPaid)
                          const Text('PAID',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kEmerald))
                        else
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: (isGiven ? kEmerald : kRed).withValues(alpha: 0.12),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              minimumSize: const Size(0, 30),
                            ),
                            onPressed: () => _settle(loan),
                            child: Text(isGiven ? 'Receive' : 'Repay',
                                style: TextStyle(fontSize: 11, color: isGiven ? kEmerald : kRed)),
                          ),
                        PopupMenuButton<String>(
                          color: kCard,
                          icon: Icon(Icons.more_vert, size: 16, color: kFg24),
                          onSelected: (v) async {
                            if (v == 'delete') {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete this loan of ${taka(loan.principal)}?'),
                                  content: const Text(
                                      'Its repayment history is removed too. Account balances will NOT be reversed.',
                                      style: TextStyle(fontSize: 13)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete', style: TextStyle(color: kRed))),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                try {
                                  await widget.state.deleteLiability(loan.id);
                                  _load();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text('Cannot delete: $e')));
                                  }
                                }
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kRed))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (!_showSettled && hiddenSettled > 0)
                Text('+ $hiddenSettled settled loan${hiddenSettled > 1 ? 's' : ''} hidden',
                    style: TextStyle(fontSize: 10.5, color: kFg24)),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _addLoan(person: p.name, phone: p.phone),
                    icon: const Icon(Icons.add, size: 14, color: kCyan),
                    label: Text('New loan with ${p.name.split(' ').first}',
                        style: const TextStyle(fontSize: 11.5, color: kCyan)),
                  ),
                  const Spacer(),
                  if (p.repayments.isNotEmpty)
                    TextButton(
                      onPressed: () => _showHistory(p),
                      child: Text('History (${p.repayments.length})',
                          style: TextStyle(fontSize: 11.5, color: kFg38)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory(_PersonLedger p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Payment history — ${p.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...p.repayments.map((entry) {
            final (rep, loanType) = entry;
            final received = loanType == 'loan_given';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(received ? Icons.south_west : Icons.north_east,
                  size: 16, color: received ? kEmerald : kRed),
              title: Text(
                '${DateFormat('MMM d, yyyy').format(rep.date)} · ${received ? 'received' : 'paid'} via ${rep.accountName}',
                style: const TextStyle(fontSize: 12.5),
              ),
              subtitle: rep.notes.isNotEmpty ? Text(rep.notes, style: TextStyle(fontSize: 11, color: kFg38)) : null,
              trailing: Text(taka(rep.amount),
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: received ? kEmerald : kRed)),
            );
          }),
        ],
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
            Text(label, style: TextStyle(fontSize: 10, color: kFg38), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
