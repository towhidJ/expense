import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal>? _goals;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await widget.state.fetchGoals();
    if (mounted) setState(() => _goals = g);
  }

  Future<void> _openForm({Goal? edit}) async {
    final title = TextEditingController(text: edit?.title ?? '');
    final target = TextEditingController(text: edit == null ? '' : edit.targetAmount.toString());
    final saved = TextEditingController(text: edit == null ? '0' : edit.savedAmount.toString());
    DateTime? targetDate = edit?.targetDate;

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
                Text(edit == null ? 'New Goal' : 'Edit Goal', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. New Laptop')),
                const SizedBox(height: 12),
                TextField(
                  controller: target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Target Amount (৳)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: saved,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Saved So Far (৳)'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: targetDate ?? DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setSheet(() => targetDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Target Date (optional)'),
                    child: Text(targetDate == null ? '—' : DateFormat('MMM d, yyyy').format(targetDate!)),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: edit == null ? 'Add Goal' : 'Save',
                  onPressed: () {
                    if (title.text.trim().isEmpty || double.tryParse(target.text.trim()) == null) return;
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
      await widget.state.upsertGoal(
        id: edit?.id,
        title: title.text.trim(),
        targetAmount: double.parse(target.text.trim()),
        savedAmount: double.tryParse(saved.text.trim()) ?? 0,
        targetDate: targetDate,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = _goals;
    return Scaffold(
      appBar: AppBar(title: const Text('Goals', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: goals == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : goals.isEmpty
              ? Center(child: Text('🎯  No goals yet', style: TextStyle(color: kFg.withValues(alpha: 0.35))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: goals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final g = goals[i];
                    final pct = g.targetAmount > 0 ? (g.savedAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
                    final done = g.savedAmount >= g.targetAmount;
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openForm(edit: g),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(g.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                                  ),
                                  if (done)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Text('🎉', style: TextStyle(fontSize: 16)),
                                    ),
                                  PopupMenuButton<String>(
                                    color: kCard,
                                    icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                                    onSelected: (v) async {
                                      if (v == 'edit') _openForm(edit: g);
                                      if (v == 'delete') {
                                        await widget.state.deleteGoal(g.id);
                                        _load();
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
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  backgroundColor: kFg.withValues(alpha: 0.06),
                                  color: done ? kEmerald : kCyan,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${taka(g.savedAmount)} / ${taka(g.targetAmount)}',
                                      style: TextStyle(fontSize: 12, color: kFg54)),
                                  Text(
                                    g.targetDate == null
                                        ? '${(pct * 100).toStringAsFixed(0)}%'
                                        : 'by ${DateFormat('MMM d, yyyy').format(g.targetDate!)}',
                                    style: TextStyle(fontSize: 11, color: kFg38),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
