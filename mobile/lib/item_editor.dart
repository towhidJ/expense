import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

/// Draft row for the itemized "ki ki kinlam" list in purchase/expense forms.
class ItemDraft {
  ItemDraft([PurchaseItem? from]) {
    if (from != null) {
      name.text = from.name;
      amount.text = from.amount == null
          ? ''
          : (from.amount! % 1 == 0
              ? from.amount!.toStringAsFixed(0)
              : from.amount!.toString());
    }
  }
  final name = TextEditingController();
  final amount = TextEditingController();
}

List<PurchaseItem> draftsToItems(List<ItemDraft> drafts) => drafts
    .where((d) => d.name.text.trim().isNotEmpty)
    .map((d) => PurchaseItem(
        name: d.name.text.trim(),
        amount: double.tryParse(d.amount.text.trim())))
    .toList();

/// Dynamic item rows (name + optional ৳) used inside bottom-sheet forms.
/// The parent owns [drafts]; call with the sheet's setState as [onChanged].
class ItemRowsEditor extends StatelessWidget {
  const ItemRowsEditor({super.key, required this.drafts, required this.onChanged});
  final List<ItemDraft> drafts;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items bought (ki ki kinlen)', style: TextStyle(fontSize: 12, color: kFg54)),
        const SizedBox(height: 8),
        ...List.generate(drafts.length, (i) {
          final d = drafts[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: d.name,
                    decoration: InputDecoration(
                      hintText: 'Item ${i + 1}, e.g. Rice 5kg',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: d.amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(hintText: '৳', isDense: true),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 16, color: kFg38),
                  onPressed: () {
                    drafts.removeAt(i);
                    onChanged();
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: kCyan,
          ),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add item', style: TextStyle(fontSize: 12.5)),
          onPressed: () {
            drafts.add(ItemDraft());
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Compact read-only list of items shown when a row is expanded.
class ItemListView extends StatelessWidget {
  const ItemListView({super.key, required this.items});
  final List<PurchaseItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kFg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: items
            .map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(it.name, style: TextStyle(fontSize: 12.5, color: kFg70))),
                      if (it.amount != null)
                        Text(taka(it.amount!), style: TextStyle(fontSize: 12.5, color: kFg54)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
