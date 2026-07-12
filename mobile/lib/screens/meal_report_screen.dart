import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../pdf_export.dart';
import '../theme.dart';
import 'meals_screen.dart' show kMonthNames;

/// Printable monthly meal report — the mess's "voucher": totals + per-member
/// meals/deposit/cost/balance. Like voucher.dart, the white paper area is a
/// RepaintBoundary captured to PDF so Bangla text and ৳ print correctly.
class MealReportScreen extends StatefulWidget {
  const MealReportScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.year,
    required this.month,
  });
  final AppState state;
  final MealGroupMember membership;
  final int year;
  final int month;

  @override
  State<MealReportScreen> createState() => _MealReportScreenState();
}

class _MealReportScreenState extends State<MealReportScreen> {
  final _paperKey = GlobalKey();
  late int _year = widget.year;
  late int _month = widget.month;
  MealMonthSummary? _summary;
  MealGroup? _group;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.state.fetchMealMonthSummary(widget.membership.groupId, _year, _month),
        widget.state.fetchMealGroup(widget.membership.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as MealMonthSummary;
        _group = results[1] as MealGroup?;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m < 1) { m = 12; y--; } else if (m > 12) { m = 1; y++; }
    setState(() {
      _month = m;
      _year = y;
      _summary = null;
    });
    _load();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  String get _fileName =>
      'meal-report-$_year-${_month.toString().padLeft(2, '0')}.pdf';

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    // Fixed "paper" colors — stays black-on-white in dark mode.
    const ink = Color(0xFF111827);
    const inkSoft = Color(0xFF6B7280);
    const line = Color(0xFF64748B);
    final money = NumberFormat('#,##0.##');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
          Center(child: Text('${kMonthNames[_month - 1].substring(0, 3)} $_year',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCyan,
                    side: const BorderSide(color: kCyan),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share PDF'),
                  onPressed: _busy || s == null
                      ? null
                      : () => _run(() => exportBoundaryAsPdf(_paperKey, _fileName)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  label: '🖨️ Print',
                  busy: _busy,
                  onPressed: s == null
                      ? null
                      : () => _run(() => printBoundary(_paperKey, _fileName)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: _paperKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF374151), width: 2)),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFF1F2937), width: 2))),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              Text(_group?.name ?? 'Mess',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ink)),
                              const Text('Meal Management',
                                  style: TextStyle(fontSize: 10, color: inkSoft)),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF0891B2),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('MEAL REPORT — ${kMonthNames[_month - 1].toUpperCase()} $_year',
                                    style: const TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Totals
                        Table(
                          border: TableBorder.all(color: line),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                              children: ['Total Bazar', 'Total Meals', 'Meal Rate', 'Fixed Costs', 'Deposits']
                                  .map((h) => Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Text(h,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 8.5, fontWeight: FontWeight.bold, color: ink)),
                                      ))
                                  .toList(),
                            ),
                            TableRow(
                              children: [
                                '৳${money.format(s.totalBazar)}',
                                money.format(s.totalMeals),
                                '৳${money.format(s.mealRate)}',
                                '৳${money.format(s.totalFixed)}',
                                '৳${money.format(s.totalDeposits)}',
                              ]
                                  .map((v) => Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Text(v,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 9.5, color: ink)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Member table
                        Table(
                          border: TableBorder.all(color: line),
                          columnWidths: const {
                            0: FlexColumnWidth(2.2),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1.4),
                            3: FlexColumnWidth(1.4),
                            4: FlexColumnWidth(1.5),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
                              children: ['Member', 'Meals', 'Deposit', 'Cost', 'Balance']
                                  .map((h) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                        child: Text(h,
                                            style: const TextStyle(
                                                fontSize: 9, fontWeight: FontWeight.bold, color: ink)),
                                      ))
                                  .toList(),
                            ),
                            ...s.members.map((m) => TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      child: Text(m.displayName,
                                          style: const TextStyle(fontSize: 9.5, color: ink)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      child: Text(money.format(m.meals),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 9.5, color: ink)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      child: Text('৳${money.format(m.deposits)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 9.5, color: ink)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      child: Text('৳${money.format(m.totalCost)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 9.5, color: ink)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      child: Text(
                                        '৳${money.format(m.balance)}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: m.balance < 0
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF16A34A)),
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        ),
                        if (s.totalAdvance > 0) ...[
                          const SizedBox(height: 8),
                          Text('Advance (জামানত) held by the mess: ৳${money.format(s.totalAdvance)}',
                              style: const TextStyle(fontSize: 9, color: inkSoft)),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          'Balance = deposits − (meals × meal rate + fixed share). Negative balance is payable to the mess.',
                          style: TextStyle(fontSize: 8, color: inkSoft),
                        ),
                        const SizedBox(height: 28),
                        // Signatures
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ['Prepared By', 'Manager']
                              .map((label) => Column(
                                    children: [
                                      Container(width: 110, height: 1, color: const Color(0xFF9CA3AF)),
                                      const SizedBox(height: 4),
                                      Text(label, style: const TextStyle(fontSize: 9, color: inkSoft)),
                                    ],
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                            style: const TextStyle(fontSize: 7.5, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
