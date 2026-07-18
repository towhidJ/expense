import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../theme.dart';

/// Inventory / stock tracker — mirrors web /inventory. Quantity changes go
/// ONLY through the process_inventory_movement RPC (running balance).
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.state});
  final AppState state;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>>? _items;
  List<Map<String, dynamic>> _movements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.state.entityRows('inventory_items', orderBy: 'name', ascending: true),
        widget.state.entityRows('inventory_movements', orderBy: 'move_date'),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0];
        _movements = results[1];
      });
    } catch (_) {
      if (mounted) setState(() => _items = []);
    }
  }

  Future<void> _addItem() async {
    final name = TextEditingController();
    final sku = TextEditingController();
    final unit = TextEditingController(text: 'pcs');
    final cost = TextEditingController();
    final sale = TextEditingController();
    final reorder = TextEditingController();
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
                const Text('New Item', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child:
                          TextField(controller: sku, decoration: const InputDecoration(labelText: 'SKU'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: unit,
                          decoration: const InputDecoration(labelText: 'Unit (pcs/kg/box)'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: cost,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Cost price'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: sale,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Sale price'))),
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: reorder,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Reorder level', helperText: 'Low-stock alert below this quantity')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Item',
                  busy: busy,
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.insertEntityRow('inventory_items', {
                        'name': name.text.trim(),
                        'sku': sku.text.trim().isEmpty ? null : sku.text.trim(),
                        'unit': unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(),
                        'cost_price': double.tryParse(cost.text.trim()) ?? 0,
                        'sale_price': double.tryParse(sale.text.trim()) ?? 0,
                        'reorder_level': double.tryParse(reorder.text.trim()) ?? 0,
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

  Future<void> _move(Map<String, dynamic> item, String type) async {
    final qty = TextEditingController();
    final price = TextEditingController(
        text: '${type == 'in' ? item['cost_price'] ?? '' : item['sale_price'] ?? ''}');
    final notes = TextEditingController();
    String? accountId;
    String? categoryId;
    DateTime date = DateTime.now();
    bool busy = false;
    final isIn = type == 'in';
    final cats = widget.state.categories.where((c) => c.type == (isIn ? 'expense' : 'income')).toList();

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
                Text('${isIn ? 'Stock In' : 'Stock Out'} — ${item['name']}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                Text('Current: ${item['quantity']} ${item['unit']}',
                    style: TextStyle(fontSize: 12, color: kFg38)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: qty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Quantity'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: price,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Unit price (৳)'))),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  dropdownColor: kCard,
                  initialValue: accountId,
                  decoration: InputDecoration(
                      labelText:
                          isIn ? 'Pay from account (optional)' : 'Deposit to account (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("Don't log a transaction")),
                    ...widget.state.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                  ],
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                if (accountId != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    dropdownColor: kCard,
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: cats
                        .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                        .toList(),
                    onChanged: (v) => setSheet(() => categoryId = v),
                  ),
                ],
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
                  label: 'Confirm',
                  busy: busy,
                  onPressed: () async {
                    final q = double.tryParse(qty.text.trim());
                    if (q == null || q <= 0) return;
                    if (accountId != null && categoryId == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Pick a category for the transaction.')));
                      return;
                    }
                    setSheet(() => busy = true);
                    try {
                      await widget.state.processInventoryMovement(
                        itemId: item['id'],
                        movementType: type,
                        quantity: q,
                        unitPrice: double.tryParse(price.text.trim()) ?? 0,
                        date: date,
                        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                        accountId: accountId,
                        categoryId: categoryId,
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
    final items = _items;
    final value = (items ?? []).fold<double>(
        0,
        (s, i) =>
            s + ((i['quantity'] as num?)?.toDouble() ?? 0) * ((i['cost_price'] as num?)?.toDouble() ?? 0));
    final low = (items ?? [])
        .where((i) =>
            ((i['reorder_level'] as num?)?.toDouble() ?? 0) > 0 &&
            ((i['quantity'] as num?)?.toDouble() ?? 0) <= ((i['reorder_level'] as num?)?.toDouble() ?? 0))
        .length;
    final recent = [..._movements]
      ..sort((a, b) => (b['move_date'] as String).compareTo(a['move_date'] as String));

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : RefreshIndicator(
              color: kCyan,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Row(children: [
                    Expanded(child: _stat('Items', '${items.length}', kCyan)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Stock Value', taka(value), kEmerald)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Low Stock', '$low', low > 0 ? kRed : kFg38)),
                  ]),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No items yet — tap + to add stock items.',
                              style: TextStyle(color: kFg38))),
                    ),
                  ...items.map((i) {
                    final isLow = ((i['reorder_level'] as num?)?.toDouble() ?? 0) > 0 &&
                        ((i['quantity'] as num?)?.toDouble() ?? 0) <=
                            ((i['reorder_level'] as num?)?.toDouble() ?? 0);
                    return Card(
                      child: ListTile(
                        title: Text('${i['name']}${isLow ? ' ⚠️' : ''}', style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          '${i['quantity']} ${i['unit']} in stock · cost ${taka((i['cost_price'] as num?) ?? 0)} / sale ${taka((i['sale_price'] as num?) ?? 0)}',
                          style: TextStyle(fontSize: 11.5, color: isLow ? kRed : kFg38),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _move(i, 'in'),
                              icon: const Icon(Icons.add_circle_outline, color: kEmerald, size: 22),
                              tooltip: 'Stock in',
                            ),
                            IconButton(
                              onPressed: () => _move(i, 'out'),
                              icon: const Icon(Icons.remove_circle_outline, color: kRed, size: 22),
                              tooltip: 'Stock out',
                            ),
                            PopupMenuButton<String>(
                              color: kCard,
                              icon: Icon(Icons.more_vert, color: kFg38, size: 20),
                              onSelected: (v) async {
                                if (v == 'delete') {
                                  try {
                                    await widget.state.deleteEntityRow('inventory_items', i['id']);
                                    _load();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  }
                                }
                              },
                              itemBuilder: (_) =>
                                  const [PopupMenuItem(value: 'delete', child: Text('Delete item'))],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('RECENT MOVEMENTS',
                        style: TextStyle(
                            fontSize: 11, letterSpacing: 1.2, color: kFg38, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...recent.take(15).map((m) {
                      final item =
                          items.where((i) => i['id'] == m['item_id']).firstOrNull;
                      final isIn = m['movement_type'] == 'in';
                      return Card(
                        child: ListTile(
                          dense: true,
                          leading: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                              size: 18, color: isIn ? kEmerald : kRed),
                          title: Text(item?['name'] ?? '—', style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                              DateFormat('MMM d, yyyy').format(DateTime.parse(m['move_date'])),
                              style: TextStyle(fontSize: 11, color: kFg38)),
                          trailing: Text(
                              '${isIn ? '+' : '−'}${m['quantity']} · ${taka(((m['quantity'] as num?)?.toDouble() ?? 0) * ((m['unit_price'] as num?)?.toDouble() ?? 0))}',
                              style: TextStyle(fontSize: 12, color: isIn ? kEmerald : kRed)),
                        ),
                      );
                    }),
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
