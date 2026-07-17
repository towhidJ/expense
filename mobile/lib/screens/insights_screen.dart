import 'package:flutter/material.dart';
import '../ai_service.dart';
import '../app_state.dart';
import '../theme.dart';

/// Client-side spending stats + an AI you can ask (gemini edge function,
/// aggregates only — no raw transaction dump leaves the device).
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _Finding {
  _Finding(this.up, this.text);
  final bool? up; // true = up/red, false = down/green, null = neutral
  final String text;
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<Map<String, dynamic>>? _tx;
  final _question = TextEditingController();
  final _chat = <(String role, String text)>[];
  bool _asking = false;
  final _scroll = ScrollController();

  static const _suggestions = [
    'How can I save more?',
    'Where did most of my money go?',
    'Is my spending trend healthy?',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = DateTime(DateTime.now().year, DateTime.now().month - 3, 1);
    final rows = await widget.state
        .fetchTxSlice(start, select: 'type, amount, date, description, categories(name, icon)');
    if (mounted) setState(() => _tx = rows);
  }

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  ({
    double expThis,
    double expLast,
    double incThis,
    List<(String, double)> topCats,
    List<_Finding> findings,
    double? savingsRate
  }) get _stats {
    final tx = _tx ?? [];
    final now = DateTime.now();
    final thisM = _monthKey(now);
    final lastM = _monthKey(DateTime(now.year, now.month - 1, 15));
    List<Map<String, dynamic>> inMonth(String m) =>
        tx.where((t) => (t['date'] as String?)?.startsWith(m) ?? false).toList();
    double sum(Iterable<Map<String, dynamic>> list) =>
        list.fold(0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0));
    final thisMonth = inMonth(thisM);
    final lastMonth = inMonth(lastM);
    final expThis = sum(thisMonth.where((t) => t['type'] == 'expense'));
    final expLast = sum(lastMonth.where((t) => t['type'] == 'expense'));
    final incThis = sum(thisMonth.where((t) => t['type'] == 'income'));

    String catName(Map<String, dynamic> t) {
      final c = t['categories'];
      return c == null ? 'Uncategorized' : '${c['icon'] ?? ''} ${c['name'] ?? ''}'.trim();
    }

    final catMap = <String, double>{};
    for (final t in thisMonth.where((t) => t['type'] == 'expense')) {
      catMap[catName(t)] = (catMap[catName(t)] ?? 0) + ((t['amount'] as num?)?.toDouble() ?? 0);
    }
    final topCats = catMap.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final top5 = topCats.take(5).toList();

    final catLast = <String, double>{};
    for (final t in lastMonth.where((t) => t['type'] == 'expense')) {
      catLast[catName(t)] = (catLast[catName(t)] ?? 0) + ((t['amount'] as num?)?.toDouble() ?? 0);
    }

    final findings = <_Finding>[];
    if (expLast > 0) {
      final change = (expThis - expLast) / expLast * 100;
      if (change.abs() >= 10) {
        findings.add(_Finding(change > 0,
            'Overall spending is ${change.abs().toStringAsFixed(0)}% ${change > 0 ? 'higher' : 'lower'} than last month (${taka(expThis)} vs ${taka(expLast)}).'));
      }
    }
    for (final (cat, amt) in top5) {
      final prev = catLast[cat] ?? 0;
      if (prev > 500 && amt > prev * 1.3) {
        findings.add(_Finding(true,
            '$cat jumped ${((amt - prev) / prev * 100).toStringAsFixed(0)}% — ${taka(amt)} this month vs ${taka(prev)} last month.'));
      } else if (prev > 500 && amt < prev * 0.7) {
        findings.add(_Finding(false, '$cat dropped to ${taka(amt)} from ${taka(prev)} — nice saving.'));
      }
    }
    double? savingsRate;
    if (incThis > 0) {
      savingsRate = (incThis - expThis) / incThis * 100;
      findings.add(_Finding(
          savingsRate >= 20 ? false : true,
          savingsRate >= 0
              ? "You're keeping ${savingsRate.toStringAsFixed(0)}% of this month's income (${taka(incThis - expThis)})."
              : "You've spent ${taka(expThis - incThis)} more than you earned this month."));
    }
    final expenses = thisMonth.where((t) => t['type'] == 'expense').toList()
      ..sort((a, b) => ((b['amount'] as num?) ?? 0).compareTo((a['amount'] as num?) ?? 0));
    if (expenses.isNotEmpty) {
      final biggest = expenses.first;
      final desc = (biggest['description'] as String?) ?? '';
      findings.add(_Finding(null,
          'Biggest single expense this month: ${taka((biggest['amount'] as num).toDouble())}${desc.isNotEmpty ? ' — $desc' : ''}.'));
    }
    if (findings.isEmpty) findings.add(_Finding(null, 'Not enough data this month yet — keep tracking!'));

    return (
      expThis: expThis,
      expLast: expLast,
      incThis: incThis,
      topCats: top5,
      findings: findings,
      savingsRate: savingsRate
    );
  }

  /// Compact aggregated context for the AI (numbers only, no raw dump) —
  /// same shape as the web Insights page.
  Map<String, dynamic> get _aiContext {
    final byMonth = <String, Map<String, double>>{};
    for (final t in _tx ?? <Map<String, dynamic>>[]) {
      final m = (t['date'] as String?)?.substring(0, 7);
      if (m == null) continue;
      final entry = byMonth.putIfAbsent(m, () => {'income': 0, 'expense': 0});
      final key = t['type'] == 'income' ? 'income' : 'expense';
      entry[key] = (entry[key] ?? 0) + ((t['amount'] as num?)?.toDouble() ?? 0);
    }
    final stats = _stats;
    return {
      'currency': 'BDT',
      'months': byMonth,
      'this_month_top_categories': {for (final (c, v) in stats.topCats) c: v},
      'savings_rate_pct': stats.savingsRate?.toStringAsFixed(1),
    };
  }

  Future<void> _ask([String? preset]) async {
    final text = (preset ?? _question.text).trim();
    if (text.isEmpty || _asking) return;
    setState(() {
      _question.clear();
      _chat.add(('user', text));
      _asking = true;
    });
    try {
      final result = await AiService.insights(_aiContext, text);
      setState(() => _chat.add(('ai', result['answer']?.toString() ?? result.toString())));
    } catch (e) {
      setState(() => _chat.add(('ai', '⚠️ $e')));
    }
    setState(() => _asking = false);
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final tx = _tx;
    final stats = tx == null ? null : _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold))),
      body: tx == null
          ? const Center(child: CircularProgressIndicator(color: kPurple))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("✨ This month's findings",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kPurple)),
                              const SizedBox(height: 8),
                              ...stats!.findings.map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          f.up == true
                                              ? Icons.trending_up
                                              : f.up == false
                                                  ? Icons.trending_down
                                                  : Icons.savings_outlined,
                                          size: 16,
                                          color: f.up == true ? kRed : f.up == false ? kEmerald : kCyan,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(f.text, style: TextStyle(fontSize: 12.5, color: kFg70))),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                      if (stats.topCats.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Top categories this month',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kFg70)),
                                const SizedBox(height: 8),
                                ...stats.topCats.map((c) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(children: [
                                        Expanded(child: Text(c.$1, style: TextStyle(fontSize: 12.5, color: kFg54))),
                                        Text(taka(c.$2),
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      ]),
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (_chat.isEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _suggestions
                              .map((s) => ActionChip(
                                    label: Text(s, style: TextStyle(fontSize: 11.5, color: kCyan)),
                                    backgroundColor: kCyan.withValues(alpha: 0.08),
                                    onPressed: () => _ask(s),
                                  ))
                              .toList(),
                        ),
                      ..._chat.map((m) {
                        final isUser = m.$1 == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            constraints:
                                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                            decoration: BoxDecoration(
                              color: isUser ? kCyan.withValues(alpha: 0.15) : kCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isUser ? kCyan.withValues(alpha: 0.25) : kFg12),
                            ),
                            child: Text(m.$2, style: TextStyle(fontSize: 13, color: kFg)),
                          ),
                        );
                      }),
                      if (_asking)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(children: [
                            const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kPurple)),
                            const SizedBox(width: 8),
                            Text('Thinking…', style: TextStyle(fontSize: 12, color: kFg38)),
                          ]),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _question,
                            decoration: const InputDecoration(hintText: 'Ask about your spending…', isDense: true),
                            onSubmitted: (_) => _ask(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _asking ? null : () => _ask(),
                          icon: const Icon(Icons.send, color: kPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
