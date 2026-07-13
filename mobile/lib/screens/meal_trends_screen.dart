import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'meals_screen.dart' show kMonthNames;

/// Trend charts (v24) + item price history (v25). Mirrors the web's
/// /meals/reports page.
class MealTrendsScreen extends StatefulWidget {
  const MealTrendsScreen({super.key, required this.state, required this.membership});
  final AppState state;
  final MealGroupMember membership;

  @override
  State<MealTrendsScreen> createState() => _MealTrendsScreenState();
}

class _MealTrendsScreenState extends State<MealTrendsScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  int _monthsBack = 6;
  List<MealTrendPoint>? _trend;
  List<String> _itemNames = [];
  String? _selectedItem;
  List<MealItemPricePoint>? _priceHistory;

  @override
  void initState() {
    super.initState();
    _loadTrend();
    state.fetchMealItemNames(groupId).then((names) {
      if (mounted) setState(() => _itemNames = names);
    }).catchError((_) {});
  }

  Future<void> _loadTrend() async {
    try {
      final rows = await state.fetchMealTrend(groupId, monthsBack: _monthsBack);
      if (mounted) setState(() => _trend = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _loadPriceHistory(String item) async {
    setState(() { _selectedItem = item; _priceHistory = null; });
    try {
      final rows = await state.fetchMealItemPriceHistory(groupId, item);
      if (mounted) setState(() => _priceHistory = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _monthLabel(MealTrendPoint p) => '${kMonthNames[p.month - 1].substring(0, 3)} ${p.year % 100}';

  @override
  Widget build(BuildContext context) {
    final trend = _trend;
    final topSpenders = (trend ?? []).where((p) => p.topSpenderName != null).toList();
    final maxBazar = (trend ?? []).fold<double>(0, (m, p) => p.totalBazar > m ? p.totalBazar : m);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Spend Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              DropdownButton<int>(
                value: _monthsBack,
                underline: const SizedBox.shrink(),
                items: const [3, 6, 12]
                    .map((n) => DropdownMenuItem(value: n, child: Text('Last $n months', style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _monthsBack = v);
                  _loadTrend();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
              child: SizedBox(
                height: 220,
                child: trend == null
                    ? const Center(child: CircularProgressIndicator(color: kCyan))
                    : trend.isEmpty
                        ? Center(child: Text('No data yet.', style: TextStyle(color: kFg38)))
                        : BarChart(BarChartData(
                            maxY: maxBazar <= 0 ? 100 : maxBazar * 1.2,
                            barTouchData: BarTouchData(enabled: true),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(_monthLabel(trend[i]), style: TextStyle(fontSize: 9, color: kFg38)),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              for (var i = 0; i < trend.length; i++)
                                BarChartGroupData(x: i, barRods: [
                                  BarChartRodData(toY: trend[i].totalBazar, color: kCyan, width: 12, borderRadius: BorderRadius.circular(3)),
                                ]),
                            ],
                          )),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Top Bazar Spender by Month', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: topSpenders.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No bazar expenses recorded yet.', style: TextStyle(fontSize: 12, color: kFg38)),
                  )
                : Column(
                    children: topSpenders
                        .map((p) => ListTile(
                              dense: true,
                              title: Text(_monthLabel(p), style: const TextStyle(fontSize: 13)),
                              trailing: Text('${p.topSpenderName} · ৳${p.topSpenderAmount?.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kCyan)),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 20),
          const Text('Item Price History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedItem,
            hint: const Text('Select an item...', style: TextStyle(fontSize: 13)),
            decoration: const InputDecoration(isDense: true),
            items: _itemNames.map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) { if (v != null) _loadPriceHistory(v); },
          ),
          const SizedBox(height: 8),
          if (_selectedItem != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 180,
                  child: _priceHistory == null
                      ? const Center(child: CircularProgressIndicator(color: kCyan))
                      : _priceHistory!.isEmpty
                          ? Center(child: Text('No priced entries for "$_selectedItem" yet.', style: TextStyle(fontSize: 12, color: kFg38)))
                          : LineChart(LineChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (var i = 0; i < _priceHistory!.length; i++)
                                      FlSpot(i.toDouble(), _priceHistory![i].amount),
                                  ],
                                  isCurved: true,
                                  color: kCyan,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: true),
                                ),
                              ],
                            )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
