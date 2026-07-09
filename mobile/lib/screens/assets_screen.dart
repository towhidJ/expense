import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _assetTypes = ['Land', 'Property', 'Vehicle', 'Gold', 'Equipment', 'Furniture', 'Other'];

// Common quantity units per asset type (gold in bhori, land in katha, ...)
const _unitsByType = {
  'Gold': ['ভরি', 'আনা', 'গ্রাম', 'রতি'],
  'Land': ['কাঠা', 'শতক', 'বিঘা', 'একর', 'sq ft'],
  'Property': ['sq ft', 'কাঠা', 'unit'],
  'Vehicle': ['pcs'],
  'Equipment': ['pcs'],
  'Furniture': ['pcs'],
  'Other': ['pcs', 'kg', 'unit'],
};

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  List<Asset>? _assets;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await widget.state.fetchAssets();
    if (mounted) setState(() => _assets = a);
  }

  Future<void> _openForm({Asset? edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final purchase = TextEditingController(text: edit == null ? '' : edit.purchaseValue.toString());
    final current = TextEditingController(text: edit == null ? '' : edit.currentValue.toString());
    final quantity = TextEditingController(text: edit?.quantity == null ? '' : edit!.quantity.toString());
    final unit = TextEditingController(text: edit?.unit ?? '');
    String type = edit != null && _assetTypes.contains(edit.type) ? edit.type : 'Other';
    DateTime date = edit?.purchaseDate ?? DateTime.now();

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
                Text(edit == null ? 'New Asset' : 'Edit Asset', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Yamaha FZ')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  dropdownColor: kCard,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _assetTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setSheet(() => type = v ?? 'Other'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: purchase,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Purchase Value (৳)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: current,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Current Value (৳)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantity,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          hintText: type == 'Gold' ? 'e.g. 5.5' : (type == 'Land' ? 'e.g. 10' : 'e.g. 1'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: unit,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          hintText: (_unitsByType[type] ?? _unitsByType['Other']!).first,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: (_unitsByType[type] ?? _unitsByType['Other']!)
                      .map((u) => ActionChip(
                            label: Text(u, style: const TextStyle(fontSize: 11)),
                            backgroundColor: kFg.withValues(alpha: 0.05),
                            side: BorderSide(color: kFg.withValues(alpha: 0.1)),
                            onPressed: () => setSheet(() => unit.text = u),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Purchase Date'),
                    child: Text(DateFormat('MMM d, yyyy').format(date)),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: edit == null ? 'Add Asset' : 'Save',
                  onPressed: () {
                    if (name.text.trim().isEmpty || double.tryParse(purchase.text.trim()) == null || double.tryParse(current.text.trim()) == null) return;
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
      await widget.state.upsertAsset(
        id: edit?.id,
        name: name.text.trim(),
        type: type,
        purchaseValue: double.parse(purchase.text.trim()),
        currentValue: double.parse(current.text.trim()),
        purchaseDate: date,
        quantity: double.tryParse(quantity.text.trim()),
        unit: unit.text.trim(),
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final assets = _assets;
    final totalValue = assets?.fold<double>(0, (s, a) => s + a.currentValue) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Assets', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: assets == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Asset Value', style: TextStyle(fontSize: 12, color: kFg38)),
                        const SizedBox(height: 4),
                        Text(taka(totalValue), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kOrange)),
                        Text('${assets.length} assets', style: TextStyle(fontSize: 11, color: kFg38)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (assets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('🏍️  No assets yet', style: TextStyle(color: kFg.withValues(alpha: 0.35)))),
                  )
                else
                  ...assets.map((a) {
                    final gain = a.currentValue - a.purchaseValue;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => _openForm(edit: a),
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.two_wheeler, color: kOrange, size: 20),
                          ),
                          title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${a.type}'
                            '${a.quantity != null ? ' • ${a.quantity} ${a.unit}'.trimRight() : ''}'
                            '${a.purchaseDate != null ? ' • ${DateFormat('MMM yyyy').format(a.purchaseDate!)}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(taka(a.currentValue),
                                      style: const TextStyle(
                                          fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text('${gain >= 0 ? '+' : ''}${taka(gain)}',
                                      style: TextStyle(fontSize: 11, color: gain >= 0 ? kEmerald : kRed)),
                                ],
                              ),
                              PopupMenuButton<String>(
                                color: kCard,
                                icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                                onSelected: (v) async {
                                  if (v == 'edit') _openForm(edit: a);
                                  if (v == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Delete "${a.name}"?'),
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
                                      await widget.state.deleteAsset(a.id);
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
            ),
    );
  }
}
