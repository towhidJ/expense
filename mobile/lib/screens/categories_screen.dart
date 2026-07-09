import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _icons = ['🍔', '🚗', '🛍️', '📄', '🎮', '🏥', '📚', '🏠', '💸', '💰', '💻', '📈', '🎁', '💵', '⚡', '📱', '✈️', '🎓', '🐟', '🥦', '☕', '👕', '⛽', '🔧'];
const _colors = ['#ef4444', '#f97316', '#f59e0b', '#10b981', '#14b8a6', '#06b6d4', '#0ea5e9', '#6366f1', '#8b5cf6', '#ec4899', '#64748b'];

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _tab = 'expense';

  Future<void> _openForm({Category? edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    String icon = edit?.icon ?? _icons.first;
    String color = edit?.color ?? _colors.first;

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
                Text(edit == null ? 'New ${_tab == 'expense' ? 'Expense' : 'Income'} Category' : 'Edit Category',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 14),
                Text('Icon', style: TextStyle(fontSize: 12, color: kFg38)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _icons.map((i) {
                    final sel = icon == i;
                    return GestureDetector(
                      onTap: () => setSheet(() => icon = i),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? kCyan.withValues(alpha: 0.2) : kFg.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? kCyan : kFg12),
                        ),
                        child: Text(i, style: const TextStyle(fontSize: 18)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text('Color', style: TextStyle(fontSize: 12, color: kFg38)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colors.map((c) {
                    final col = Color(int.parse('FF${c.substring(1)}', radix: 16));
                    final sel = color == c;
                    return GestureDetector(
                      onTap: () => setSheet(() => color = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: edit == null ? 'Add Category' : 'Save Changes',
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
    if (saved != true) return;
    try {
      if (edit == null) {
        await widget.state.addCategory(name: name.text.trim(), type: _tab, icon: icon, color: color);
      } else {
        await widget.state.updateCategory(edit.id, name: name.text.trim(), icon: icon, color: color);
      }
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _delete(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: const Text('Transactions using this category may fail to display it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.state.deleteCategory(c.id);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot delete: category is used by existing transactions.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final cats = widget.state.categories.where((c) => c.type == _tab).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold))),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(),
            backgroundColor: kCyan,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: ['expense', 'income'].map((t) {
                    final sel = _tab == t;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: t == 'expense' ? 8 : 0),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: sel ? kCyan.withValues(alpha: 0.15) : kFg.withValues(alpha: 0.04),
                            side: BorderSide(color: sel ? kCyan : kFg12),
                            foregroundColor: sel ? kCyan : kFg38,
                          ),
                          onPressed: () => setState(() => _tab = t),
                          child: Text(t == 'expense' ? '💸 Expense' : '💰 Income'),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: cats.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    final col = Color(int.parse('FF${c.color.substring(1)}', radix: 16));
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: Text(c.icon, style: const TextStyle(fontSize: 18)),
                        ),
                        title: Text(c.name, style: const TextStyle(fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 18, color: kFg38),
                              onPressed: () => _openForm(edit: c),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: kFg38),
                              onPressed: () => _delete(c),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
