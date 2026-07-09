import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Budget>? _budgets;
  Map<String, double> _spent = {}; // category_id -> spent this month

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _budgets = null);
    final results = await Future.wait([
      widget.state.fetchBudgets(_month.month, _month.year),
      widget.state.fetchTransactions(
        start: _month,
        end: DateTime(_month.year, _month.month + 1, 0),
        type: 'expense',
      ),
    ]);
    final txs = results[1] as List<Tx>;
    final spent = <String, double>{};
    for (final t in txs) {
      if (t.categoryId != null) spent[t.categoryId!] = (spent[t.categoryId!] ?? 0) + t.amount;
    }
    if (mounted) {
      setState(() {
        _budgets = results[0] as List<Budget>;
        _spent = spent;
      });
    }
  }

  Future<void> _openForm({Budget? edit}) async {
    final amount = TextEditingController(text: edit == null ? '' : edit.amount.toString());
    String? categoryId = edit?.categoryId;
    final cats = widget.state.categories.where((c) => c.type == 'expense').toList();

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
                Text(edit == null ? 'New Budget — ${DateFormat('MMMM yyyy').format(_month)}' : 'Edit Budget',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                if (edit == null)
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}'))).toList(),
                    onChanged: (v) => setSheet(() => categoryId = v),
                  )
                else
                  Text('${edit.categoryIcon} ${edit.categoryName}', style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monthly Limit (৳)'),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: edit == null ? 'Add Budget' : 'Save',
                  onPressed: () {
                    if ((edit == null && categoryId == null) || double.tryParse(amount.text.trim()) == null) return;
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
        await widget.state.addBudget(
          categoryId: categoryId!,
          amount: double.parse(amount.text.trim()),
          month: _month.month,
          year: _month.year,
        );
      } else {
        await widget.state.updateBudget(edit.id, double.parse(amount.text.trim()));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgets = _budgets;
    final totalBudget = budgets?.fold<double>(0, (s, b) => s + b.amount) ?? 0;
    final totalSpent = budgets?.fold<double>(0, (s, b) => s + (_spent[b.categoryId] ?? 0)) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() => _month = DateTime(_month.year, _month.month - 1));
                    _load();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(DateFormat('MMMM yyyy').format(_month),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _month = DateTime(_month.year, _month.month + 1));
                    _load();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      Text('Budgeted', style: TextStyle(fontSize: 11, color: kFg38)),
                      Text(taka(totalBudget), style: const TextStyle(fontWeight: FontWeight.bold, color: kCyan)),
                    ]),
                    Column(children: [
                      Text('Spent', style: TextStyle(fontSize: 11, color: kFg38)),
                      Text(taka(totalSpent), style: const TextStyle(fontWeight: FontWeight.bold, color: kRed)),
                    ]),
                    Column(children: [
                      Text('Remaining', style: TextStyle(fontSize: 11, color: kFg38)),
                      Text(taka(totalBudget - totalSpent),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: kEmerald)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: budgets == null
                ? const Center(child: CircularProgressIndicator(color: kCyan))
                : budgets.isEmpty
                    ? Center(child: Text('No budgets for this month', style: TextStyle(color: kFg.withValues(alpha: 0.35))))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: budgets.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final b = budgets[i];
                          final spent = _spent[b.categoryId] ?? 0;
                          final pct = b.amount > 0 ? (spent / b.amount).clamp(0.0, 1.0) : 0.0;
                          final over = spent > b.amount;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(b.categoryIcon, style: const TextStyle(fontSize: 18)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(b.categoryName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                      ),
                                      Text('${taka(spent)} / ${taka(b.amount)}',
                                          style: TextStyle(fontSize: 12, color: over ? kRed : kFg54)),
                                      PopupMenuButton<String>(
                                        color: kCard,
                                        iconSize: 18,
                                        onSelected: (v) async {
                                          if (v == 'edit') _openForm(edit: b);
                                          if (v == 'delete') {
                                            await widget.state.deleteBudget(b.id);
                                            _load();
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: kRed))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 6,
                                      backgroundColor: kFg.withValues(alpha: 0.06),
                                      color: over ? kRed : (pct > 0.8 ? kOrange : kEmerald),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    over
                                        ? 'Over budget by ${taka(spent - b.amount)}'
                                        : '${taka(b.amount - spent)} remaining • ${(pct * 100).toStringAsFixed(0)}% used',
                                    style: TextStyle(fontSize: 11, color: over ? kRed : kFg38),
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
  }
}
