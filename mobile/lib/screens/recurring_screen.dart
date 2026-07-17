import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _frequencies = ['daily', 'weekly', 'monthly', 'yearly'];

const _utilityLabels = {
  'electricity': '⚡ Electricity',
  'gas': '🔥 Gas',
  'water': '💧 Water',
  'internet': '🌐 Internet',
  'phone': '📱 Phone',
  'tv': '📺 TV',
  'other': '📋 Other',
};

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key, required this.state});
  final AppState state;

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<Recurring>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.state.fetchRecurring();
    if (mounted) setState(() => _items = r);
  }

  Future<void> _openForm({Recurring? edit}) async {
    final title = TextEditingController(text: edit?.title ?? '');
    final amount = TextEditingController(text: edit == null ? '' : edit.amount.toString());
    String type = edit?.type ?? 'expense';
    String? categoryId = edit?.categoryId;
    String? accountId = edit?.accountId;
    String frequency = edit?.frequency ?? 'monthly';
    DateTime nextRun = edit?.nextRunDate ?? DateTime.now().add(const Duration(days: 1));
    bool isSubscription = edit?.isSubscription ?? false;
    String? utilityType = edit?.utilityType;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final cats = widget.state.categories.where((c) => c.type == type).toList();
          if (categoryId != null && !cats.any((c) => c.id == categoryId)) categoryId = null;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(edit == null ? 'New Recurring Transaction' : 'Edit Recurring',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    children: ['expense', 'income'].map((t) {
                      final sel = type == t;
                      final color = t == 'expense' ? kRed : kEmerald;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: t == 'expense' ? 8 : 0),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: sel ? color.withValues(alpha: 0.15) : kFg.withValues(alpha: 0.04),
                              side: BorderSide(color: sel ? color : kFg12),
                              foregroundColor: sel ? color : kFg38,
                            ),
                            onPressed: () => setSheet(() => type = t),
                            child: Text(t == 'expense' ? '💸 Expense' : '💰 Income'),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. House Rent')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}'))).toList(),
                    onChanged: (v) => setSheet(() => categoryId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: widget.state.accounts.any((a) => a.id == accountId) ? accountId : null,
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: widget.state.accounts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
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
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: _frequencies
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
                      decoration: const InputDecoration(labelText: 'Next Run Date'),
                      child: Text(DateFormat('MMM d, yyyy').format(nextRun)),
                    ),
                  ),
                  if (type == 'expense') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: utilityType,
                      dropdownColor: kCard,
                      decoration: const InputDecoration(
                        labelText: 'Utility bill (optional)',
                        helperText: 'Each auto-run records that month\'s bill as PAID on the Utility screen.',
                        helperMaxLines: 2,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Not a utility bill')),
                        ..._utilityLabels.entries
                            .map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
                      ],
                      onChanged: (v) => setSheet(() => utilityType = v),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Subscription (show on Subscriptions screen)',
                          style: TextStyle(fontSize: 13)),
                      value: isSubscription,
                      activeColor: kCyan,
                      onChanged: (v) => setSheet(() => isSubscription = v ?? false),
                    ),
                  ],
                  const SizedBox(height: 12),
                  GradientButton(
                    label: edit == null ? 'Add Recurring' : 'Save',
                    onPressed: () {
                      if (title.text.trim().isEmpty ||
                          categoryId == null ||
                          accountId == null ||
                          double.tryParse(amount.text.trim()) == null) {
                        return;
                      }
                      Navigator.pop(sheetContext, true);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      await widget.state.upsertRecurring(
        id: edit?.id,
        title: title.text.trim(),
        type: type,
        categoryId: categoryId!,
        accountId: accountId!,
        amount: double.parse(amount.text.trim()),
        frequency: frequency,
        nextRunDate: nextRun,
        isActive: edit?.isActive ?? true,
        isSubscription: isSubscription,
        utilityType: utilityType,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final dueCount = (items ?? []).where((r) => r.isActive && !r.nextRunDate.isAfter(DateTime.now())).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (dueCount > 0)
            TextButton.icon(
              onPressed: () async {
                try {
                  final n = await widget.state.runDueRecurring();
                  _load();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$n transaction(s) posted.')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              icon: const Icon(Icons.bolt, size: 18, color: kEmerald),
              label: Text('Run $dueCount due', style: const TextStyle(color: kEmerald, fontSize: 13)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : items.isEmpty
              ? Center(child: Text('🔁  No recurring transactions', style: TextStyle(color: kFg.withValues(alpha: 0.35))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = items[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _openForm(edit: r),
                        leading: Text(r.categoryIcon, style: const TextStyle(fontSize: 20)),
                        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          '${r.frequency} • next ${DateFormat('MMM d').format(r.nextRunDate)} • ${r.accountName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${r.type == 'income' ? '+' : '-'}${taka(r.amount)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: r.type == 'income' ? kEmerald : kRed),
                            ),
                            Switch(
                              value: r.isActive,
                              activeThumbColor: kCyan,
                              onChanged: (v) async {
                                await widget.state.setRecurringActive(r.id, v);
                                _load();
                              },
                            ),
                            PopupMenuButton<String>(
                              color: kCard,
                              icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                              onSelected: (v) async {
                                if (v == 'edit') _openForm(edit: r);
                                if (v == 'delete') {
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
                                    await widget.state.deleteRecurring(r.id);
                                    _load();
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                                PopupMenuItem(value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
