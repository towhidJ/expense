import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Shared bills (v19): rent, wifi, gas — split equally or with custom
/// amounts, with per-member paid ticks. Standalone ledger; it does NOT feed
/// the meal month summary.
class MealSharedBillsScreen extends StatefulWidget {
  const MealSharedBillsScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealSharedBillsScreen> createState() => _MealSharedBillsScreenState();
}

class _MealSharedBillsScreenState extends State<MealSharedBillsScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  List<MealSharedExpense>? _bills;
  List<MealGroupMember> _members = [];
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    try {
      final start = DateTime(_year, _month, 1);
      final end = DateTime(_year, _month + 1, 1);
      final results = await Future.wait([
        state.fetchMealSharedExpenses(groupId, start, end),
        state.fetchMealMembers(groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _bills = results[0] as List<MealSharedExpense>;
        _members = results[1] as List<MealGroupMember>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _memberName(String memberId) {
    for (final m in _members) {
      if (m.id == memberId) return m.displayName;
    }
    return 'Member';
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _month = m;
      _year = y;
      _bills = null;
    });
    _load();
  }

  Future<void> _newBillSheet() async {
    final approved = _members.where((m) => m.status == 'approved').toList();
    final title = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    var date = DateTime.now();
    var splitType = 'equal';
    final included = {for (final m in approved) m.id: true};
    final custom = {for (final m in approved) m.id: TextEditingController()};

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
                const Text('New Shared Bill', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'Basha bhara — July'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Total amount (৳)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today, size: 18, color: kCyan),
                        title: Text('${date.day}/${date.month}',
                            style: const TextStyle(fontSize: 14)),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: date,
                            firstDate: DateTime(2023),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) setSheet(() => date = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Equal split'),
                        selected: splitType == 'equal',
                        selectedColor: kCyan.withValues(alpha: 0.2),
                        onSelected: (_) => setSheet(() => splitType = 'equal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Custom'),
                        selected: splitType == 'custom',
                        selectedColor: kPurple.withValues(alpha: 0.2),
                        onSelected: (_) => setSheet(() => splitType = 'custom'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(splitType == 'equal' ? 'Who shares this bill?' : 'Amount per member',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                ...approved.map((m) => splitType == 'equal'
                    ? CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: included[m.id],
                        activeColor: kCyan,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(m.displayName, style: const TextStyle(fontSize: 13.5)),
                        onChanged: (v) => setSheet(() => included[m.id] = v ?? false),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(m.displayName, style: const TextStyle(fontSize: 13.5))),
                            SizedBox(
                              width: 110,
                              child: TextField(
                                controller: custom[m.id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(hintText: '0', isDense: true),
                              ),
                            ),
                          ],
                        ),
                      )),
                const SizedBox(height: 8),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Save Bill',
                  onPressed: () {
                    if (title.text.trim().isNotEmpty && (double.tryParse(amount.text) ?? 0) > 0) {
                      Navigator.pop(sheetContext, true);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;

    final total = double.parse(amount.text);
    List<Map<String, dynamic>> shares;
    if (splitType == 'equal') {
      final ids = approved.where((m) => included[m.id] == true).map((m) => m.id).toList();
      if (ids.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Pick at least one member.')));
        }
        return;
      }
      // last member absorbs the rounding remainder so shares sum exactly
      final base = (total / ids.length * 100).floorToDouble() / 100;
      shares = [
        for (var i = 0; i < ids.length; i++)
          {
            'member_id': ids[i],
            'amount': i == ids.length - 1
                ? ((total - base * (ids.length - 1)) * 100).roundToDouble() / 100
                : base,
          }
      ];
    } else {
      shares = [
        for (final m in approved)
          if ((double.tryParse(custom[m.id]!.text) ?? 0) > 0)
            {'member_id': m.id, 'amount': double.parse(custom[m.id]!.text)}
      ];
    }

    await _run(() => state.createMealSharedExpense(
          groupId: groupId,
          title: title.text.trim(),
          amount: total,
          date: date,
          splitType: splitType,
          shares: shares,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final bills = _bills;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Bills', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () => _shiftMonth(-1), icon: Icon(Icons.chevron_left, color: kFg54)),
          Center(child: Text('$_month/$_year', style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(onPressed: () => _shiftMonth(1), icon: Icon(Icons.chevron_right, color: kFg54)),
        ],
      ),
      floatingActionButton: widget.isManager
          ? FloatingActionButton.extended(
              onPressed: _newBillSheet,
              backgroundColor: kCyan,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text('Bill', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: bills == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : bills.isEmpty
              ? Center(
                  child: Text('No shared bills this month', style: TextStyle(color: kFg38)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: bills.map((bill) {
                    final paidCount = bill.shares.where((s) => s.paid).length;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              dense: true,
                              leading: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: kPurple.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.receipt_long, size: 18, color: kPurple),
                              ),
                              title: Text(bill.title, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                '${bill.date.day}/${bill.date.month} · ${bill.splitType == 'equal' ? 'equal split' : 'custom split'}'
                                '${bill.note.isNotEmpty ? ' · ${bill.note}' : ''}',
                                style: TextStyle(fontSize: 11, color: kFg38),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(taka(bill.amount),
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('$paidCount/${bill.shares.length} paid',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: paidCount == bill.shares.length ? kEmerald : kOrange)),
                                ],
                              ),
                              onLongPress: widget.isManager
                                  ? () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          content: const Text('Delete this bill and its shares?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(dialogContext, true),
                                                child: const Text('Delete', style: TextStyle(color: kRed))),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await _run(() => state.deleteMealSharedExpense(bill.id));
                                      }
                                    }
                                  : null,
                            ),
                            Divider(height: 1, color: kFg.withValues(alpha: 0.06)),
                            ...bill.shares.map((s) => ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text(_memberName(s.memberId), style: const TextStyle(fontSize: 13)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(taka(s.shareAmount),
                                          style: TextStyle(fontSize: 12.5, color: kFg54)),
                                      const SizedBox(width: 8),
                                      widget.isManager
                                          ? Checkbox(
                                              value: s.paid,
                                              activeColor: kEmerald,
                                              onChanged: (v) =>
                                                  _run(() => state.toggleMealSharePaid(s.id, v ?? false)),
                                            )
                                          : Text(
                                              s.paid ? 'paid' : 'due',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: s.paid ? kEmerald : kOrange),
                                            ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
