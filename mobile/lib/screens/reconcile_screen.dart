import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Bank statement reconciliation — mirrors web /reconcile. Mobile takes the
/// statement as pasted CSV text (no file-picker dependency); matching logic
/// is identical: same type, amount within ৳1, date within ±3 days.
class ReconcileScreen extends StatefulWidget {
  const ReconcileScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ReconcileScreen> createState() => _ReconcileScreenState();
}

class _StatementRow {
  _StatementRow(this.date, this.description, this.amount, this.type);
  final DateTime date;
  final String description;
  final double amount;
  final String type;
  bool selected = true;
}

/// Minimal CSV parser: handles quoted fields and commas inside quotes.
List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field = StringBuffer();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field = StringBuffer();
      if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  row.add(field.toString());
  if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
  return rows;
}

class _ReconcileScreenState extends State<ReconcileScreen> {
  int _step = 1;
  String? _accountId;
  final _csvCtl = TextEditingController();
  List<String> _headers = [];
  List<List<String>> _dataRows = [];
  String? _dateCol, _descCol, _amountCol;

  List<_StatementRow> _missing = [];
  int _matched = 0;
  List<Tx> _stale = [];
  String? _expenseCatId, _incomeCatId;
  bool _importing = false;
  int? _importedCount;

  void _parse() {
    final rows = _parseCsv(_csvCtl.text.trim());
    if (rows.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Paste CSV with a header row and data rows.')));
      return;
    }
    setState(() {
      _headers = rows.first.map((h) => h.trim()).toList();
      _dataRows = rows.skip(1).toList();
      _dateCol = null;
      _descCol = null;
      _amountCol = null;
      _step = 2;
    });
  }

  Future<void> _compare() async {
    if (_dateCol == null || _descCol == null || _amountCol == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Map date, description and amount columns.')));
      return;
    }
    final di = _headers.indexOf(_dateCol!);
    final de = _headers.indexOf(_descCol!);
    final am = _headers.indexOf(_amountCol!);

    final statement = <_StatementRow>[];
    for (final r in _dataRows) {
      if (r.length <= di || r.length <= de || r.length <= am) continue;
      final raw = double.tryParse(r[am].replaceAll(RegExp(r'[,৳$\s]'), ''));
      final date = DateTime.tryParse(r[di].trim());
      if (raw == null || raw == 0 || date == null) continue;
      statement.add(_StatementRow(date, r[de].trim(), raw.abs(), raw < 0 ? 'expense' : 'income'));
    }
    if (statement.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No usable rows — dates must be YYYY-MM-DD, negative amount = expense.')));
      return;
    }

    final all = await widget.state.fetchTransactions();
    final appRows = all.where((t) => t.accountId == _accountId).toList();
    final claimed = <String>{};
    final missing = <_StatementRow>[];
    var matched = 0;
    for (final sr in statement) {
      Tx? hit;
      for (final ar in appRows) {
        if (claimed.contains(ar.id)) continue;
        if (ar.type != sr.type) continue;
        if ((ar.amount - sr.amount).abs() >= 1) continue;
        if (ar.date.difference(sr.date).inDays.abs() > 3) continue;
        hit = ar;
        break;
      }
      if (hit != null) {
        claimed.add(hit.id);
        matched++;
      } else {
        missing.add(sr);
      }
    }
    final minDate = statement.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = statement.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final stale = appRows
        .where((t) =>
            !claimed.contains(t.id) &&
            !t.date.isBefore(minDate.subtract(const Duration(days: 3))) &&
            !t.date.isAfter(maxDate.add(const Duration(days: 3))))
        .toList();

    if (!mounted) return;
    setState(() {
      _missing = missing;
      _matched = matched;
      _stale = stale;
      _step = 3;
    });
  }

