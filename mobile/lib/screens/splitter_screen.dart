import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _pink = Color(0xFFEC4899);

/// Greedy settlement: minimal-ish "X pays Y" list from net balances
/// (ported verbatim from the web Splitter page).
List<SettleMove> settle(List<({String name, double net})> balances) {
  final debtors = balances.where((b) => b.net < -0.01).map((b) => [b.name, -b.net]).toList()
    ..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
  final creditors = balances.where((b) => b.net > 0.01).map((b) => [b.name, b.net]).toList()
    ..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
  final moves = <SettleMove>[];
  var i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final pay = (debtors[i][1] as double) < (creditors[j][1] as double)
        ? debtors[i][1] as double
        : creditors[j][1] as double;
    moves.add(SettleMove(debtors[i][0] as String, creditors[j][0] as String, pay));
    debtors[i][1] = (debtors[i][1] as double) - pay;
    creditors[j][1] = (creditors[j][1] as double) - pay;
    if ((debtors[i][1] as double) < 0.01) i++;
    if ((creditors[j][1] as double) < 0.01) j++;
  }
  return moves;
}

class SplitterScreen extends StatefulWidget {
  const SplitterScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SplitterScreen> createState() => _SplitterScreenState();
}

class _SplitterScreenState extends State<SplitterScreen> {
  List<SplitEvent>? _events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.state.fetchSplitEvents();
    if (mounted) setState(() => _events = rows);
  }

  Future<void> _createEvent() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Event'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(hintText: "e.g. Cox's Bazar Trip"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final event = await widget.state.addSplitEvent(name.text.trim());
      await _load();
      if (mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => _SplitDetailScreen(state: widget.state, event: event)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    return Scaffold(
      appBar: AppBar(title: const Text('Bill Splitter', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEvent,
        backgroundColor: _pink,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: events == null
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : events.isEmpty
              ? Center(
                  child: Text('Trips, dinners, picnics —\nsplit fairly, settle with the fewest payments.',
                      textAlign: TextAlign.center, style: TextStyle(color: kFg38)))
              : RefreshIndicator(
                  color: _pink,
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = events[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.groups_outlined, color: _pink),
                          title: Text(e.name, style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chevron_right, color: kFg24),
                              PopupMenuButton<String>(
                                color: kCard,
                                icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                                onSelected: (v) async {
                                  if (v == 'delete') {
                                    await widget.state.deleteSplitEvent(e.id);
                                    _load();
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kRed))),
                                ],
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(context,
                                MaterialPageRoute(builder: (_) => _SplitDetailScreen(state: widget.state, event: e)));
                            _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _SplitDetailScreen extends StatefulWidget {
  const _SplitDetailScreen({required this.state, required this.event});
  final AppState state;
  final SplitEvent event;

  @override
  State<_SplitDetailScreen> createState() => _SplitDetailScreenState();
}

class _SplitDetailScreenState extends State<_SplitDetailScreen> {
  List<SplitMember>? _members;
  List<SplitExpense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (members, expenses) = await widget.state.fetchSplitDetail(widget.event.id);
    if (mounted) {
      setState(() {
        _members = members;
        _expenses = expenses;
      });
    }
  }

  List<({String id, String name, double paid, double share, double net})> get _balances {
    final members = _members ?? [];
    final map = {
      for (final m in members) m.id: (name: m.name, paid: 0.0, share: 0.0),
    };
    final paid = <String, double>{};
    final share = <String, double>{};
    for (final exp in _expenses) {
      paid[exp.payerMemberId] = (paid[exp.payerMemberId] ?? 0) + exp.amount;
      final sharers = (exp.participantIds.isNotEmpty ? exp.participantIds : map.keys.toList())
          .where(map.containsKey)
          .toList();
      if (sharers.isEmpty) continue;
      final each = exp.amount / sharers.length;
      for (final id in sharers) {
        share[id] = (share[id] ?? 0) + each;
      }
    }
    return members
        .map((m) => (
              id: m.id,
              name: m.name,
              paid: paid[m.id] ?? 0,
              share: share[m.id] ?? 0,
              net: (paid[m.id] ?? 0) - (share[m.id] ?? 0),
            ))
        .toList();
  }

  Future<void> _addMember() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(hintText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await widget.state.addSplitMember(widget.event.id, name.text.trim(), isMe: (_members ?? []).isEmpty);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addExpense() async {
    final members = _members ?? [];
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add members first.')));
      return;
    }
    final desc = TextEditingController();
    final amount = TextEditingController();
    String? payerId = members.first.id;
    final participants = <String>{};
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
                const Text('Add Expense', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Hotel bill')),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: payerId,
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                  onChanged: (v) => setSheet(() => payerId = v),
                ),
                const SizedBox(height: 12),
                Text('Shared by (none selected = everyone)', style: TextStyle(fontSize: 12.5, color: kFg54)),
                Wrap(
                  spacing: 6,
                  children: members.map((m) {
                    final sel = participants.contains(m.id);
                    return FilterChip(
                      label: Text(m.name, style: TextStyle(fontSize: 12, color: sel ? _pink : kFg54)),
                      selected: sel,
                      selectedColor: _pink.withValues(alpha: 0.18),
                      onSelected: (v) => setSheet(() => v ? participants.add(m.id) : participants.remove(m.id)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Add Expense',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (desc.text.trim().isEmpty || amt == null || amt <= 0 || payerId == null) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.addSplitExpense(
                        eventId: widget.event.id,
                        payerMemberId: payerId!,
                        description: desc.text.trim(),
                        amount: amt,
                        participantIds: participants.toList(),
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
    final members = _members;
    final balances = _balances;
    final moves = settle(balances.map((b) => (name: b.name, net: b.net)).toList());
    final total = _expenses.fold<double>(0, (s, e) => s + e.amount);
    final memberNames = {for (final m in members ?? <SplitMember>[]) m.id: m.name};

    return Scaffold(
      appBar: AppBar(title: Text(widget.event.name, style: const TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        backgroundColor: _pink,
        foregroundColor: Colors.white,
        child: const Icon(Icons.receipt_long_outlined),
      ),
      body: members == null
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : RefreshIndicator(
              color: _pink,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total spent: ${taka(total)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: _addMember,
                        icon: const Icon(Icons.person_add_alt, size: 16, color: _pink),
                        label: const Text('Member', style: TextStyle(fontSize: 12, color: _pink)),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: balances
                        .map((b) => Chip(
                              backgroundColor: (b.net > 0.01
                                      ? kEmerald
                                      : b.net < -0.01
                                          ? kRed
                                          : kFg24)
                                  .withValues(alpha: 0.12),
                              label: Text(
                                '${b.name}: ${b.net >= 0 ? '+' : '−'}${taka(b.net.abs())}',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: b.net > 0.01 ? kEmerald : b.net < -0.01 ? kRed : kFg54),
                              ),
                              deleteIcon: Icon(Icons.close, size: 13, color: kFg24),
                              onDeleted: () async {
                                await widget.state.deleteSplitRow('split_members', b.id);
                                _load();
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  if (moves.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Settle up 💸',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _pink)),
                            const SizedBox(height: 8),
                            ...moves.map((m) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: Text('${m.from}  →  ${m.to}',
                                              style: const TextStyle(fontSize: 13))),
                                      Text(taka(m.amount),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text('Expenses', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kFg54)),
                  const SizedBox(height: 6),
                  if (_expenses.isEmpty)
                    Text('No expenses yet — add who paid for what.', style: TextStyle(fontSize: 12, color: kFg38)),
                  ..._expenses.map((e) => Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text(e.description, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            'paid by ${memberNames[e.payerMemberId] ?? '?'}'
                            '${e.participantIds.isNotEmpty ? ' · shared by ${e.participantIds.map((id) => memberNames[id] ?? '?').join(', ')}' : ' · everyone'}',
                            style: TextStyle(fontSize: 11, color: kFg38),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(taka(e.amount),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 17, color: kRed),
                                onPressed: () async {
                                  await widget.state.deleteSplitRow('split_expenses', e.id);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}
