import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../theme.dart';

const _statusMeta = {
  'draft': ('Draft', Colors.grey),
  'sent': ('Sent', kCyan),
  'paid': ('Paid', kEmerald),
  'overdue': ('Overdue', kRed),
  'cancelled': ('Cancelled', Colors.grey),
};

double _invoiceTotal(Map<String, dynamic> inv) =>
    ((inv['invoice_items'] as List?) ?? []).fold<double>(
        0,
        (s, it) =>
            s + ((it['quantity'] as num?)?.toDouble() ?? 0) * ((it['unit_price'] as num?)?.toDouble() ?? 0));

/// Client invoicing — mirrors web /invoicing (without the PDF export, which
/// stays web-side). Items are replaced wholesale on save; mark-paid posts
/// income via process_transaction.
class InvoicingScreen extends StatefulWidget {
  const InvoicingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<InvoicingScreen> createState() => _InvoicingScreenState();
}

class _InvoicingScreenState extends State<InvoicingScreen> {
  List<Map<String, dynamic>>? _invoices;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.state
          .entityRows('invoices', select: '*, invoice_items(*)', orderBy: 'issue_date');
      if (mounted) setState(() => _invoices = rows);
    } catch (_) {
      if (mounted) setState(() => _invoices = []);
    }
  }

  Future<void> _edit([Map<String, dynamic>? inv]) async {
    final number = TextEditingController(
        text: inv?['invoice_number'] ??
            'INV-${((_invoices?.length ?? 0) + 1).toString().padLeft(4, '0')}');
    final client = TextEditingController(text: inv?['client_name'] ?? '');
    final contact = TextEditingController(text: inv?['client_contact'] ?? '');
    final notes = TextEditingController(text: inv?['notes'] ?? '');
    DateTime issueDate =
        inv?['issue_date'] != null ? DateTime.parse(inv!['issue_date']) : DateTime.now();
    DateTime? dueDate = inv?['due_date'] != null ? DateTime.parse(inv!['due_date']) : null;
    final items = <(TextEditingController, TextEditingController, TextEditingController)>[];
    final existing = ((inv?['invoice_items'] as List?) ?? [])
      ..sort((a, b) => ((a['sort_order'] ?? 0) as num).compareTo((b['sort_order'] ?? 0) as num));
    for (final it in existing) {
      items.add((
        TextEditingController(text: it['description'] ?? ''),
        TextEditingController(text: '${it['quantity'] ?? 1}'),
        TextEditingController(text: '${it['unit_price'] ?? 0}'),
      ));
    }
    if (items.isEmpty) {
      items.add((TextEditingController(), TextEditingController(text: '1'), TextEditingController()));
    }
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
                Text(inv == null ? 'New Invoice' : 'Edit Invoice',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: number,
                          decoration: const InputDecoration(labelText: 'Invoice number'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: client, decoration: const InputDecoration(labelText: 'Client name'))),
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: contact,
                    decoration: const InputDecoration(labelText: 'Client contact (phone/email)')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Issue date', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(DateFormat('MMM d, yyyy').format(issueDate),
                      style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: issueDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => issueDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Due date', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(dueDate == null ? 'Not set' : DateFormat('MMM d, yyyy').format(dueDate!),
                      style: TextStyle(fontSize: 13, color: dueDate == null ? kFg38 : kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: dueDate ?? issueDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => dueDate = picked);
                  },
                ),
                const SizedBox(height: 4),
                Text('LINE ITEMS',
                    style: TextStyle(
                        fontSize: 11, letterSpacing: 1.2, color: kFg38, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...items.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                            flex: 3,
                            child: TextField(
                                controller: entry.value.$1,
                                decoration: const InputDecoration(labelText: 'Description', isDense: true))),
                        const SizedBox(width: 6),
                        Expanded(
                            child: TextField(
                                controller: entry.value.$2,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Qty', isDense: true))),
                        const SizedBox(width: 6),
                        Expanded(
                            flex: 2,
                            child: TextField(
                                controller: entry.value.$3,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Price', isDense: true))),
                        IconButton(
                          onPressed: items.length == 1
                              ? null
                              : () => setSheet(() => items.removeAt(entry.key)),
                          icon: Icon(Icons.close, size: 16, color: kFg38),
                        ),
                      ]),
                    )),
                TextButton(
                  onPressed: () => setSheet(() => items
                      .add((TextEditingController(), TextEditingController(text: '1'), TextEditingController()))),
                  child: const Text('+ Add line item', style: TextStyle(fontSize: 12.5, color: kCyan)),
                ),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Invoice',
                  busy: busy,
                  onPressed: () async {
                    if (number.text.trim().isEmpty || client.text.trim().isEmpty) return;
                    setSheet(() => busy = true);
                    try {
                      String invoiceId;
                      final payload = {
                        'invoice_number': number.text.trim(),
                        'client_name': client.text.trim(),
                        'client_contact': contact.text.trim().isEmpty ? null : contact.text.trim(),
                        'issue_date':
                            '${issueDate.year.toString().padLeft(4, '0')}-${issueDate.month.toString().padLeft(2, '0')}-${issueDate.day.toString().padLeft(2, '0')}',
                        'due_date': dueDate == null
                            ? null
                            : '${dueDate!.year.toString().padLeft(4, '0')}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                      };
                      if (inv == null) {
                        final created = await widget.state.insertEntityRow('invoices', payload);
                        invoiceId = created['id'];
                      } else {
                        invoiceId = inv['id'];
                        await widget.state.updateEntityRow('invoices', invoiceId, payload);
                        await supabase.from('invoice_items').delete().eq('invoice_id', invoiceId);
                      }
                      final rows = <Map<String, dynamic>>[];
                      for (final (i, it) in items.indexed) {
                        if (it.$1.text.trim().isEmpty) continue;
                        rows.add({
                          'invoice_id': invoiceId,
                          'description': it.$1.text.trim(),
                          'quantity': double.tryParse(it.$2.text.trim()) ?? 1,
                          'unit_price': double.tryParse(it.$3.text.trim()) ?? 0,
                          'sort_order': i,
                        });
                      }
                      if (rows.isNotEmpty) await supabase.from('invoice_items').insert(rows);
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
                            content: Text(e.toString().contains('duplicate')
                                ? 'This invoice number already exists.'
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

  Future<void> _markPaid(Map<String, dynamic> inv) async {
    String? accountId;
    String? categoryId;
    DateTime date = DateTime.now();
    bool busy = false;
    final incomeCats = widget.state.categories.where((c) => c.type == 'income').toList();
    final total = _invoiceTotal(inv);

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
                Text('Mark Paid — ${inv['invoice_number']} (${taka(total)})',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Deposit to account'),
                  items: widget.state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Income category'),
                  items: incomeCats
                      .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                      .toList(),
                  onChanged: (v) => setSheet(() => categoryId = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Payment date', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing:
                      Text(DateFormat('MMM d, yyyy').format(date), style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: 'Confirm Payment',
                  busy: busy,
                  onPressed: () async {
                    if (accountId == null || categoryId == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Account and category are required.')));
                      return;
                    }
                    setSheet(() => busy = true);
                    try {
                      final txId = await widget.state.processTransactionId(
                        accountId: accountId!,
                        categoryId: categoryId!,
                        type: 'income',
                        amount: total,
                        date: date,
                        description: 'Invoice ${inv['invoice_number']} — ${inv['client_name']}',
                      );
                      await widget.state.updateEntityRow('invoices', inv['id'],
                          {'status': 'paid', 'account_id': accountId, 'transaction_id': txId});
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
    final invoices = _invoices;
    final unpaid = (invoices ?? [])
        .where((i) => i['status'] != 'paid' && i['status'] != 'cancelled')
        .toList();
    final unpaidTotal = unpaid.fold<double>(0, (s, i) => s + _invoiceTotal(i));
    final year = DateTime.now().year;
    final paidThisYear = (invoices ?? [])
        .where((i) => i['status'] == 'paid' && DateTime.parse(i['issue_date']).year == year)
        .fold<double>(0, (s, i) => s + _invoiceTotal(i));

    return Scaffold(
      appBar: AppBar(title: const Text('Invoicing', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: invoices == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : RefreshIndicator(
              color: kCyan,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Row(children: [
                    Expanded(child: _stat('Outstanding', taka(unpaidTotal), kOrange)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Paid This Year', taka(paidThisYear), kEmerald)),
                  ]),
                  const SizedBox(height: 12),
                  if (invoices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No invoices yet — tap + to create one.',
                              style: TextStyle(color: kFg38))),
                    ),
                  ...invoices.map((inv) {
                    final meta = _statusMeta[inv['status']] ?? _statusMeta['draft']!;
                    return Card(
                      child: ListTile(
                        title: Text('${inv['invoice_number']} · ${inv['client_name']}',
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          '${taka(_invoiceTotal(inv))} · ${meta.$1} · issued ${DateFormat('MMM d').format(DateTime.parse(inv['issue_date']))}',
                          style: TextStyle(fontSize: 11.5, color: meta.$2),
                        ),
                        trailing: PopupMenuButton<String>(
                          color: kCard,
                          icon: Icon(Icons.more_vert, color: kFg38, size: 20),
                          onSelected: (v) async {
                            if (v == 'paid') _markPaid(inv);
                            if (v == 'edit') _edit(inv);
                            if (v == 'sent' || v == 'cancelled') {
                              try {
                                await widget.state.updateEntityRow('invoices', inv['id'], {'status': v});
                                _load();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                            if (v == 'delete') {
                              try {
                                await widget.state.deleteEntityRow('invoices', inv['id']);
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
                            if (inv['status'] != 'paid' && inv['status'] != 'cancelled')
                              const PopupMenuItem(value: 'paid', child: Text('Mark paid')),
                            if (inv['status'] == 'draft')
                              const PopupMenuItem(value: 'sent', child: Text('Mark sent')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            if (inv['status'] != 'paid')
                              const PopupMenuItem(value: 'cancelled', child: Text('Cancel invoice')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: kFg38)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
