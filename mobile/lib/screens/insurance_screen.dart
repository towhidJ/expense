import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _policyTypes = {
  'life': ('❤️', 'Life'),
  'health': ('🏥', 'Health'),
  'vehicle': ('🚗', 'Vehicle'),
  'property': ('🏠', 'Property'),
  'other': ('📋', 'Other'),
};

const _frequencies = {
  'monthly': 'Monthly',
  'quarterly': 'Quarterly',
  'half_yearly': 'Half-yearly',
  'yearly': 'Yearly',
};

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key, required this.state});
  final AppState state;

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  List<InsurancePolicy>? _policies;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.state.fetchInsurance();
    if (mounted) setState(() => _policies = rows);
  }

  Future<void> _edit([InsurancePolicy? p]) async {
    final name = TextEditingController(text: p?.name ?? '');
    final provider = TextEditingController(text: p?.provider ?? '');
    final policyNo = TextEditingController(text: p?.policyNumber ?? '');
    final coverage = TextEditingController(text: p == null || p.coverageAmount == 0 ? '' : p.coverageAmount.toStringAsFixed(0));
    final premium = TextEditingController(text: p == null ? '' : p.premiumAmount.toStringAsFixed(0));
    final notes = TextEditingController(text: p?.notes ?? '');
    String type = p?.type ?? 'life';
    String frequency = p?.premiumFrequency ?? 'yearly';
    DateTime? nextPremium = p?.nextPremiumDate;
    DateTime? maturity = p?.maturityDate;
    bool isActive = p?.isActive ?? true;
    bool busy = false;

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
                Text(p == null ? 'New Policy' : 'Edit Policy',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Policy name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _policyTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value.$1} ${e.value.$2}')))
                      .toList(),
                  onChanged: (v) => setSheet(() => type = v ?? 'other'),
                ),
                const SizedBox(height: 12),
                TextField(controller: provider, decoration: const InputDecoration(labelText: 'Company / provider')),
                const SizedBox(height: 12),
                TextField(controller: policyNo, decoration: const InputDecoration(labelText: 'Policy number')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: coverage,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Coverage (৳)'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: premium,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Premium (৳)'))),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Premium frequency'),
                  items: _frequencies.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) => setSheet(() => frequency = v ?? 'yearly'),
                ),
                const SizedBox(height: 12),
                _dateTile(sheetContext, 'Next premium date', nextPremium, (d) => setSheet(() => nextPremium = d)),
                _dateTile(sheetContext, 'Maturity date', maturity, (d) => setSheet(() => maturity = d)),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active policy', style: TextStyle(fontSize: 14)),
                  value: isActive,
                  activeThumbColor: kCyan,
                  onChanged: (v) => setSheet(() => isActive = v),
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: 'Save Policy',
                  busy: busy,
                  onPressed: () async {
                    final prem = double.tryParse(premium.text.trim());
                    if (name.text.trim().isEmpty || prem == null) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.upsertInsurance(
                        id: p?.id,
                        name: name.text.trim(),
                        type: type,
                        provider: provider.text.trim(),
                        policyNumber: policyNo.text.trim(),
                        coverageAmount: double.tryParse(coverage.text.trim()) ?? 0,
                        premiumAmount: prem,
                        premiumFrequency: frequency,
                        nextPremiumDate: nextPremium,
                        maturityDate: maturity,
                        notes: notes.text.trim(),
                        isActive: isActive,
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Widget _dateTile(BuildContext ctx, String label, DateTime? value, ValueChanged<DateTime?> onPicked) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontSize: 13, color: kFg54)),
      trailing: Text(value == null ? 'Not set' : DateFormat('MMM d, yyyy').format(value),
          style: TextStyle(fontSize: 13, color: value == null ? kFg38 : kFg)),
      onTap: () async {
        final picked = await showDatePicker(
          context: ctx,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        onPicked(picked ?? value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final policies = _policies;
    final active = policies?.where((p) => p.isActive).toList() ?? [];
    final yearly = active.fold<double>(0, (s, p) => s + p.yearlyPremium);
    final soon = DateTime.now().add(const Duration(days: 30));
    final dueSoon = active
        .where((p) => p.nextPremiumDate != null && p.nextPremiumDate!.isBefore(soon))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Insurance', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        backgroundColor: kPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: policies == null
          ? const Center(child: CircularProgressIndicator(color: kPurple))
          : RefreshIndicator(
              color: kPurple,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Row(children: [
                    Expanded(child: _stat('Active Policies', '${active.length}', kPurple)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Premium / Year', taka(yearly), kOrange)),
                  ]),
                  if (dueSoon.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('⚠️ Premium due within 30 days',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kOrange)),
                            const SizedBox(height: 6),
                            ...dueSoon.map((p) => Text(
                                '${p.name} — ${taka(p.premiumAmount)} on ${DateFormat('MMM d').format(p.nextPremiumDate!)}',
                                style: TextStyle(fontSize: 12, color: kFg54))),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (policies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(child: Text('No policies yet — add the first one.', style: TextStyle(color: kFg38))),
                    ),
                  ...policies.map((p) {
                    final overdue = p.isActive && p.nextPremiumDate != null && p.nextPremiumDate!.isBefore(DateTime.now());
                    final meta = _policyTypes[p.type] ?? _policyTypes['other']!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: Text(meta.$1, style: const TextStyle(fontSize: 22)),
                          title: Text('${p.name}${p.isActive ? '' : ' (inactive)'}', style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${p.provider.isNotEmpty ? '${p.provider} · ' : ''}${taka(p.premiumAmount)}/${_frequencies[p.premiumFrequency]?.toLowerCase() ?? p.premiumFrequency}'
                            '${p.nextPremiumDate != null ? ' · next ${DateFormat('MMM d').format(p.nextPremiumDate!)}${overdue ? ' ⚠️' : ''}' : ''}'
                            '${p.coverageAmount > 0 ? '\nCoverage ${taka(p.coverageAmount)}' : ''}',
                            style: TextStyle(fontSize: 11, color: overdue ? kRed : kFg38),
                          ),
                          isThreeLine: p.coverageAmount > 0,
                          trailing: PopupMenuButton<String>(
                            color: kCard,
                            icon: Icon(Icons.more_vert, color: kFg38, size: 20),
                            onSelected: (v) async {
                              if (v == 'edit') _edit(p);
                              if (v == 'delete') {
                                try {
                                  await widget.state.deleteInsurance(p.id);
                                  _load();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

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
