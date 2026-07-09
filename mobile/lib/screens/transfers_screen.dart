import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key, required this.state});
  final AppState state;

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  List<Transfer>? _transfers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await widget.state.fetchTransfers();
    if (mounted) setState(() => _transfers = t);
  }

  Future<void> _newTransfer() async {
    final accounts = widget.state.accounts;
    if (accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least two accounts to transfer.')),
      );
      return;
    }
    String? fromId;
    String? toId;
    final amount = TextEditingController();
    final notes = TextEditingController();
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
                const Text('New Transfer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'From account'),
                  items: accounts
                      .map((a) => DropdownMenuItem(
                          value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                      .toList(),
                  onChanged: (v) => setSheet(() => fromId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'To account'),
                  items: accounts
                      .where((a) => a.id != fromId)
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setSheet(() => toId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Transfer',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (fromId == null || toId == null || amt == null || amt <= 0) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.addTransfer(
                        fromAccountId: fromId!,
                        toAccountId: toId!,
                        amount: amt,
                        date: DateTime.now(),
                        notes: notes.text.trim(),
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext)
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final transfers = _transfers;
    return Scaffold(
      appBar: AppBar(title: const Text('Transfers', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _newTransfer,
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.swap_horiz),
      ),
      body: transfers == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : transfers.isEmpty
              ? Center(
                  child: Text('No transfers yet',
                      style: TextStyle(color: kFg.withValues(alpha: 0.35))),
                )
              : RefreshIndicator(
                  color: kCyan,
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: transfers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = transfers[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.swap_horiz, color: kCyan),
                          title: Text('${t.fromName} → ${t.toName}', style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${DateFormat('MMM d, yyyy').format(t.date)}'
                            '${t.notes.isNotEmpty ? ' • ${t.notes}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35)),
                          ),
                          trailing: Text(taka(t.amount),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kCyan)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
