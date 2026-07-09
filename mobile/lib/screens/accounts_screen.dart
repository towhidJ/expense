import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _accountTypes = {
  'cash': ('💵', 'Cash'),
  'bank': ('🏦', 'Bank'),
  'mobile': ('📱', 'Mobile Banking'),
  'wallet': ('👛', 'Wallet'),
  'credit_card': ('💳', 'Credit Card'),
};

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key, required this.state});
  final AppState state;

  Future<void> _openForm(BuildContext context, {Account? edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final opening = TextEditingController(text: edit == null ? '' : edit.currentBalance.toString());
    final accountNumber = TextEditingController(text: edit?.accountNumber ?? '');
    String type = edit != null && _accountTypes.containsKey(edit.type) ? edit.type : 'cash';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(edit == null ? 'New Account' : 'Edit Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                dropdownColor: kCard,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _accountTypes.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value.$1} ${e.value.$2}')))
                    .toList(),
                onChanged: (v) => setState(() => type = v ?? 'cash'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNumber,
                decoration: const InputDecoration(
                    labelText: 'Account Number (optional)', hintText: 'A/C no / bKash 01XXXXXXXXX'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: opening,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: edit == null ? 'Opening Balance (৳)' : 'Current Balance (৳)', hintText: '0'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(edit == null ? 'Add' : 'Save')),
          ],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    try {
      if (edit == null) {
        await state.addAccount(
          name: name.text.trim(),
          type: type,
          openingBalance: double.tryParse(opening.text.trim()) ?? 0,
          accountNumber: accountNumber.text.trim(),
        );
      } else {
        await state.updateAccount(
          id: edit.id,
          name: name.text.trim(),
          type: type,
          accountNumber: accountNumber.text.trim(),
          currentBalance: double.tryParse(opening.text.trim()) ?? edit.currentBalance,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(BuildContext context, Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${a.name}"?'),
        content: const Text('Accounts with existing transactions cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await state.deleteAccount(a.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cannot delete: account is used by transactions.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = state.accounts.fold<double>(0, (s, a) => s + a.currentBalance);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        color: kCyan,
        onRefresh: state.refreshAccounts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Balance',
                        style: TextStyle(fontSize: 12, color: kFg.withValues(alpha: 0.4))),
                    const SizedBox(height: 4),
                    Text(taka(total),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kCyan)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...state.accounts.map((a) {
              final meta = _accountTypes[a.type] ?? ('💰', a.type);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kFg.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(meta.$1, style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(a.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                        '${meta.$2}${a.accountNumber.isNotEmpty ? ' • A/C: ${a.accountNumber}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: kFg.withValues(alpha: 0.35))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          taka(a.currentBalance),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: a.currentBalance >= 0 ? kEmerald : kRed,
                          ),
                        ),
                        PopupMenuButton<String>(
                          color: kCard,
                          icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                          onSelected: (v) {
                            if (v == 'edit') _openForm(context, edit: a);
                            if (v == 'delete') _delete(context, a);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                            PopupMenuItem(value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (state.accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text('No accounts yet — add one with +',
                      style: TextStyle(color: kFg.withValues(alpha: 0.35))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
