import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../voucher.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _typeFilter = 'all';
  List<Tx>? _txs;
  String? _entityId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _txs = null);
    final txs = await widget.state.fetchTransactions(
      start: _month,
      end: DateTime(_month.year, _month.month + 1, 0),
      type: _typeFilter == 'all' ? null : _typeFilter,
    );
    if (mounted) {
      setState(() {
        _txs = txs;
        _entityId = widget.state.currentEntity?.id;
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _openForm({Tx? edit}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TxFormSheet(state: widget.state, edit: edit),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Tx t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('${t.description.isEmpty ? t.categoryName : t.description} • ${taka(t.amount)}\n'
            'The account balance will be restored.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.state.deleteTransaction(t.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entityId != null && _entityId != widget.state.currentEntity?.id) {
      _entityId = widget.state.currentEntity?.id;
      _load();
    }
    final txs = _txs;
    final income = txs?.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount) ?? 0;
    final expense = txs?.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount) ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Center(
                    child: Text(DateFormat('MMMM yyyy').format(_month),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
                const SizedBox(width: 4),
                DropdownButton<String>(
                  value: _typeFilter,
                  underline: const SizedBox.shrink(),
                  dropdownColor: kCard,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'income', child: Text('💰 Income')),
                    DropdownMenuItem(value: 'expense', child: Text('💸 Expense')),
                  ],
                  onChanged: (v) {
                    setState(() => _typeFilter = v ?? 'all');
                    _load();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _SummaryPill(label: 'In', value: taka(income), color: kEmerald),
                const SizedBox(width: 8),
                _SummaryPill(label: 'Out', value: taka(expense), color: kRed),
                const SizedBox(width: 8),
                _SummaryPill(label: 'Net', value: taka(income - expense), color: kCyan),
              ],
            ),
          ),
          Expanded(
            child: txs == null
                ? const Center(child: CircularProgressIndicator(color: kCyan))
                : txs.isEmpty
                    ? Center(
                        child: Text('📭  No transactions',
                            style: TextStyle(color: kFg.withValues(alpha: 0.35))),
                      )
                    : RefreshIndicator(
                        color: kCyan,
                        onRefresh: _load,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: txs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => TxTile(
                            tx: txs[i],
                            onEdit: () => _openForm(edit: txs[i]),
                            onDelete: () => _delete(txs[i]),
                            onVoucher: () => showVoucher(
                                context, txs[i], widget.state.currentEntity?.name ?? ''),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: kFg.withValues(alpha: 0.4))),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared transaction row (also used on the dashboard).
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx, this.onEdit, this.onDelete, this.onVoucher});
  final Tx tx;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onVoucher;

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == 'income';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kFg.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tx.categoryIcon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description.isEmpty ? tx.categoryName : tx.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.categoryName} • ${DateFormat('MMM d').format(tx.date)}'
                      '${tx.accountName.isNotEmpty ? ' • ${tx.accountName}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isIncome ? '+' : '-'}${taka(tx.amount)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isIncome ? kEmerald : kRed,
                ),
              ),
              if (onDelete != null || onEdit != null || onVoucher != null)
                PopupMenuButton<String>(
                  color: kCard,
                  icon: Icon(Icons.more_vert, size: 18, color: kFg.withValues(alpha: 0.3)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'voucher') onVoucher?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                    if (onVoucher != null)
                      const PopupMenuItem(value: 'voucher', child: Text('🖨️ Print Voucher')),
                    if (onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add / edit transaction bottom sheet. Pops `true` when a change was saved.
class TxFormSheet extends StatefulWidget {
  const TxFormSheet({super.key, required this.state, this.edit});
  final AppState state;
  final Tx? edit;

  @override
  State<TxFormSheet> createState() => _TxFormSheetState();
}

class _TxFormSheetState extends State<TxFormSheet> {
  late String _type = widget.edit?.type ?? 'expense';
  late String? _categoryId = widget.edit?.categoryId;
  late String? _accountId = widget.edit?.accountId;
  late final _amount = TextEditingController(
      text: widget.edit == null ? '' : widget.edit!.amount.toString());
  late final _description = TextEditingController(text: widget.edit?.description ?? '');
  late DateTime _date = widget.edit?.date ?? DateTime.now();
  bool _busy = false;

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (_categoryId == null || _accountId == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a category, an account and a valid amount.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.edit == null) {
        await widget.state.addTransaction(
          accountId: _accountId!,
          categoryId: _categoryId!,
          type: _type,
          amount: amount,
          date: _date,
          description: _description.text.trim(),
        );
      } else {
        await widget.state.updateTransaction(
          id: widget.edit!.id,
          accountId: _accountId!,
          categoryId: _categoryId!,
          type: _type,
          amount: amount,
          date: _date,
          description: _description.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.state.categories.where((c) => c.type == _type).toList();
    // If the selected category belongs to the other type, reset it.
    if (_categoryId != null && !cats.any((c) => c.id == _categoryId)) _categoryId = null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: kFg24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.edit == null ? 'Add Transaction' : 'Edit Transaction',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: ['expense', 'income'].map((t) {
                final selected = _type == t;
                final color = t == 'expense' ? kRed : kEmerald;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t == 'expense' ? 8 : 0),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected ? color.withValues(alpha: 0.15) : kFg.withValues(alpha: 0.04),
                        side: BorderSide(color: selected ? color : kFg12),
                        foregroundColor: selected ? color : kFg38,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() => _type = t),
                      child: Text(t == 'expense' ? '💸 Expense' : '💰 Income'),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              dropdownColor: kCard,
              decoration: const InputDecoration(labelText: 'Category'),
              items: cats
                  .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: widget.state.accounts.any((a) => a.id == _accountId) ? _accountId : null,
              dropdownColor: kCard,
              decoration: const InputDecoration(labelText: 'Account'),
              items: widget.state.accounts
                  .map((a) => DropdownMenuItem(
                      value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (৳)', hintText: '0.00'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'What was this for?'),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(DateFormat('EEE, MMM d, yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: widget.edit == null ? 'Add Transaction' : 'Update Transaction',
              busy: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
