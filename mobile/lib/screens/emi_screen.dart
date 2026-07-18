import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

/// EMI calculator + amortization schedule + saved scenarios (emi_scenarios).
/// Pure client-side math; scenarios are plain entity rows — mirrors web /emi.
class EmiScreen extends StatefulWidget {
  const EmiScreen({super.key, required this.state});
  final AppState state;

  @override
  State<EmiScreen> createState() => _EmiScreenState();
}

class _ScheduleRow {
  _ScheduleRow(this.month, this.payment, this.principal, this.interest, this.balance);
  final int month;
  final double payment, principal, interest, balance;
}

class _Schedule {
  _Schedule(this.emi, this.rows);
  final double emi;
  final List<_ScheduleRow> rows;
  double get totalInterest => rows.fold(0, (s, r) => s + r.interest);
  double get totalPayment => rows.fold(0, (s, r) => s + r.payment);
  int get months => rows.length;
}

_Schedule _buildSchedule(double principal, double annualRate, int n, double extraMonthly) {
  final r = annualRate / 12 / 100;
  final emi = r == 0 ? principal / n : principal * r * math.pow(1 + r, n) / (math.pow(1 + r, n) - 1);
  final rows = <_ScheduleRow>[];
  var balance = principal;
  var month = 0;
  while (balance > 0.5 && month < n * 3) {
    month++;
    final interest = balance * r;
    var principalPaid = emi - interest + extraMonthly;
    if (principalPaid > balance) principalPaid = balance;
    balance -= principalPaid;
    rows.add(_ScheduleRow(month, interest + principalPaid, principalPaid, interest, math.max(balance, 0)));
    if (balance <= 0.5) break;
  }
  return _Schedule(emi, rows);
}

class _EmiScreenState extends State<EmiScreen> {
  final _principal = TextEditingController(text: '500000');
  final _rate = TextEditingController(text: '12');
  final _tenure = TextEditingController(text: '36');
  final _extra = TextEditingController(text: '0');
  final _name = TextEditingController();
  List<Map<String, dynamic>>? _scenarios;
  bool _showAll = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.state.entityRows('emi_scenarios');
      if (mounted) setState(() => _scenarios = rows);
    } catch (_) {
      if (mounted) setState(() => _scenarios = []);
    }
  }

  double get _p => double.tryParse(_principal.text) ?? 0;
  double get _r => double.tryParse(_rate.text) ?? 0;
  int get _n => int.tryParse(_tenure.text) ?? 0;
  double get _e => double.tryParse(_extra.text) ?? 0;

  Future<void> _save() async {
    if (_p <= 0 || _n <= 0) return;
    setState(() => _saving = true);
    try {
      await widget.state.insertEntityRow('emi_scenarios', {
        'name': _name.text.trim().isEmpty ? 'Loan of ${taka(_p)}' : _name.text.trim(),
        'principal': _p,
        'interest_rate': _r,
        'tenure_months': _n,
      });
      _name.clear();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final base = _p > 0 && _n > 0 ? _buildSchedule(_p, _r, _n, 0) : null;
    final withExtra = _p > 0 && _n > 0 && _e > 0 ? _buildSchedule(_p, _r, _n, _e) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('EMI Calculator', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _principal,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Loan amount (৳)'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: _rate,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Rate (%/yr)'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _tenure,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Tenure (months)'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: _extra,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Extra/month (৳)'))),
                  ]),
                ],
              ),
            ),
          ),
          if (base != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _stat('Monthly EMI', taka(base.emi), kCyan)),
              const SizedBox(width: 10),
              Expanded(child: _stat('Total Interest', taka(base.totalInterest), kRed)),
            ]),
            const SizedBox(height: 10),
            _stat('Total Payment (${base.months} months)', taka(base.totalPayment), kPurple),
            if (withExtra != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Paying an extra ${taka(_e)}/month clears the loan in ${withExtra.months} months '
                    'instead of ${base.months}, saving ${taka(base.totalInterest - withExtra.totalInterest)} in interest.',
                    style: const TextStyle(fontSize: 12.5, color: kEmerald, height: 1.4),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Save as scenario
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Save as… (optional name)'))),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, color: kCyan),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            // Amortization table
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Row(children: [
                      _th('Mo', 34),
                      Expanded(child: _thRight('Payment')),
                      Expanded(child: _thRight('Principal')),
                      Expanded(child: _thRight('Interest')),
                      Expanded(child: _thRight('Balance')),
                    ]),
                  ),
                  ...(_showAll ? base.rows : base.rows.take(12)).map((row) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        child: Row(children: [
                          SizedBox(width: 34, child: Text('${row.month}', style: TextStyle(fontSize: 11.5, color: kFg54))),
                          Expanded(child: _tdRight(taka(row.payment), kFg)),
                          Expanded(child: _tdRight(taka(row.principal), kEmerald)),
                          Expanded(child: _tdRight(taka(row.interest), kRed.withValues(alpha: 0.8))),
                          Expanded(child: _tdRight(taka(row.balance), kFg54)),
                        ]),
                      )),
                  if (base.rows.length > 12)
                    TextButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      child: Text(_showAll ? 'Show less' : 'Show all ${base.rows.length} months',
                          style: const TextStyle(color: kCyan, fontSize: 12.5)),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
          if ((_scenarios ?? []).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('SAVED SCENARIOS',
                style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: kFg38, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._scenarios!.map((s) => Card(
                  child: ListTile(
                    title: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                        '${taka((s['principal'] as num?) ?? 0)} · ${s['interest_rate']}% · ${s['tenure_months']} months',
                        style: TextStyle(fontSize: 11.5, color: kFg38)),
                    trailing: PopupMenuButton<String>(
                      color: kCard,
                      icon: Icon(Icons.more_vert, color: kFg38, size: 20),
                      onSelected: (v) async {
                        if (v == 'load') {
                          setState(() {
                            _principal.text = '${s['principal']}';
                            _rate.text = '${s['interest_rate']}';
                            _tenure.text = '${s['tenure_months']}';
                            _extra.text = '0';
                          });
                        }
                        if (v == 'delete') {
                          try {
                            await widget.state.deleteEntityRow('emi_scenarios', s['id']);
                            _load();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'load', child: Text('Load into calculator')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _th(String label, double width) =>
      SizedBox(width: width, child: Text(label, style: TextStyle(fontSize: 10.5, color: kFg38, fontWeight: FontWeight.w600)));

  Widget _thRight(String label) => Text(label,
      textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, color: kFg38, fontWeight: FontWeight.w600));

  Widget _tdRight(String v, Color c) =>
      Text(v, textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: c));

  Widget _stat(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: kFg38)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
