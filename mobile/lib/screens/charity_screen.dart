import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../theme.dart';

const _charityCats = {
  'zakat': ('☪️', 'Zakat'),
  'sadaqah': ('🤲', 'Sadaqah'),
  'other': ('❤️', 'Other'),
};

/// Charity / Sadaqah donation ledger — mirrors web /charity. Every donation
/// posts a real expense via process_transaction and links its transaction_id.
class CharityScreen extends StatefulWidget {
  const CharityScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CharityScreen> createState() => _CharityScreenState();
}

class _CharityScreenState extends State<CharityScreen> {
  List<Map<String, dynamic>>? _donations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.state.entityRows('charity_donations', orderBy: 'date');
      if (mounted) setState(() => _donations = rows);
    } catch (_) {
      if (mounted) setState(() => _donations = []);
    }
  }

  Future<void> _add() async {
    final recipient = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();
    String category = 'sadaqah';
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
                const Text('Log Donation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                    controller: recipient,
                    decoration: const InputDecoration(labelText: 'Recipient (e.g. Local Madrasa)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _charityCats.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value.$1} ${e.value.$2}')))
                      .toList(),
                  onChanged: (v) => setSheet(() => category = v ?? 'sadaqah'),
                ),
                const SizedBox(height: 12),
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
                  trailing:
                      Text(DateFormat('MMM d, yyyy').format(date), style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Donation',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (recipient.text.trim().isEmpty ||
                        amt == null ||
                        amt <= 0 ||
                        accountId == null ||
                        categoryId == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(
                          content: Text('Recipient, amount, account and category are required.')));
                      return;
                    }
                    setSheet(() => busy = true);
                    try {
                      final txId = await widget.state.processTransactionId(
                        accountId: accountId!,
                        categoryId: categoryId!,
                        type: 'expense',
                        amount: amt,
                        date: date,
                        description: '${_charityCats[category]!.$2} — ${recipient.text.trim()}',
                      );
                      await widget.state.insertEntityRow('charity_donations', {
                        'recipient': recipient.text.trim(),
                        'category': category,
                        'amount': amt,
                        'date':
                            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        'account_id': accountId,
                        'transaction_id': txId,
                        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final donations = _donations;
    final year = DateTime.now().year;
    final yearRows =
        (donations ?? []).where((d) => DateTime.parse(d['date']).year == year).toList();
    final yearTotal = yearRows.fold<double>(0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));
    final zakatTotal = yearRows
        .where((d) => d['category'] == 'zakat')
        .fold<double>(0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Charity / Sadaqah', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: kEmerald,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: donations == null
          ? const Center(child: CircularProgressIndicator(color: kEmerald))
          : RefreshIndicator(
              color: kEmerald,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Row(children: [
                    Expanded(child: _stat('This Year', taka(yearTotal), kEmerald)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Zakat Paid', taka(zakatTotal), kPurple)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Sadaqah/Other', taka(yearTotal - zakatTotal), kCyan)),
                  ]),
                  const SizedBox(height: 12),
                  if (donations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No donations logged yet — tap +.', style: TextStyle(color: kFg38))),
                    ),
                  ...donations.map((d) {
                    final meta = _charityCats[d['category']] ?? _charityCats['other']!;
                    return Card(
                      child: ListTile(
                        leading: Text(meta.$1, style: const TextStyle(fontSize: 20)),
                        title: Text(d['recipient'] ?? '', style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          '${meta.$2} · ${DateFormat('MMM d, yyyy').format(DateTime.parse(d['date']))}'
                          '${(d['notes'] ?? '').toString().isNotEmpty ? ' · ${d['notes']}' : ''}',
                          style: TextStyle(fontSize: 11.5, color: kFg38),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(taka((d['amount'] as num?) ?? 0),
                                style: const TextStyle(
                                    fontSize: 13.5, fontWeight: FontWeight.w600, color: kEmerald)),
                            PopupMenuButton<String>(
                              color: kCard,
                              icon: Icon(Icons.more_vert, color: kFg38, size: 20),
                              onSelected: (v) async {
                                if (v == 'delete') {
                                  try {
                                    await widget.state.deleteEntityRow('charity_donations', d['id']);
                                    _load();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'delete', child: Text('Delete (transaction stays)')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
