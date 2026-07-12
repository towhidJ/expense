import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Shopping list (v19): the pre-purchase "ki ki lagbe" list. Anyone adds
/// items, whoever does the bazar ticks them off, then converts the ticked
/// items into one itemized bazar expense.
class MealShoppingScreen extends StatefulWidget {
  const MealShoppingScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealShoppingScreen> createState() => _MealShoppingScreenState();
}

class _MealShoppingScreenState extends State<MealShoppingScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  List<MealShoppingItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await state.fetchMealShoppingItems(groupId);
      if (!mounted) return;
      setState(() => _items = rows);
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

  Future<void> _addSheet() async {
    final name = TextEditingController();
    final qty = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Item', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Item', hintText: 'e.g. Chal, Soyabean tel'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qty,
                decoration: const InputDecoration(labelText: 'Qty (optional)', hintText: 'e.g. 2 kg'),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Add to List',
                onPressed: () {
                  if (name.text.trim().isNotEmpty) Navigator.pop(sheetContext, true);
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(() => state.addMealShoppingItem(groupId,
        name: name.text.trim(), qty: qty.text.trim()));
  }

  Future<void> _convertSheet(List<MealShoppingItem> bought) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var date = DateTime.now();
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
                const Text('Convert to Expense', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'All ${bought.length} bought item${bought.length > 1 ? 's' : ''} become one itemized bazar expense.',
                  style: TextStyle(fontSize: 12, color: kFg38),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Total amount (৳)'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 18, color: kEmerald),
                  title: Text('${date.day}/${date.month}/${date.year}',
                      style: const TextStyle(fontSize: 14)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Save Expense',
                  onPressed: () {
                    if ((double.tryParse(amount.text) ?? 0) > 0) Navigator.pop(sheetContext, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(() => state.convertMealShoppingToExpense(
          groupId: groupId,
          items: bought,
          amount: double.parse(amount.text),
          date: date,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expense saved — list cleared.')));
    }
  }

  Widget _itemTile(MealShoppingItem it) {
    final canDelete = widget.isManager || it.addedBy == state.uid;
    return CheckboxListTile(
      value: it.isBought,
      activeColor: kEmerald,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (v) => _run(() => state.toggleMealShoppingItem(it.id, v ?? false)),
      title: Text(
        it.qty.isEmpty ? it.name : '${it.name} — ${it.qty}',
        style: TextStyle(
          fontSize: 14,
          color: it.isBought ? kFg38 : null,
          decoration: it.isBought ? TextDecoration.lineThrough : null,
        ),
      ),
      secondary: canDelete
          ? IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: kFg38),
              onPressed: () => _run(() => state.deleteMealShoppingItem(it.id)),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final toBuy = (items ?? []).where((it) => !it.isBought).toList();
    final bought = (items ?? []).where((it) => it.isBought).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSheet,
        backgroundColor: kCyan,
        icon: const Icon(Icons.add, size: 18, color: Colors.white),
        label: const Text('Item', style: TextStyle(color: Colors.white)),
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: [
                Text('TO BUY (${toBuy.length})',
                    style: TextStyle(fontSize: 11, color: kFg38, letterSpacing: 1)),
                const SizedBox(height: 8),
                if (toBuy.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nothing on the list. Add what the mess needs.',
                          style: TextStyle(fontSize: 12, color: kFg38)),
                    ),
                  )
                else
                  Card(child: Column(children: toBuy.map(_itemTile).toList())),
                if (bought.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('BOUGHT (${bought.length})',
                            style: const TextStyle(fontSize: 11, color: kEmerald, letterSpacing: 1)),
                      ),
                      TextButton.icon(
                        onPressed: () => _convertSheet(bought),
                        icon: const Icon(Icons.shopping_cart_checkout, size: 16, color: kEmerald),
                        label: const Text('Convert to Expense',
                            style: TextStyle(fontSize: 12, color: kEmerald)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Card(child: Column(children: bought.map(_itemTile).toList())),
                ],
              ],
            ),
    );
  }
}
