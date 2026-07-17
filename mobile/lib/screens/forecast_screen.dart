import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// 6-month cashflow projection from trailing monthly averages. Recurring
/// items auto-post into transactions, so the averages already include them —
/// the recurring totals are shown as info, never added on top (web parity).
class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _MonthTotal {
  _MonthTotal(this.name);
  final String name;
  double income = 0;
  double expense = 0;
}

class _ForecastScreenState extends State<ForecastScreen> {
  List<Map<String, dynamic>>? _txSlice;
  List<Recurring> _recurring = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = DateTime(DateTime.now().year, DateTime.now().month - 6, 1);
    final results = await Future.wait([
      widget.state.fetchTxSlice(start),
      widget.state.fetchRecurring(),
    ]);
    if (mounted) {
      setState(() {
        _txSlice = results[0] as List<Map<String, dynamic>>;
        _recurring = (results[1] as List<Recurring>).where((r) => r.isActive).toList();
      });
    }
  }

  // Last 7 calendar months (6 past + current) with income/expense totals.
  List<_MonthTotal> get _history {
    final now = DateTime.now();
    final months = <String, _MonthTotal>{};
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      months[key] = _MonthTotal(DateFormat('MMM yy').format(d));
    }
    for (final tx in _txSlice ?? <Map<String, dynamic>>[]) {
      final key = (tx['date'] as String?)?.substring(0, 7);
      final m = months[key];
      if (m == null) continue;
      final amt = (tx['amount'] as num?)?.toDouble() ?? 0;
      if (tx['type'] == 'income') {
        m.income += amt;
      } else if (tx['type'] == 'expense') {
        m.expense += amt;
      }
    }
    return months.values.toList();
  }

  // Average over up to the last 3 FULL months with activity (partial current
  // month excluded unless it's all we have).
  ({double income, double expense, int sampleSize}) _averages(List<_MonthTotal> history) {
    final full = history.sublist(0, history.length - 1).where((m) => m.income > 0 || m.expense > 0).toList();
    final sample = full.length > 3 ? full.sublist(full.length - 3) : full;
    final base = sample.isNotEmpty ? sample : [history.last];
    final income = base.fold<double>(0, (s, m) => s + m.income) / base.length;
    final expense = base.fold<double>(0, (s, m) => s + m.expense) / base.length;
    return (income: income, expense: expense, sampleSize: sample.length);
  }

  @override
  Widget build(BuildContext context) {
    if (_txSlice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cashflow Forecast', style: TextStyle(fontWeight: FontWeight.bold))),
        body: const Center(child: CircularProgressIndicator(color: kCyan)),
      );
    }
    final history = _history;
    final avg = _averages(history);
    final currentBalance = sumBdt(widget.state.accounts);
    final monthlyNet = avg.income - avg.expense;

    // 6 future months projection
    final now = DateTime.now();
    final projection = List.generate(6, (i) {
      final d = DateTime(now.year, now.month + i + 1, 1);
      return (
        name: DateFormat('MMM yy').format(d),
        balance: currentBalance + monthlyNet * (i + 1),
      );
    });

    double recIncome = 0, recExpense = 0;
    for (final r in _recurring) {
      if (r.type == 'income') {
        recIncome += r.monthlyAmount;
      } else {
        recExpense += r.monthlyAmount;
      }
    }

    final spots = <FlSpot>[
      FlSpot(0, currentBalance),
      ...projection.asMap().entries.map((e) => FlSpot(e.key + 1.0, e.value.balance)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cashflow Forecast', style: TextStyle(fontWeight: FontWeight.bold))),
      body: RefreshIndicator(
        color: kCyan,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(children: [
              Expanded(child: _stat('Avg income/mo', taka(avg.income), kEmerald)),
              const SizedBox(width: 8),
              Expanded(child: _stat('Avg expense/mo', taka(avg.expense), kRed)),
              const SizedBox(width: 8),
              Expanded(
                  child: _stat('Net/mo', '${monthlyNet >= 0 ? '+' : '−'}${taka(monthlyNet.abs())}',
                      monthlyNet >= 0 ? kCyan : kRed)),
            ]),
            const SizedBox(height: 6),
            Text(
              avg.sampleSize > 0
                  ? 'Based on your last ${avg.sampleSize} full month${avg.sampleSize > 1 ? 's' : ''} (recurring already included).'
                  : 'Not enough history yet — based on the current month only.',
              style: TextStyle(fontSize: 10.5, color: kFg38),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 10),
                      child: Text('Projected balance — next 6 months',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kFg70)),
                    ),
                    SizedBox(
                      height: 190,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (v) => FlLine(color: kFg.withValues(alpha: 0.05), strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 44,
                                getTitlesWidget: (v, _) => Text(
                                  v.abs() >= 100000
                                      ? '${(v / 100000).toStringAsFixed(1)}L'
                                      : '${(v / 1000).toStringAsFixed(0)}k',
                                  style: TextStyle(fontSize: 9, color: kFg38),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (v, _) {
                                  final i = v.toInt();
                                  final label = i == 0 ? 'Now' : (i - 1 < projection.length ? projection[i - 1].name : '');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(label, style: TextStyle(fontSize: 8.5, color: kFg38)),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: kCyan,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(show: true, color: kCyan.withValues(alpha: 0.08)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...projection.map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(p.name, style: const TextStyle(fontSize: 13.5)),
                    trailing: Text(taka(p.balance),
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: p.balance >= 0 ? kEmerald : kRed)),
                  ),
                )),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active recurring commitments (info — already inside the averages)',
                        style: TextStyle(fontSize: 11.5, color: kFg54)),
                    const SizedBox(height: 6),
                    Text('Income ${taka(recIncome)}/mo · Expense ${taka(recExpense)}/mo',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, color: kFg38), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