  Future<void> _import() async {
    final selected = _missing.where((r) => r.selected).toList();
    if (selected.isEmpty) return;
    if (selected.any((r) => r.type == 'expense') && _expenseCatId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick an expense category first.')));
      return;
    }
    if (selected.any((r) => r.type == 'income') && _incomeCatId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick an income category first.')));
      return;
    }
    setState(() => _importing = true);
    try {
      final count = await widget.state.importTransactionsBulk(selected
          .map((r) => {
                'account_id': _accountId,
                'category_id': r.type == 'expense' ? _expenseCatId : _incomeCatId,
                'type': r.type,
                'amount': r.amount,
                'date': DateFormat('yyyy-MM-dd').format(r.date),
                'description': r.description,
              })
          .toList());
      if (mounted) setState(() => _importedCount = count);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
    if (mounted) setState(() => _importing = false);
  }

  void _reset() => setState(() {
        _step = 1;
        _csvCtl.clear();
        _missing = [];
        _stale = [];
        _matched = 0;
        _importedCount = null;
        _expenseCatId = null;
        _incomeCatId = null;
      });

  @override
  Widget build(BuildContext context) {
    final expenseCats = widget.state.categories.where((c) => c.type == 'expense').toList();
    final incomeCats = widget.state.categories.where((c) => c.type == 'income').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Bank Reconciliation', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_importedCount != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Icon(Icons.check_circle_outline, color: kEmerald, size: 36),
                  const SizedBox(height: 10),
                  Text('Imported $_importedCount transactions',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  TextButton(onPressed: _reset, child: const Text('Reconcile another statement')),
                ]),
              ),
            ),
          ] else if (_step == 1) ...[
            Text('Compare a bank/bKash statement against your ledger and import what\'s missing.',
                style: TextStyle(fontSize: 12.5, color: kFg54, height: 1.4)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: kCard,
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Which account is this statement for?'),
              items: widget.state.accounts
                  .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csvCtl,
              maxLines: 10,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'Paste CSV here',
                alignLabelWithHint: true,
                hintText: 'date,description,amount\n2026-07-01,ATM Withdrawal,-2000\n…',
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(label: 'Next — Map Columns', onPressed: _accountId == null ? null : _parse),
          ] else if (_step == 2) ...[
            Text('${_dataRows.length} rows found. Match your CSV columns (negative amount = expense).',
                style: TextStyle(fontSize: 12.5, color: kFg54)),
            const SizedBox(height: 12),
            for (final (label, value, setter) in [
              ('Date column', _dateCol, (String? v) => _dateCol = v),
              ('Description column', _descCol, (String? v) => _descCol = v),
              ('Amount column', _amountCol, (String? v) => _amountCol = v),
            ]) ...[
              DropdownButtonFormField<String>(
                dropdownColor: kCard,
                initialValue: value,
                decoration: InputDecoration(labelText: label),
                items: _headers.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (v) => setState(() => setter(v)),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              TextButton(onPressed: () => setState(() => _step = 1), child: const Text('Back')),
              const Spacer(),
              SizedBox(width: 160, child: GradientButton(label: 'Compare', onPressed: _compare)),
            ]),
          ] else ...[
            Row(children: [
              Expanded(child: _stat('Matched', '$_matched', kEmerald)),
              const SizedBox(width: 10),
              Expanded(child: _stat('Missing', '${_missing.length}', kOrange)),
              const SizedBox(width: 10),
              Expanded(child: _stat('Unmatched in app', '${_stale.length}', kRed)),
            ]),
            const SizedBox(height: 12),
            if (_missing.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    const Icon(Icons.check_circle_outline, color: kEmerald, size: 30),
                    const SizedBox(height: 8),
                    const Text('Everything in the statement is already in your ledger.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
                    TextButton(onPressed: _reset, child: const Text('Start over')),
                  ]),
                ),
              )
            else ...[
              Text('MISSING IN APP — IMPORT THESE?',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: kFg38, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_missing.any((r) => r.type == 'expense'))
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: _expenseCatId,
                  decoration: const InputDecoration(labelText: 'Expense category for imports'),
                  items: expenseCats
                      .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                      .toList(),
                  onChanged: (v) => setState(() => _expenseCatId = v),
                ),
              if (_missing.any((r) => r.type == 'income')) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: _incomeCatId,
                  decoration: const InputDecoration(labelText: 'Income category for imports'),
                  items: incomeCats
                      .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                      .toList(),
                  onChanged: (v) => setState(() => _incomeCatId = v),
                ),
              ],
              const SizedBox(height: 8),
              ..._missing.map((r) => Card(
                    child: CheckboxListTile(
                      dense: true,
                      activeColor: kCyan,
                      value: r.selected,
                      onChanged: (v) => setState(() => r.selected = v ?? false),
                      title: Text(r.description.isEmpty ? '(no description)' : r.description,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                          '${DateFormat('MMM d, yyyy').format(r.date)} · ${r.type} · ${taka(r.amount)}',
                          style: TextStyle(
                              fontSize: 11.5, color: r.type == 'expense' ? kRed : kEmerald)),
                    ),
                  )),
              const SizedBox(height: 10),
              GradientButton(
                label: _importing
                    ? 'Importing…'
                    : 'Import ${_missing.where((r) => r.selected).length} selected',
                busy: _importing,
                onPressed: _importing ? null : _import,
              ),
              TextButton(onPressed: _reset, child: const Text('Start over')),
            ],
            if (_stale.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('IN APP, NOT IN STATEMENT',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: kFg38, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Same date range, no matching statement row — worth a second look.',
                  style: TextStyle(fontSize: 11, color: kFg38)),
              const SizedBox(height: 8),
              ..._stale.map((t) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text(t.description.isEmpty ? t.categoryName : t.description,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(t.date),
                          style: TextStyle(fontSize: 11, color: kFg38)),
                      trailing: Text(taka(t.amount), style: const TextStyle(fontSize: 12.5)),
                    ),
                  )),
            ],
          ],
          const SizedBox(height: 24),
        ],
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
            Text(label, style: TextStyle(fontSize: 10.5, color: kFg38), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
