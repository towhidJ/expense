import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

String _monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-01';
String _monthLabel(String key, [String pattern = 'MMM yy']) => DateFormat(pattern).format(DateTime.parse(key));

/// Rent management (v35 + v38): partial payments, charge itemization, rent
/// revisions, tenant history, unit expenses and end-tenancy advance settlement.
class RentScreen extends StatefulWidget {
  const RentScreen({super.key, required this.state});
  final AppState state;

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  List<RentalUnit>? _units;
  List<RentPayment> _payments = [];
  List<RentRevision> _revisions = [];
  List<UnitTenancy> _tenancies = [];
  List<RentUnitExpense> _expenses = [];
  String? _expandedUnitId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (units, payments, revisions, tenancies, expenses) = await widget.state.fetchRentData();
    if (mounted) {
      setState(() {
        _units = units;
        _payments = payments;
        _revisions = revisions;
        _tenancies = tenancies;
        _expenses = expenses;
      });
    }
  }

  // ---- derived helpers ----

  List<String> get _last12Months {
    final now = DateTime.now();
    return List.generate(12, (i) => _monthKey(DateTime(now.year, now.month - i, 1)));
  }

  String get _thisMonth => _monthKey(DateTime.now());

  double _expectedRent(RentalUnit unit, String monthKey) {
    for (final r in _revisions) {
      // _revisions come sorted by effective_from desc
      if (r.unitId == unit.id && r.effectiveFrom.compareTo(monthKey) <= 0) return r.monthlyRent;
    }
    return unit.monthlyRent;
  }

  List<RentPayment> _monthPayments(RentalUnit unit, String monthKey) =>
      _payments.where((p) => p.unitId == unit.id && p.rentMonth == monthKey).toList();

  double _monthPaid(RentalUnit unit, String monthKey) =>
      _monthPayments(unit, monthKey).fold(0, (s, p) => s + p.amount);

  /// Unpaid months (12-month window): list of (monthKey, dueAmount).
  List<(String, double)> _dueMonths(RentalUnit unit) {
    final startKey = unit.rentStart == null ? null : _monthKey(DateTime(unit.rentStart!.year, unit.rentStart!.month, 1));
    final out = <(String, double)>[];
    for (final m in _last12Months) {
      if (m.compareTo(_thisMonth) > 0) continue;
      if (startKey != null && m.compareTo(startKey) < 0) continue;
      final due = _expectedRent(unit, m) - _monthPaid(unit, m);
      if (due > 0) out.add((m, due));
    }
    return out;
  }

  // ---- unit form ----

  Future<void> _editUnit([RentalUnit? unit]) async {
    final name = TextEditingController(text: unit?.name ?? '');
    final tenant = TextEditingController(text: unit?.tenantName ?? '');
    final phone = TextEditingController(text: unit?.tenantPhone ?? '');
    final rent = TextEditingController(text: unit == null ? '' : unit.monthlyRent.toStringAsFixed(0));
    final advance = TextEditingController(
        text: unit == null || unit.advanceDeposit == 0 ? '' : unit.advanceDeposit.toStringAsFixed(0));
    DateTime? rentStart = unit?.rentStart;
    DateTime rentEffective = DateTime(DateTime.now().year, DateTime.now().month, 1);
    bool isActive = unit?.isActive ?? true;
    bool busy = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final rentChanged = unit != null && double.tryParse(rent.text.trim()) != unit.monthlyRent;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(unit == null ? 'New Rental Unit' : 'Edit Unit',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Unit name', hintText: 'e.g. 2nd Floor Flat-A')),
                  const SizedBox(height: 12),
                  TextField(controller: tenant, decoration: const InputDecoration(labelText: 'Tenant name')),
                  const SizedBox(height: 12),
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Tenant phone')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: rent,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Monthly rent (৳)'),
                        onChanged: (_) => setSheet(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: advance,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Advance (৳)'),
                      ),
                    ),
                  ]),
                  if (rentChanged)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('New rent effective from', style: TextStyle(fontSize: 13, color: kFg54)),
                      subtitle: Text('Older months keep the previous rent in dues.',
                          style: TextStyle(fontSize: 10.5, color: kFg38)),
                      trailing: Text(DateFormat('MMMM yyyy').format(rentEffective),
                          style: TextStyle(fontSize: 13, color: kFg)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: rentEffective,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setSheet(() => rentEffective = DateTime(picked.year, picked.month, 1));
                      },
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Rent since', style: TextStyle(fontSize: 13, color: kFg54)),
                    trailing: Text(rentStart == null ? 'Not set' : DateFormat('MMM d, yyyy').format(rentStart!),
                        style: TextStyle(fontSize: 13, color: rentStart == null ? kFg38 : kFg)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: rentStart ?? DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setSheet(() => rentStart = picked);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Currently rented', style: TextStyle(fontSize: 14)),
                    value: isActive,
                    activeThumbColor: kCyan,
                    onChanged: (v) => setSheet(() => isActive = v),
                  ),
                  const SizedBox(height: 8),
                  GradientButton(
                    label: 'Save Unit',
                    busy: busy,
                    onPressed: () async {
                      final rentAmt = double.tryParse(rent.text.trim());
                      if (name.text.trim().isEmpty || rentAmt == null) return;
                      setSheet(() => busy = true);
                      try {
                        final unitId = await widget.state.upsertRentalUnit(
                          id: unit?.id,
                          name: name.text.trim(),
                          tenantName: tenant.text.trim(),
                          tenantPhone: phone.text.trim(),
                          monthlyRent: rentAmt,
                          advanceDeposit: double.tryParse(advance.text.trim()) ?? 0,
                          rentStart: rentStart,
                          notes: unit?.notes ?? '',
                          isActive: isActive,
                        );
                        if (unit == null) {
                          final eff = rentStart ?? DateTime.now();
                          await widget.state.saveRentRevision(
                              unitId: unitId,
                              effectiveFrom: _monthKey(DateTime(eff.year, eff.month, 1)),
                              monthlyRent: rentAmt);
                        } else if (rentAmt != unit.monthlyRent) {
                          await widget.state.saveRentRevision(
                              unitId: unit.id, effectiveFrom: _monthKey(rentEffective), monthlyRent: rentAmt);
                        }
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
          );
        },
      ),
    );
    if (saved == true) _load();
  }

  // ---- collect (partial + charges) ----

  Future<void> _collect(RentalUnit unit, String monthKey) async {
    final expected = _expectedRent(unit, monthKey);
    final paid = _monthPaid(unit, monthKey);
    final remaining = (expected - paid).clamp(0, double.infinity).toDouble();
    final amount = TextEditingController(
        text: (remaining > 0 ? remaining : expected).toStringAsFixed(0));
    final charge = TextEditingController();
    final chargeNote = TextEditingController();
    DateTime date = DateTime.now();
    bool logIncome = true;
    String? accountId;
    String? categoryId;
    bool busy = false;
    final incomeCategories = widget.state.categories.where((c) => c.type == 'income').toList();

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
                const Text('Collect Rent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${unit.name} — ${_monthLabel(monthKey, 'MMMM yyyy')}${unit.tenantName != null ? ' · ${unit.tenantName}' : ''}\n'
                  'Expected ${taka(expected)} · already received ${taka(paid)} — partial amounts are fine.',
                  style: TextStyle(fontSize: 12, color: kFg54),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount received (total ৳)'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: charge,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Incl. charges (৳)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: chargeNote,
                      decoration: const InputDecoration(labelText: 'Charge note', hintText: 'gas/water/service'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date received', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(DateFormat('MMM d, yyyy').format(date), style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Log as income (adds to account balance)', style: TextStyle(fontSize: 13.5)),
                  value: logIncome,
                  activeThumbColor: kCyan,
                  onChanged: (v) => setSheet(() => logIncome = v),
                ),
                if (logIncome) ...[
                  DropdownButtonFormField<String>(
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Deposit to account'),
                    items: widget.state.accounts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                        .toList(),
                    onChanged: (v) => setSheet(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Income category'),
                    items: incomeCategories
                        .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                        .toList(),
                    onChanged: (v) => setSheet(() => categoryId = v),
                  ),
                ],
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Record Payment',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    final chg = double.tryParse(charge.text.trim()) ?? 0;
                    if (amt == null || amt <= 0) return;
                    if (chg > amt) return;
                    if (logIncome && (accountId == null || categoryId == null)) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.collectRent(
                        unit: unit,
                        rentMonth: monthKey,
                        amount: amt,
                        chargeAmount: chg,
                        chargeNote: chargeNote.text.trim(),
                        date: date,
                        accountId: logIncome ? accountId : null,
                        categoryId: logIncome ? categoryId : null,
                        description: 'Rent — ${unit.name} (${_monthLabel(monthKey, 'MMMM yyyy')})',
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

  // ---- month detail (payments of a month) ----

  Future<void> _showMonth(RentalUnit unit, String monthKey) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final list = _monthPayments(unit, monthKey);
          final expected = _expectedRent(unit, monthKey);
          final paid = list.fold<double>(0, (s, p) => s + p.amount);
          final remaining = (expected - paid).clamp(0, double.infinity).toDouble();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_monthLabel(monthKey, 'MMMM yyyy'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${unit.name} · expected ${taka(expected)} · received ${taka(paid)}'
                  '${remaining > 0 ? ' · ${taka(remaining)} due' : ''}',
                  style: TextStyle(fontSize: 12.5, color: remaining > 0 ? kOrange : kFg54),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('No payments recorded for this month.', style: TextStyle(color: kFg38, fontSize: 13)),
                  ),
                ...list.map((p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${taka(p.amount)}${p.chargeAmount > 0 ? ' (incl. ${taka(p.chargeAmount)} ${p.chargeNote.isEmpty ? 'charges' : p.chargeNote})' : ''}',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${DateFormat('MMM d, yyyy').format(p.paidDate)}${p.transactionId != null ? ' · in accounts' : ''}',
                          style: TextStyle(fontSize: 11, color: kFg38),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: kRed),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: sheetContext,
                              builder: (context) => AlertDialog(
                                title: Text('Remove this ${taka(p.amount)} payment record?'),
                                content: const Text('Any linked income transaction stays.',
                                    style: TextStyle(fontSize: 13)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Remove', style: TextStyle(color: kRed))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await widget.state.deleteRentPayment(p.id);
                              await _load();
                              setSheet(() {});
                            }
                          },
                        ),
                      ),
                    )),
                const SizedBox(height: 8),
                GradientButton(
                  label: remaining > 0 ? 'Collect ${taka(remaining)}' : 'Collect More',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _collect(unit, monthKey);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- end tenancy: advance settlement ----

  Future<void> _endTenancy(RentalUnit unit) async {
    final duesPrefill = _dueMonths(unit).fold<double>(0, (s, m) => s + m.$2);
    final dues = TextEditingController(text: duesPrefill > 0 ? duesPrefill.toStringAsFixed(0) : '');
    final notes = TextEditingController();
    DateTime endDate = DateTime.now();
    bool logRefund = true;
    bool logDuesIncome = false;
    String? accountId;
    String? categoryId;
    String? duesCategoryId;
    bool busy = false;
    final incomeCategories = widget.state.categories.where((c) => c.type == 'income').toList();
    final expenseCategories = widget.state.categories.where((c) => c.type == 'expense').toList();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final advance = unit.advanceDeposit;
          final d = double.tryParse(dues.text.trim()) ?? 0;
          final deducted = d < advance ? d : advance;
          final refund = (advance - d) > 0 ? advance - d : 0.0;
          final shortfall = (d - advance) > 0 ? d - advance : 0.0;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('End Tenancy — ${unit.name}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${unit.tenantName ?? 'Tenant'} is leaving. Settle dues against the advance deposit.',
                      style: TextStyle(fontSize: 12.5, color: kFg54)),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Leaving date', style: TextStyle(fontSize: 13, color: kFg54)),
                    trailing: Text(DateFormat('MMM d, yyyy').format(endDate), style: TextStyle(fontSize: 13, color: kFg)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setSheet(() => endDate = picked);
                    },
                  ),
                  TextField(
                    controller: dues,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Unpaid dues (৳)',
                      helperText: 'Pre-filled from unpaid months — adjust if needed.',
                    ),
                    onChanged: (_) => setSheet(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kFg.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kFg12),
                    ),
                    child: Column(children: [
                      _settleRow('Advance held', taka(advance), kFg70),
                      _settleRow('Dues deducted from advance', '− ${taka(deducted)}', kOrange),
                      Divider(color: kFg12, height: 14),
                      _settleRow('Advance to return', taka(refund), kEmerald, bold: true),
                      if (shortfall > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Dues exceed the advance — tenant still owes ${taka(shortfall)}. Collect it separately (Dena-Paona is handy).',
                            style: const TextStyle(fontSize: 11, color: kRed),
                          ),
                        ),
                    ]),
                  ),
                  if (refund > 0) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Log the ${taka(refund)} refund as an expense', style: const TextStyle(fontSize: 13)),
                      subtitle: Text('Cash leaves an account', style: TextStyle(fontSize: 11, color: kFg38)),
                      value: logRefund,
                      activeThumbColor: kCyan,
                      onChanged: (v) => setSheet(() => logRefund = v),
                    ),
                    if (logRefund) ...[
                      DropdownButtonFormField<String>(
                        dropdownColor: kCard,
                        decoration: const InputDecoration(labelText: 'Refund from account'),
                        items: widget.state.accounts
                            .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                            .toList(),
                        onChanged: (v) => setSheet(() => accountId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        dropdownColor: kCard,
                        decoration: const InputDecoration(labelText: 'Expense category'),
                        items: expenseCategories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                            .toList(),
                        onChanged: (v) => setSheet(() => categoryId = v),
                      ),
                    ],
                  ],
                  if (deducted > 0)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Log the ${taka(deducted)} kept dues as rent income',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('Memo entry — no account movement', style: TextStyle(fontSize: 11, color: kFg38)),
                      value: logDuesIncome,
                      activeThumbColor: kCyan,
                      onChanged: (v) => setSheet(() => logDuesIncome = v),
                    ),
                  if (deducted > 0 && logDuesIncome)
                    DropdownButtonFormField<String>(
                      dropdownColor: kCard,
                      decoration: const InputDecoration(labelText: 'Income category'),
                      items: incomeCategories
                          .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                          .toList(),
                      onChanged: (v) => setSheet(() => duesCategoryId = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes', hintText: 'condition of flat, keys returned…')),
                  const SizedBox(height: 8),
                  Text('The tenant moves to this unit\'s history, and the unit becomes vacant.',
                      style: TextStyle(fontSize: 11, color: kFg38)),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: 'End Tenancy & Settle',
                    busy: busy,
                    onPressed: () async {
                      if (logRefund && refund > 0 && (accountId == null || categoryId == null)) return;
                      if (logDuesIncome && deducted > 0 && duesCategoryId == null) return;
                      setSheet(() => busy = true);
                      try {
                        await widget.state.endTenancy(
                          unit: unit,
                          endDate: endDate,
                          dues: d,
                          currentRent: _expectedRent(unit, _thisMonth),
                          refundAccountId: logRefund && refund > 0 ? accountId : null,
                          refundCategoryId: logRefund && refund > 0 ? categoryId : null,
                          duesIncomeCategoryId: logDuesIncome && deducted > 0 ? duesCategoryId : null,
                          notes: notes.text.trim(),
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
          );
        },
      ),
    );
    if (saved == true) _load();
  }

  Widget _settleRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: kFg54)),
          Text(value,
              style: TextStyle(fontSize: 12.5, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  // ---- unit expense ----

  Future<void> _addExpense(RentalUnit unit) async {
    final amount = TextEditingController();
    final desc = TextEditingController();
    DateTime date = DateTime.now();
    bool payFromAccount = false;
    String? accountId;
    String? categoryId;
    bool busy = false;
    final expenseCategories = widget.state.categories.where((c) => c.type == 'expense').toList();

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
                Text('Unit Expense — ${unit.name}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description', hintText: 'Repair, paint, motor…')),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(DateFormat('MMM d, yyyy').format(date), style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pay from account (logs an expense)', style: TextStyle(fontSize: 13.5)),
                  value: payFromAccount,
                  activeThumbColor: kCyan,
                  onChanged: (v) => setSheet(() => payFromAccount = v),
                ),
                if (payFromAccount) ...[
                  DropdownButtonFormField<String>(
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: widget.state.accounts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${taka(a.currentBalance)})')))
                        .toList(),
                    onChanged: (v) => setSheet(() => accountId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Expense category'),
                    items: expenseCategories
                        .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                        .toList(),
                    onChanged: (v) => setSheet(() => categoryId = v),
                  ),
                ],
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Add Expense',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (amt == null || amt <= 0) return;
                    if (payFromAccount && (accountId == null || categoryId == null)) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.addRentUnitExpense(
                        unitId: unit.id,
                        unitName: unit.name,
                        date: date,
                        amount: amt,
                        description: desc.text.trim(),
                        accountId: payFromAccount ? accountId : null,
                        categoryId: payFromAccount ? categoryId : null,
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

  // ---- WhatsApp reminder ----

  Future<void> _sendWhatsApp(RentalUnit unit) async {
    final dues = _dueMonths(unit);
    if (dues.isEmpty || unit.tenantPhone == null) return;
    var digits = unit.tenantPhone!.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = '88$digits';
    final list = dues.map((m) => '${_monthLabel(m.$1)} ${taka(m.$2)}').join(', ');
    final total = dues.fold<double>(0, (s, m) => s + m.$2);
    final msg =
        'আসসালামু আলাইকুম${unit.tenantName != null ? ' ${unit.tenantName}' : ''}, ${unit.name} এর ভাড়া বাকি আছে: $list। মোট ${taka(total)}। দয়া করে পরিশোধ করবেন। ধন্যবাদ।';
    final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(msg)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
      }
    }
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final units = _units;
    final activeUnits = (units ?? []).where((u) => u.isActive).toList();
    final expectedMonthly = activeUnits.fold<double>(0, (s, u) => s + _expectedRent(u, _thisMonth));
    final collectedThisMonth =
        _payments.where((p) => p.rentMonth == _thisMonth).fold<double>(0, (s, p) => s + p.amount);
    final advanceHeld = activeUnits.fold<double>(0, (s, u) => s + u.advanceDeposit);
    final dueCount = activeUnits.where((u) => _monthPaid(u, _thisMonth) < _expectedRent(u, _thisMonth)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Rent', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editUnit(),
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_home_outlined),
      ),
      body: units == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : RefreshIndicator(
              color: const Color(0xFF14B8A6),
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  Row(children: [
                    Expanded(child: _stat('Expected/mo', taka(expectedMonthly), kEmerald)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _stat('Collected${dueCount > 0 ? ' ($dueCount due)' : ''}',
                            taka(collectedThisMonth), dueCount > 0 ? kOrange : kEmerald)),
                    const SizedBox(width: 8),
                    Expanded(child: _stat('Advance held', taka(advanceHeld), kPurple)),
                  ]),
                  const SizedBox(height: 14),
                  if (units.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No rental units.\nAdd flats/shops you rent out and track collection.',
                              textAlign: TextAlign.center, style: TextStyle(color: kFg38))),
                    ),
                  ...units.map(_unitCard),
                ],
              ),
            ),
    );
  }

  Widget _unitCard(RentalUnit unit) {
    final dues = _dueMonths(unit);
    final duesTotal = dues.fold<double>(0, (s, m) => s + m.$2);
    final expanded = _expandedUnitId == unit.id;
    final history = _tenancies.where((t) => t.unitId == unit.id).toList();
    final unitExpenses = _expenses.where((x) => x.unitId == unit.id).toList();
    final collectedAll = _payments.where((p) => p.unitId == unit.id).fold<double>(0, (s, p) => s + p.amount);
    final expensesAll = unitExpenses.fold<double>(0, (s, x) => s + x.amount);
    const teal = Color(0xFF14B8A6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Opacity(
          opacity: unit.isActive ? 1 : 0.65,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.home_outlined, color: teal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${unit.name} · ${taka(_expectedRent(unit, _thisMonth))}/mo',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(
                            '${unit.tenantName ?? (unit.isActive ? 'No tenant' : 'Vacant')}'
                            '${unit.advanceDeposit > 0 ? ' · advance ${taka(unit.advanceDeposit)}' : ''}',
                            style: TextStyle(fontSize: 11, color: kFg38),
                          ),
                        ],
                      ),
                    ),
                    if (duesTotal > 0 && unit.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: kRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('DUE ${taka(duesTotal)}',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: kRed)),
                      ),
                    PopupMenuButton<String>(
                      color: kCard,
                      icon: Icon(Icons.more_vert, size: 20, color: kFg38),
                      onSelected: (v) async {
                        switch (v) {
                          case 'whatsapp':
                            _sendWhatsApp(unit);
                          case 'end':
                            _endTenancy(unit);
                          case 'edit':
                            _editUnit(unit);
                          case 'delete':
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete "${unit.name}" and its payment history?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: kRed))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              try {
                                await widget.state.deleteRentalUnit(unit.id);
                                _load();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                        }
                      },
                      itemBuilder: (_) => [
                        if (unit.isActive && duesTotal > 0 && unit.tenantPhone != null)
                          const PopupMenuItem(value: 'whatsapp', child: Text('💬 WhatsApp reminder')),
                        if (unit.isActive && unit.tenantName != null)
                          const PopupMenuItem(value: 'end', child: Text('🚪 End tenancy / settle advance')),
                        const PopupMenuItem(value: 'edit', child: Text('✏️ Edit unit')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _last12Months.reversed.map((m) {
                      final expected = _expectedRent(unit, m);
                      final paid = _monthPaid(unit, m);
                      final hasPayments = _monthPayments(unit, m).isNotEmpty;
                      final isFuture = m.compareTo(_thisMonth) > 0;
                      final beforeStart = unit.rentStart != null &&
                          m.compareTo(_monthKey(DateTime(unit.rentStart!.year, unit.rentStart!.month, 1))) < 0;
                      final full = expected > 0 ? paid >= expected : hasPayments;
                      final partial = paid > 0 && !full;
                      final disabled = isFuture || beforeStart || (!unit.isActive && !hasPayments);
                      final Color color = full
                          ? kEmerald
                          : partial
                              ? kOrange
                              : disabled
                                  ? kFg24
                                  : m == _thisMonth
                                      ? kOrange
                                      : kRed;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: disabled
                              ? null
                              : () => hasPayments ? _showMonth(unit, m) : _collect(unit, m),
                          child: Container(
                            width: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: disabled ? 0.05 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withValues(alpha: disabled ? 0.1 : 0.35)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_monthLabel(m, 'MMM'),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                                Text(full ? '✓' : partial ? 'part' : disabled ? '·' : 'due',
                                    style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _expandedUnitId = expanded ? null : unit.id),
                      icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: teal),
                      label: Text('Expenses & history', style: const TextStyle(fontSize: 11.5, color: teal)),
                    ),
                    const Spacer(),
                    if (unit.tenantPhone != null)
                      IconButton(
                        icon: Icon(Icons.phone_outlined, size: 17, color: kCyan.withValues(alpha: 0.8)),
                        onPressed: () => launchUrl(Uri.parse('tel:${unit.tenantPhone}')),
                      ),
                  ],
                ),
                if (expanded) ...[
                  Divider(color: kFg12, height: 8),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Expenses ${taka(expensesAll)} · net income ${taka(collectedAll - expensesAll)}',
                        style: TextStyle(fontSize: 11.5, color: kFg54),
                      ),
                      TextButton.icon(
                        onPressed: () => _addExpense(unit),
                        icon: const Icon(Icons.add, size: 14, color: teal),
                        label: const Text('Expense', style: TextStyle(fontSize: 11, color: teal)),
                      ),
                    ],
                  ),
                  ...unitExpenses.take(8).map((x) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${DateFormat('MMM d, yy').format(x.date)} · ${x.description.isEmpty ? 'Expense' : x.description}${x.transactionId == null ? ' (memo)' : ''}',
                                style: TextStyle(fontSize: 11, color: kFg38),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(taka(x.amount), style: const TextStyle(fontSize: 11.5, color: kRed)),
                            InkWell(
                              onTap: () async {
                                await widget.state.deleteRentUnitExpense(x.id);
                                _load();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(Icons.close, size: 13, color: kFg24),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  Text('Past tenants', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kFg54)),
                  if (history.isEmpty)
                    Text('None yet — ending a tenancy archives the tenant here.',
                        style: TextStyle(fontSize: 10.5, color: kFg24)),
                  ...history.map((t) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${t.tenantName} · ${t.startDate != null ? DateFormat('MMM yy').format(t.startDate!) : '?'} → ${DateFormat('MMM yy').format(t.endDate)}'
                          ' · rent ${taka(t.monthlyRent)} · advance ${taka(t.advanceDeposit)}'
                          '${t.duesDeducted > 0 ? ' · dues kept ${taka(t.duesDeducted)}' : ''}'
                          '${t.advanceReturned > 0 ? ' · returned ${taka(t.advanceReturned)}' : ''}',
                          style: TextStyle(fontSize: 10.5, color: kFg38),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
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
            Text(label, style: TextStyle(fontSize: 10, color: kFg38), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
