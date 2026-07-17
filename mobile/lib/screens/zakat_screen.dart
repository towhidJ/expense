import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _voriGrams = 11.664;
const _nisabGoldVori = 7.5; // 87.48 g
const _nisabSilverVori = 52.5; // 612.36 g
const _zakatRate = 0.025;
const _prefsKey = 'zakat_settings_v1'; // same shape as the web localStorage key

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  bool _loading = true;
  double _savings = 0, _investments = 0, _receivables = 0, _debts = 0;

  // settings (persisted)
  String basis = 'silver';
  final goldPrice = TextEditingController(text: '145000');
  final silverPrice = TextEditingController(text: '2200');
  final goldOwned = TextEditingController();
  final silverOwned = TextEditingController();
  final otherAssets = TextEditingController();
  bool includeCash = true, includeSavings = true, includeInvestments = true, includeReceivables = true, deductDebts = true;

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
        basis = s['basis'] ?? 'silver';
        goldPrice.text = '${s['goldPriceVori'] ?? 145000}';
        silverPrice.text = '${s['silverPriceVori'] ?? 2200}';
        goldOwned.text = '${s['goldOwnedVori'] ?? ''}';
        silverOwned.text = '${s['silverOwnedVori'] ?? ''}';
        otherAssets.text = '${s['otherAssets'] ?? ''}';
        includeCash = s['includeCash'] ?? true;
        includeSavings = s['includeSavings'] ?? true;
        includeInvestments = s['includeInvestments'] ?? true;
        includeReceivables = s['includeReceivables'] ?? true;
        deductDebts = s['deductDebts'] ?? true;
      }
    } catch (_) {}
    final (savings, investments, receivables, debts) = await widget.state.fetchZakatParts();
    if (mounted) {
      setState(() {
        _savings = savings;
        _investments = investments;
        _receivables = receivables;
        _debts = debts;
        _loading = false;
      });
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey,
        jsonEncode({
          'basis': basis,
          'goldPriceVori': goldPrice.text,
          'silverPriceVori': silverPrice.text,
          'goldOwnedVori': goldOwned.text,
          'silverOwnedVori': silverOwned.text,
          'otherAssets': otherAssets.text,
          'includeCash': includeCash,
          'includeSavings': includeSavings,
          'includeInvestments': includeInvestments,
          'includeReceivables': includeReceivables,
          'deductDebts': deductDebts,
        }));
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final cash = sumBdt(widget.state.accounts);
    final goldValue = _num(goldOwned) * _num(goldPrice);
    final silverValue = _num(silverOwned) * _num(silverPrice);
    final otherValue = _num(otherAssets);
    final totalAssets = (includeCash ? cash : 0) +
        (includeSavings ? _savings : 0) +
        (includeInvestments ? _investments : 0) +
        (includeReceivables ? _receivables : 0) +
        goldValue +
        silverValue +
        otherValue;
    final deductible = deductDebts ? _debts : 0;
    final netWealth = totalAssets - deductible;
    final nisab = basis == 'gold' ? _nisabGoldVori * _num(goldPrice) : _nisabSilverVori * _num(silverPrice);
    final eligible = netWealth >= nisab && nisab > 0;
    final zakatDue = eligible ? netWealth * _zakatRate : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Zakat Calculator', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kEmerald))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(eligible ? 'Zakat payable this year' : 'Below nisab — zakat not obligatory',
                            style: TextStyle(fontSize: 13, color: eligible ? kEmerald : kFg54)),
                        const SizedBox(height: 6),
                        Text(taka(zakatDue),
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: eligible ? kEmerald : kFg38)),
                        const SizedBox(height: 6),
                        Text(
                          'Net wealth ${taka(netWealth)} · nisab (${basis == 'gold' ? 'gold' : 'silver'}) ${taka(nisab)} · rate 2.5%',
                          style: TextStyle(fontSize: 11, color: kFg38),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['silver', 'gold'].map((b) {
                    final sel = basis == b;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: b == 'silver' ? 8 : 0),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: sel ? kEmerald.withValues(alpha: 0.14) : kFg.withValues(alpha: 0.04),
                            side: BorderSide(color: sel ? kEmerald : kFg12),
                            foregroundColor: sel ? kEmerald : kFg38,
                          ),
                          onPressed: () {
                            setState(() => basis = b);
                            _persist();
                          },
                          child: Text('${b == 'silver' ? '🥈 Silver' : '🥇 Gold'} nisab',
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: Text(
                    'Silver nisab ($_nisabSilverVori vori ≈ ${(_nisabSilverVori * _voriGrams).toStringAsFixed(0)}g) is the safer, lower threshold most commonly advised.',
                    style: TextStyle(fontSize: 10.5, color: kFg38),
                  ),
                ),
                _toggleRow('Cash & bank accounts', cash, includeCash, (v) => setState(() => includeCash = v)),
                _toggleRow('Savings balance', _savings, includeSavings, (v) => setState(() => includeSavings = v)),
                _toggleRow('Investments (current value)', _investments, includeInvestments,
                    (v) => setState(() => includeInvestments = v)),
                _toggleRow('Receivables (loans you gave)', _receivables, includeReceivables,
                    (v) => setState(() => includeReceivables = v)),
                _toggleRow('Deduct debts you owe', -_debts, deductDebts, (v) => setState(() => deductDebts = v)),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(children: [
                          Expanded(child: _field('Gold price/vori', goldPrice)),
                          const SizedBox(width: 10),
                          Expanded(child: _field('Silver price/vori', silverPrice)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _field('Gold owned (vori)', goldOwned)),
                          const SizedBox(width: 10),
                          Expanded(child: _field('Silver owned (vori)', silverOwned)),
                        ]),
                        const SizedBox(height: 10),
                        _field('Other zakatable assets (৳)', otherAssets),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Gold ${taka(goldValue)} · Silver ${taka(silverValue)} · Other ${taka(otherValue)}\nZakat rules vary by madhhab — confirm the details with your local scholar.',
                  style: TextStyle(fontSize: 10.5, color: kFg38),
                ),
              ],
            ),
    );
  }

  Widget _toggleRow(String label, double value, bool checked, ValueChanged<bool> onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: SwitchListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        subtitle: Text(taka(value.abs()), style: TextStyle(fontSize: 12, color: value < 0 ? kRed : kFg54)),
        value: checked,
        activeThumbColor: kEmerald,
        onChanged: (v) {
          onChanged(v);
          _persist();
        },
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
