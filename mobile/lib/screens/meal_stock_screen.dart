import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Stock/inventory tracker (v27): what's in the pantry, manually adjusted
/// in/out — no auto-derivation from purchases (no reliable "consumed"
/// signal, and matching item names to stock rows risks double counting).
class MealStockScreen extends StatefulWidget {
  const MealStockScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealStockScreen> createState() => _MealStockScreenState();
}

class _MealStockScreenState extends State<MealStockScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  List<MealStockItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await state.fetchMealStockItems(groupId);
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addSheet() async {
    final name = TextEditingController();
    final qty = TextEditingController();
    final unit = TextEditingController();
    final threshold = TextEditingController();
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
              const Text('Add Stock Item', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'Rice / চাল')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit', hintText: 'kg')),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: threshold,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Low-stock alert below (optional)'),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Save',
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
    await _run(() => state.addMealStockItem(
          groupId: groupId,
          name: name.text.trim(),
          quantity: double.tryParse(qty.text) ?? 0,
          unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
          lowStockThreshold: double.tryParse(threshold.text),
        ));
  }

  Future<void> _adjustSheet(MealStockItem item) async {
    final amount = TextEditingController();
    final sign = await showModalBottomSheet<int>(
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
              Text(item.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              Text('Current: ${item.quantity} ${item.unit ?? ''}', style: TextStyle(fontSize: 12, color: kFg38)),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16, color: kEmerald),
                    label: const Text('Stock In', style: TextStyle(color: kEmerald)),
                    onPressed: () => Navigator.pop(sheetContext, 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.remove, size: 16, color: kOrange),
                    label: const Text('Stock Out', style: TextStyle(color: kOrange)),
                    onPressed: () => Navigator.pop(sheetContext, -1),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (sign == null) return;
    final delta = double.tryParse(amount.text);
    if (delta == null || delta <= 0) return;
    await _run(() => state.adjustMealStock(item.id, sign * delta));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Stock', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSheet,
        backgroundColor: kCyan,
        icon: const Icon(Icons.add, size: 18, color: Colors.white),
        label: const Text('Item', style: TextStyle(color: Colors.white)),
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : items.isEmpty
              ? Center(child: Text('No stock items yet.', style: TextStyle(color: kFg38)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: (item.isLow ? kRed : kCyan).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.inventory_2_outlined, color: item.isLow ? kRed : kCyan, size: 18),
                        ),
                        title: Row(children: [
                          Text(item.name, style: const TextStyle(fontSize: 14)),
                          if (item.isLow) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.warning_amber_rounded, size: 14, color: kRed),
                          ],
                        ]),
                        subtitle: Text('${item.quantity} ${item.unit ?? ''}', style: TextStyle(fontSize: 11, color: kFg38)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.exposure, size: 18, color: kCyan),
                              onPressed: () => _adjustSheet(item),
                            ),
                            if (widget.isManager)
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: kFg38),
                                onPressed: () => _run(() => state.deleteMealStockItem(item.id)),
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
