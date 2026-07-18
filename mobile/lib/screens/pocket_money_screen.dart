import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Kids' Pocket Money — mirrors web /pocket-money. No new ledger: payouts are
/// transactions with family_member_id set; family_allowances stores only the
/// optional monthly target per member.
class PocketMoneyScreen extends StatefulWidget {
  const PocketMoneyScreen({super.key, required this.state});
  final AppState state;

  @override
  State<PocketMoneyScreen> createState() => _PocketMoneyScreenState();
}

class _PocketMoneyScreenState extends State<PocketMoneyScreen> {
  List<FamilyMember>? _members;
  List<Tx> _txs = [];
  List<Map<String, dynamic>> _allowances = [];
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.state.fetchFamilyMembers(),
        widget.state.fetchTransactions(type: 'expense'),
        widget.state.entityRows('family_allowances'),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<FamilyMember>;
        _txs = (results[1] as List<Tx>).where((t) => t.familyMemberId != null).toList();
        _allowances = results[2] as List<Map<String, dynamic>>;
        if (_members!.isNotEmpty && (_activeId == null || !_members!.any((m) => m.id == _activeId))) {
          _activeId = _members!.first.id;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _members = []);
    }
  }

  List<Tx> get _memberTxs => _txs.where((t) => t.familyMemberId == _activeId).toList();

  Map<String, dynamic>? get _allowance =>
      _allowances.where((a) => a['family_member_id'] == _activeId).firstOrNull;

  Future<void> _setTarget() async {
    final a = _allowance;
    final ctl = TextEditingController(
        text: a?['monthly_target'] == null ? '' : (a!['monthly_target'] as num).toStringAsFixed(0));
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Monthly target', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Target (৳/month)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    try {
      final target = ctl.text.trim().isEmpty ? null : double.tryParse(ctl.text.trim());
      if (a != null) {
        await widget.state.updateEntityRow('family_allowances', a['id'], {'monthly_target': target});
      } else if (target != null) {
        await widget.state
            .insertEntityRow('family_allowances', {'family_member_id': _activeId, 'monthly_target': target});
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _give() async {
    final member = _members!.firstWhere((m) => m.id == _activeId);
    final amount = TextEditingController();
    final notes = TextEditingController();
    String? accountId;
    String? categoryId;
    DateTime date = DateTime.now();
    bool busy = false;
    final expenseCats = widget.state.categories.where((c) => c.type == 'expense').toList();

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
                Text('Give Allowance — ${member.name}',
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
                  decoration: const InputDecoration(labelText: 'From account'),
                  items: widget.state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Expense category'),
                  items: expenseCats
                      .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                      .toList(),
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
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save',
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
                      await widget.state.addTransaction(
                        accountId: accountId!,
                        categoryId: categoryId!,
                        type: 'expense',
                        amount: amt,
                        date: date,
                        description: notes.text.trim().isEmpty
                            ? 'Allowance — ${member.name}'
                            : notes.text.trim(),
                        familyMemberId: member.id,
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
    final txs = _memberTxs;
    final now = DateTime.now();
    final thisMonth = txs
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .fold<double>(0, (s, t) => s + t.amount);
    final thisYear =
        txs.where((t) => t.date.year == now.year).fold<double>(0, (s, t) => s + t.amount);
    final target = (_allowance?['monthly_target'] as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Pocket Money', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: members == null || members.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _give,
              backgroundColor: kPurple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
      body: members == null
          ? const Center(child: CircularProgressIndicator(color: kPurple))
          : RefreshIndicator(
              color: kPurple,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  if (members.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('Add family members on the Family screen first.',
                              style: TextStyle(color: kFg38))),
                    )
                  else ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: members
                            .map((m) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(m.name, style: const TextStyle(fontSize: 12)),
                                    selected: _activeId == m.id,
                                    selectedColor: kPurple.withValues(alpha: 0.2),
                                    onSelected: (_) => setState(() => _activeId = m.id),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _stat('This Month', taka(thisMonth), kPurple)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: InkWell(
                              onTap: _setTarget,
                              child: _stat('Target ✎', target == null ? 'Not set' : taka(target), kOrange))),
                      const SizedBox(width: 10),
                      Expanded(child: _stat('This Year', taka(thisYear), kCyan)),
                    ]),
                    if (target != null && thisMonth > target) ...[
                      const SizedBox(height: 8),
                      Text('⚠️ Over the monthly target by ${taka(thisMonth - target)}',
                          style: const TextStyle(fontSize: 12, color: kOrange)),
                    ],
                    const SizedBox(height: 12),
                    if (txs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                            child:
                                Text('No allowance logged yet — tap +.', style: TextStyle(color: kFg38))),
                      ),
                    ...txs.map((t) => Card(
                          child: ListTile(
                            leading: const Text('💰', style: TextStyle(fontSize: 20)),
                            title: Text(t.description.isEmpty ? 'Allowance' : t.description,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(DateFormat('MMM d, yyyy').format(t.date),
                                style: TextStyle(fontSize: 11.5, color: kFg38)),
                            trailing: Text(taka(t.amount),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ),
                        )),
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
