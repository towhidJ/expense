import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const savingTypes = {
  'general': '💰 General',
  'bank': '🏦 Bank Savings',
  'dps': '📆 DPS',
  'fdr': '📜 FDR',
  'cash': '💵 Cash',
  'other': '📦 Other',
};

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  List<Saving>? _savings;
  List<RecurringSaving> _recurring = [];
  List<SavingHead> _heads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.state.fetchSavings(),
      widget.state.fetchRecurringSavings(),
      widget.state.fetchSavingHeads(),
    ]);
    if (mounted) {
      setState(() {
        _savings = results[0] as List<Saving>;
        _recurring = results[1] as List<RecurringSaving>;
        _heads = results[2] as List<SavingHead>;
      });
    }
  }

  /// Net balance sitting in each head (deposits - withdrawals).
  Map<String, double> get _headBalances {
    final map = <String, double>{};
    for (final s in _savings ?? <Saving>[]) {
      if (s.headId == null) continue;
      map[s.headId!] = (map[s.headId!] ?? 0) + (s.type == 'deposit' ? s.amount : -s.amount);
    }
    return map;
  }

  Future<void> _openHeadForm({SavingHead? edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final institution = TextEditingController(text: edit?.institution ?? '');
    final accountNumber = TextEditingController(text: edit?.accountNumber ?? '');
    String savingType = edit?.savingType ?? 'dps';

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
                Text(edit == null ? 'New Savings Head' : 'Edit Savings Head',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Head Name', hintText: 'e.g. DBBL DPS, Home Cash')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: savingType,
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Saving Type'),
                  items: savingTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setSheet(() => savingType = v ?? 'dps'),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: institution,
                    decoration: const InputDecoration(labelText: 'Bank / Where', hintText: 'e.g. DBBL')),
                const SizedBox(height: 12),
                TextField(
                    controller: accountNumber,
                    decoration: const InputDecoration(
                        labelText: 'Account Number (optional)', hintText: 'DPS/FDR A/C no')),
                const SizedBox(height: 20),
                GradientButton(
                  label: edit == null ? 'Create Head' : 'Save',
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
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
      await widget.state.upsertSavingHead(
        id: edit?.id,
        name: name.text.trim(),
        savingType: savingType,
        institution: institution.text.trim(),
        accountNumber: accountNumber.text.trim(),
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openForm() async {
    String type = 'deposit';
    String savingType = 'general';
    String? accountId;
    String? headId;
    final amount = TextEditingController();
    final purpose = TextEditingController();
    final institution = TextEditingController();
    DateTime date = DateTime.now();

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
                const Text('New Savings Entry', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [('deposit', '⬆️ Deposit', kEmerald), ('withdraw', '⬇️ Withdraw', kRed)].map((t) {
                    final sel = type == t.$1;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: t.$1 == 'deposit' ? 8 : 0),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: sel ? t.$3.withValues(alpha: 0.15) : kFg.withValues(alpha: 0.04),
                            side: BorderSide(color: sel ? t.$3 : kFg12),
                            foregroundColor: sel ? t.$3 : kFg38,
                          ),
                          onPressed: () => setSheet(() => type = t.$1),
                          child: Text(t.$2),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: headId,
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Savings Head (where the money sits)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('No head (manual below)')),
                    ..._heads.map((h) => DropdownMenuItem<String?>(
                        value: h.id,
                        child: Text('${h.name}${h.institution.isNotEmpty ? ' — ${h.institution}' : ''}',
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setSheet(() => headId = v),
                ),
                if (headId == null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: savingType,
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Saving Type'),
                    items: savingTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setSheet(() => savingType = v ?? 'general'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: institution,
                    decoration: const InputDecoration(
                        labelText: 'Bank / Where', hintText: 'e.g. DBBL, Islami Bank, home locker'),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Account (optional — adjusts balance)'),
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
                TextField(controller: purpose, decoration: const InputDecoration(labelText: 'Purpose (optional)')),
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
                  label: 'Save',
                  onPressed: () {
                    final amt = double.tryParse(amount.text.trim());
                    if (amt == null || amt <= 0) return;
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
      // A picked head carries its type/institution over to the entry.
      final head = headId == null ? null : _heads.firstWhere((h) => h.id == headId);
      await widget.state.addSaving(
        accountId: accountId,
        type: type,
        amount: double.parse(amount.text.trim()),
        date: date,
        purpose: purpose.text.trim().isEmpty ? null : purpose.text.trim(),
        savingType: head?.savingType ?? savingType,
        institution: head != null
            ? (head.institution.isEmpty ? null : head.institution)
            : (institution.text.trim().isEmpty ? null : institution.text.trim()),
        headId: headId,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openRecurringForm() async {
    String savingType = 'dps';
    String frequency = 'monthly';
    String? accountId;
    String? headId;
    final title = TextEditingController();
    final amount = TextEditingController();
    final institution = TextEditingController();
    DateTime nextRun = DateTime.now();

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
                const Text('New Recurring Saving', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. DBBL DPS 5000')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: headId,
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Savings Head'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('No head (manual below)')),
                    ..._heads.map((h) => DropdownMenuItem<String?>(
                        value: h.id,
                        child: Text('${h.name}${h.institution.isNotEmpty ? ' — ${h.institution}' : ''}',
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setSheet(() => headId = v),
                ),
                if (headId == null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: savingType,
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Saving Type'),
                    items: savingTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setSheet(() => savingType = v ?? 'dps'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: institution,
                      decoration: const InputDecoration(labelText: 'Bank / Where', hintText: 'e.g. DBBL')),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount per period (৳)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: const InputDecoration(
                    labelText: 'Save from account (optional)',
                    helperText: 'Each run deducts the amount from this account',
                    helperMaxLines: 2,
                  ),
                  items: widget.state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: ['daily', 'weekly', 'monthly', 'yearly']
                      .map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1))))
                      .toList(),
                  onChanged: (v) => setSheet(() => frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: nextRun,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setSheet(() => nextRun = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'First Run Date'),
                    child: Text(DateFormat('MMM d, yyyy').format(nextRun)),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Add Recurring Saving',
                  onPressed: () {
                    final amt = double.tryParse(amount.text.trim());
                    if (title.text.trim().isEmpty || amt == null || amt <= 0) return;
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
      final head = headId == null ? null : _heads.firstWhere((h) => h.id == headId);
      await widget.state.addRecurringSaving(
        title: title.text.trim(),
        amount: double.parse(amount.text.trim()),
        frequency: frequency,
        nextRunDate: nextRun,
        accountId: accountId,
        savingType: head?.savingType ?? savingType,
        institution: head != null
            ? (head.institution.isEmpty ? null : head.institution)
            : (institution.text.trim().isEmpty ? null : institution.text.trim()),
        headId: headId,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _runDue(int dueCount) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Run $dueCount due recurring saving(s)?'),
        content: const Text('Overdue items catch up for every missed period.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Run')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final count = await widget.state.runDueRecurringSavings();
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count savings entry(ies) created.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final savings = _savings;
    final deposits = savings?.where((s) => s.type == 'deposit').fold<double>(0, (a, s) => a + s.amount) ?? 0;
    final withdrawals = savings?.where((s) => s.type == 'withdraw').fold<double>(0, (a, s) => a + s.amount) ?? 0;
    final now = DateTime.now();
    final dueCount = _recurring.where((r) => r.isActive && !r.nextRunDate.isAfter(now)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'New savings head',
            onPressed: () => _openHeadForm(),
            icon: const Icon(Icons.account_balance_outlined, color: kEmerald),
          ),
          IconButton(
            tooltip: 'New recurring saving',
            onPressed: _openRecurringForm,
            icon: const Icon(Icons.repeat, color: kCyan),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: savings == null
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
                          Text('Total Saved', style: TextStyle(fontSize: 11, color: kFg38)),
                          Text(taka(deposits - withdrawals),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: kCyan, fontSize: 16)),
                        ]),
                        Column(children: [
                          Text('Deposits', style: TextStyle(fontSize: 11, color: kFg38)),
                          Text(taka(deposits), style: const TextStyle(fontWeight: FontWeight.bold, color: kEmerald)),
                        ]),
                        Column(children: [
                          Text('Withdrawn', style: TextStyle(fontSize: 11, color: kFg38)),
                          Text(taka(withdrawals), style: const TextStyle(fontWeight: FontWeight.bold, color: kRed)),
                        ]),
                      ],
                    ),
                  ),
                ),
                if (dueCount > 0) ...[
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline, color: kOrange),
                      title: Text('$dueCount recurring saving(s) due',
                          style: const TextStyle(fontSize: 13.5, color: kOrange)),
                      trailing: TextButton(
                        onPressed: () => _runDue(dueCount),
                        child: const Text('Run Now', style: TextStyle(color: kOrange, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
                if (_heads.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Savings Heads', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._heads.map((h) {
                    final balance = _headBalances[h.id] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => _openHeadForm(edit: h),
                          leading: const Icon(Icons.account_balance_outlined, color: kEmerald, size: 20),
                          title: Text(h.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                          subtitle: Text(
                            '${savingTypes[h.savingType] ?? h.savingType}'
                            '${h.institution.isNotEmpty ? ' • ${h.institution}' : ''}'
                            '${h.accountNumber.isNotEmpty ? ' • A/C: ${h.accountNumber}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(taka(balance),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: balance >= 0 ? kEmerald : kRed)),
                              PopupMenuButton<String>(
                                color: kCard,
                                icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                                onSelected: (v) async {
                                  if (v == 'edit') _openHeadForm(edit: h);
                                  if (v == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Delete head "${h.name}"?'),
                                        content: const Text('Its entries stay; only the link is removed.'),
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
                                      await widget.state.deleteSavingHead(h.id);
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
                if (_recurring.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Recurring Savings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._recurring.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.repeat, color: kCyan, size: 20),
                            title: Text(r.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                            subtitle: Text(
                              '${r.headName.isNotEmpty ? '🏷️ ${r.headName}' : (savingTypes[r.savingType] ?? r.savingType)}'
                              '${r.institution.isNotEmpty ? ' • ${r.institution}' : ''}'
                              ' • ${r.frequency} • next ${DateFormat('MMM d').format(r.nextRunDate)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(taka(r.amount),
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.bold, color: kEmerald)),
                                Switch(
                                  value: r.isActive,
                                  activeThumbColor: kCyan,
                                  onChanged: (v) async {
                                    await widget.state.setRecurringSavingActive(r.id, v);
                                    _load();
                                  },
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.delete_outline, size: 18, color: kFg38),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Delete "${r.title}"?'),
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
                                      await widget.state.deleteRecurringSaving(r.id);
                                      _load();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                ],
                const SizedBox(height: 16),
                const Text('History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (savings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Center(
                        child: Text('🐖  No savings entries yet',
                            style: TextStyle(color: kFg.withValues(alpha: 0.35)))),
                  )
                else
                  ...savings.map((s) {
                    final isDeposit = s.type == 'deposit';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: Icon(isDeposit ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isDeposit ? kEmerald : kRed, size: 20),
                          title: Text(s.purpose.isEmpty ? (isDeposit ? 'Deposit' : 'Withdrawal') : s.purpose,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${s.headName.isNotEmpty ? '🏷️ ${s.headName}' : (savingTypes[s.savingType] ?? s.savingType)}'
                            '${s.institution.isNotEmpty ? ' • ${s.institution}' : ''}'
                            ' • ${DateFormat('MMM d, yyyy').format(s.date)}'
                            '${s.accountName.isNotEmpty ? ' • ${s.accountName}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${isDeposit ? '+' : '-'}${taka(s.amount)}',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDeposit ? kEmerald : kRed)),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.delete_outline, size: 18, color: kFg38),
                                onPressed: () async {
                                  try {
                                    await widget.state.deleteSaving(s.id);
                                    _load();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  }
                                },
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
