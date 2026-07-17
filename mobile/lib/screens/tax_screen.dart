import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../theme.dart';

const _prefsKey = 'tax_settings_v1'; // same shape as the web localStorage key

// NBR-style progressive slabs (first slab's limit is the editable tax-free limit).
const _slabRates = [0, 5, 10, 15, 20, 25, 30];
const _slabLimits = [350000.0, 100000.0, 400000.0, 500000.0, 500000.0, 2000000.0, double.infinity];

int _currentFyStart() {
  final now = DateTime.now();
  return now.month >= 7 ? now.year : now.year - 1;
}

class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key, required this.state});
  final AppState state;

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  int _fyStart = _currentFyStart();
  double? _trackedIncome;

  final extraIncome = TextEditingController();
  final exemptIncome = TextEditingController();
  final investment = TextEditingController();
  final rebateRate = TextEditingController(text: '15');
  final rebateCap = TextEditingController(text: '3');
  final minTax = TextEditingController(text: '5000');
  final taxFreeLimit = TextEditingController(text: '350000');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final s = jsonDecode(raw) as Map<String, dynamic>;
        extraIncome.text = '${s['extraIncome'] ?? ''}';
        exemptIncome.text = '${s['exemptIncome'] ?? ''}';
        investment.text = '${s['investmentForRebate'] ?? ''}';
        rebateRate.text = '${s['rebateRate'] ?? 15}';
        rebateCap.text = '${s['rebateCapPctOfIncome'] ?? 3}';
        minTax.text = '${s['minTax'] ?? 5000}';
        taxFreeLimit.text = '${s['taxFreeLimit'] ?? 350000}';
      }
    } catch (_) {}
    await _fetchIncome();
  }

  Future<void> _fetchIncome() async {
    setState(() => _trackedIncome = null);
    final income = await widget.state.fetchFyIncome(_fyStart);
    if (mounted) setState(() => _trackedIncome = income);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey,
        jsonEncode({
          'extraIncome': extraIncome.text,
          'exemptIncome': exemptIncome.text,
          'investmentForRebate': investment.text,
          'rebateRate': rebateRate.text,
          'rebateCapPctOfIncome': rebateCap.text,
          'minTax': minTax.text,
          'taxFreeLimit': taxFreeLimit.text,
        }));
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  ({double gross, double taxable, double tax, List<(double, int, double)> breakdown, double rebate, double payable})
      get _calc {
    final tracked = _trackedIncome ?? 0;
    final gross = tracked + _num(extraIncome);
    final taxable = (gross - _num(exemptIncome)).clamp(0, double.infinity).toDouble();
    final limits = [..._slabLimits];
    limits[0] = _num(taxFreeLimit);
    var remaining = taxable;
    var tax = 0.0;
    final breakdown = <(double, int, double)>[];
    for (var i = 0; i < limits.length && remaining > 0; i++) {
      final inSlab = remaining < limits[i] ? remaining : limits[i];
      final slabTax = inSlab * _slabRates[i] / 100;
      tax += slabTax;
      breakdown.add((inSlab, _slabRates[i], slabTax));
      remaining -= inSlab;
    }
    final capped = taxable * _num(rebateCap) / 100;
    final eligibleInvestment = _num(investment) < capped ? _num(investment) : capped;
    var rebate = eligibleInvestment * _num(rebateRate) / 100;
    if (rebate > tax) rebate = tax;
    final afterRebate = (tax - rebate).clamp(0, double.infinity).toDouble();
    final payable = taxable > _num(taxFreeLimit)
        ? (afterRebate > _num(minTax) ? afterRebate : _num(minTax))
        : afterRebate;
    return (gross: gross, taxable: taxable, tax: tax, breakdown: breakdown, rebate: rebate, payable: payable);
  }

  @override
  Widget build(BuildContext context) {
    final loading = _trackedIncome == null;
    final c = _calc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income Tax', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<int>(
            value: _fyStart,
            dropdownColor: kCard,
            underline: const SizedBox.shrink(),
            items: List.generate(4, (i) {
              final y = _currentFyStart() - i;
              return DropdownMenuItem(
                  value: y,
                  child: Text('FY $y-${'${y + 1}'.substring(2)}', style: const TextStyle(fontSize: 13)));
            }),
            onChanged: (v) {
              if (v != null) {
                _fyStart = v;
                _fetchIncome();
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Estimated tax payable', style: TextStyle(fontSize: 13, color: kCyan)),
                  const SizedBox(height: 6),
                  Text(loading ? '…' : taka(c.payable),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kCyan)),
                  const SizedBox(height: 6),
                  Text(
                    'Taxable ${taka(c.taxable)} · gross tax ${taka(c.tax)} − rebate ${taka(c.rebate)}',
                    style: TextStyle(fontSize: 11, color: kFg38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Income', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kFg70)),
                  const SizedBox(height: 4),
                  Text(
                      'Tracked income (FY $_fyStart-${'${_fyStart + 1}'.substring(2)}): ${loading ? '…' : taka(_trackedIncome!)}',
                      style: TextStyle(fontSize: 12, color: kFg54)),
                  const SizedBox(height: 10),
                  _field('Extra income not in the app (৳)', extraIncome),
                  const SizedBox(height: 10),
                  _field('Exempt income / allowances (৳)', exemptIncome),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rebate & limits', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kFg70)),
                  const SizedBox(height: 10),
                  _field('Investment for rebate (৳)', investment),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field('Rebate rate %', rebateRate)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Cap % of income', rebateCap)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field('Tax-free limit (৳)', taxFreeLimit)),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Minimum tax (৳)', minTax)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Tax-free limit: 350k general, 400k women/65+, editable. Verify slabs against the current Finance Act.',
                      style: TextStyle(fontSize: 10.5, color: kFg38)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!loading && c.breakdown.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Slab breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kFg70)),
                    const SizedBox(height: 8),
                    ...c.breakdown.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text('${taka(b.$1)} @ ${b.$2}%',
                                      style: TextStyle(fontSize: 12.5, color: kFg54))),
                              Text(taka(b.$3), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (_) {
        setState(() {});
        _persist();
      },
    );
  }
}
