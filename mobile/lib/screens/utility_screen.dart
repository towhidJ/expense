import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const utilityTypes = {
  'electricity': ('⚡', 'Electricity', 'kWh'),
  'gas': ('🔥', 'Gas', 'unit'),
  'water': ('💧', 'Water', 'unit'),
  'internet': ('🌐', 'Internet', ''),
  'phone': ('📱', 'Phone', ''),
  'tv': ('📺', 'TV', ''),
  'other': ('📋', 'Other', ''),
};

class UtilityScreen extends StatefulWidget {
  const UtilityScreen({super.key, required this.state});
  final AppState state;

  @override
  State<UtilityScreen> createState() => _UtilityScreenState();
}

class _UtilityScreenState extends State<UtilityScreen> {
  List<UtilityBill>? _bills;
  List<Recurring> _recurring = [];
  String _activeType = 'electricity';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.state.fetchUtilityBills(),
      widget.state.fetchRecurring(),
    ]);
    if (mounted) {
      setState(() {
        _bills = results[0] as List<UtilityBill>;
        _recurring = results[1] as List<Recurring>;
      });
    }
  }

  Future<void> _addBill() async {
    final meta = utilityTypes[_activeType]!;
    final amount = TextEditingController();
    final units = TextEditingController();
    final notes = TextEditingController();
    DateTime billMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
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
                Text('New ${meta.$2} Bill', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Bill month', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(DateFormat('MMMM yyyy').format(billMonth), style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: billMonth,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setSheet(() => billMonth = DateTime(picked.year, picked.month, 1));
                  },
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: units,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Units${meta.$3.isNotEmpty ? ' (${meta.$3})' : ''} — optional'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Due date (optional)', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(dueDate == null ? 'Not set' : DateFormat('MMM d, yyyy').format(dueDate!),
                      style: TextStyle(fontSize: 13, color: dueDate == null ? kFg38 : kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setSheet(() => dueDate = picked);
                  },
                ),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Bill',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (amt == null || amt <= 0) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.addUtilityBill(
                        type: _activeType,
                        billMonth: billMonth,
                        units: double.tryParse(units.text.trim()),
                        amount: amt,
                        dueDate: dueDate,
                        notes: notes.text.trim(),
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                            content: Text(e.toString().contains('23505')
                                ? 'A bill for this month already exists.'
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

  Future<void> _payBill(UtilityBill bill) async {
    final accounts = widget.state.accounts;
    final categories = widget.state.categories.where((c) => c.type == 'expense').toList();
    String? accountId;
    String? categoryId;
    DateTime date = DateTime.now();
    bool busy = false;
    final meta = utilityTypes[bill.type] ?? utilityTypes['other']!;

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
                const Text('Pay Bill', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${meta.$1} ${meta.$2} — ${DateFormat('MMMM yyyy').format(bill.billMonth)} · ${taka(bill.amount)}',
                  style: TextStyle(fontSize: 13, color: kFg54),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Pay from account'),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                      .toList(),
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Expense category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                      .toList(),
                  onChanged: (v) => setSheet(() => categoryId = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Payment date', style: TextStyle(fontSize: 13, color: kFg54)),
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
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Confirm Payment',
                  busy: busy,
                  onPressed: () async {
                    if (accountId == null || categoryId == null) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.payUtilityBill(
                        bill: bill,
                        accountId: accountId!,
                        categoryId: categoryId!,
                        date: date,
                        description:
                            '${meta.$2} bill — ${DateFormat('MMMM yyyy').format(bill.billMonth)}',
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
    final bills = _bills;
    final typeBills = (bills ?? []).where((b) => b.type == _activeType).toList()
      ..sort((a, b) => b.billMonth.compareTo(a.billMonth));
    final unpaid = (bills ?? []).where((b) => !b.isPaid).fold<double>(0, (s, b) => s + b.amount);
    Recurring? linked;
    for (final r in _recurring) {
      if (r.isActive && r.type == 'expense' && r.utilityType == _activeType) {
        linked = r;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Utility Bills', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBill,
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: bills == null
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : RefreshIndicator(
              color: kOrange,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  if (unpaid > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('Unpaid total: ${taka(unpaid)}',
                          style: TextStyle(fontSize: 13, color: kOrange, fontWeight: FontWeight.w600)),
                    ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: utilityTypes.entries.map((e) {
                        final selected = _activeType == e.key;
                        final count = (bills).where((b) => b.type == e.key).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${e.value.$1} ${e.value.$2}${count > 0 ? ' ($count)' : ''}'),
                            selected: selected,
                            selectedColor: kOrange.withValues(alpha: 0.2),
                            labelStyle: TextStyle(fontSize: 12, color: selected ? kOrange : kFg54),
                            onSelected: (_) => setState(() => _activeType = e.key),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, size: 16, color: linked != null ? kEmerald : kFg24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              linked != null
                                  ? 'Auto-pay: "${linked.title}" (${taka(linked.amount)}/${linked.frequency.replaceAll('ly', '')}) posts the payment and marks each month PAID. Next: ${DateFormat('MMM d').format(linked.nextRunDate)}.'
                                  : 'Fixed monthly bill? Tag a recurring expense with this utility type on the Recurring page — bills then appear here as PAID automatically.',
                              style: TextStyle(fontSize: 11.5, color: linked != null ? kFg70 : kFg38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (typeBills.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                          child: Text('No ${utilityTypes[_activeType]!.$2.toLowerCase()} bills yet.',
                              style: TextStyle(color: kFg38))),
                    ),
                  ...typeBills.map((b) {
                    final overdue = !b.isPaid && b.dueDate != null && b.dueDate!.isBefore(DateTime.now());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          title: Text(DateFormat('MMMM yyyy').format(b.billMonth), style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${b.units != null ? '${b.units} ${utilityTypes[b.type]!.$3} · ' : ''}'
                            '${b.isPaid ? 'PAID' : overdue ? 'OVERDUE' : b.dueDate != null ? 'due ${DateFormat('MMM d').format(b.dueDate!)}' : 'unpaid'}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: b.isPaid || overdue ? FontWeight.w600 : FontWeight.normal,
                                color: b.isPaid ? kEmerald : overdue ? kRed : kOrange),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(taka(b.amount),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              PopupMenuButton<String>(
                                color: kCard,
                                icon: Icon(Icons.more_vert, color: kFg38, size: 20),
                                onSelected: (v) async {
                                  if (v == 'pay') _payBill(b);
                                  if (v == 'delete') {
                                    try {
                                      await widget.state.deleteUtilityBill(b.id);
                                      _load();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (!b.isPaid) const PopupMenuItem(value: 'pay', child: Text('Pay now')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
            ),
    );
  }
}
