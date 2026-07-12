import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Meal calendar (v19): the whole month in one grid — one row per day, one
/// column per member. Numbers are raw meal counts; +n is guest meals.
class MealCalendarScreen extends StatefulWidget {
  const MealCalendarScreen({
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
  State<MealCalendarScreen> createState() => _MealCalendarScreenState();
}

class _MealCalendarScreenState extends State<MealCalendarScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  List<MealEntry>? _entries;
  List<MealGroupMember> _members = [];
  List<MealHoliday> _holidays = [];
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    _month = widget.month;
    _load();
  }

  Future<void> _load() async {
    try {
      final start = DateTime(_year, _month, 1);
      final end = DateTime(_year, _month + 1, 1);
      final results = await Future.wait([
        state.fetchMealEntries(groupId, start, end),
        state.fetchMealMembers(groupId),
        state.fetchMealHolidays(groupId, start, end),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<MealEntry>;
        _members = results[1] as List<MealGroupMember>;
        _holidays = results[2] as List<MealHoliday>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _month = m;
      _year = y;
      _entries = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (entries == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal Calendar', style: TextStyle(fontWeight: FontWeight.bold))),
        body: const Center(child: CircularProgressIndicator(color: kCyan)),
      );
    }

    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final now = DateTime.now();

    // date -> member -> entry
    final entryMap = <String, Map<String, MealEntry>>{};
    for (final e in entries) {
      final key = '${e.date.year}-${e.date.month}-${e.date.day}';
      (entryMap[key] ??= {})[e.memberId] = e;
    }
    final holidayMap = <String, MealHoliday>{
      for (final h in _holidays) '${h.date.year}-${h.date.month}-${h.date.day}': h
    };

    final activeIds = entries.map((e) => e.memberId).toSet();
    final cols = _members
        .where((m) => m.status == 'approved' || activeIds.contains(m.id))
        .toList();

    final memberTotals = <String, double>{};
    double grandTotal = 0;

    final rows = <TableRow>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final key = '$_year-$_month-$day';
      final holiday = holidayMap[key];
      final isToday = now.year == _year && now.month == _month && now.day == day;
      double dayTotal = 0;

      final cells = <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$day'.padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday ? kCyan : null,
                  )),
              if (holiday != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.celebration, size: 12, color: kOrange),
              ],
            ],
          ),
        ),
      ];

      for (final m in cols) {
        final e = entryMap[key]?[m.id];
        final own = e == null ? 0.0 : e.breakfast + e.lunch + e.dinner;
        final guests = e == null ? 0.0 : e.guestBreakfast + e.guestLunch + e.guestDinner;
        dayTotal += own + guests;
        memberTotals[m.id] = (memberTotals[m.id] ?? 0) + own + guests;

        String text;
        Color? color;
        if (e == null) {
          text = '—';
          color = kFg24;
        } else if (own == 0 && guests == 0) {
          text = 'off';
          color = kRed.withValues(alpha: 0.6);
        } else {
          text = own % 1 == 0 ? own.toStringAsFixed(0) : own.toStringAsFixed(1);
          if (own == 0) text = '';
          if (guests > 0) text += ' +${guests.toStringAsFixed(0)}';
          color = null;
        }
        cells.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: color)),
        ));
      }
      grandTotal += dayTotal;
      cells.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          dayTotal > 0
              ? (dayTotal % 1 == 0 ? dayTotal.toStringAsFixed(0) : dayTotal.toStringAsFixed(1))
              : '',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, color: kFg54),
        ),
      ));

      rows.add(TableRow(
        decoration: BoxDecoration(
          color: holiday != null
              ? kOrange.withValues(alpha: 0.05)
              : isToday
                  ? kCyan.withValues(alpha: 0.05)
                  : null,
          border: Border(bottom: BorderSide(color: kFg.withValues(alpha: 0.05))),
        ),
        children: cells,
      ));
    }

    // totals row
    rows.add(TableRow(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: kFg.withValues(alpha: 0.15)))),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        ...cols.map((m) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Text(
                (memberTotals[m.id] ?? 0) % 1 == 0
                    ? (memberTotals[m.id] ?? 0).toStringAsFixed(0)
                    : (memberTotals[m.id] ?? 0).toStringAsFixed(1),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            grandTotal % 1 == 0 ? grandTotal.toStringAsFixed(0) : grandTotal.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kEmerald),
          ),
        ),
      ],
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () => _shiftMonth(-1), icon: Icon(Icons.chevron_left, color: kFg54)),
          Center(child: Text('$_month/$_year', style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(onPressed: () => _shiftMonth(1), icon: Icon(Icons.chevron_right, color: kFg54)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: kFg.withValues(alpha: 0.15)))),
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          child: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        ...cols.map((m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                              child: Text(
                                m.userId == state.uid ? '${m.displayName} •' : m.displayName,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: m.userId == state.uid ? kCyan : null,
                                ),
                              ),
                            )),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          child: Text('Total',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    ...rows,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Numbers are raw meal counts (breakfast + lunch + dinner); +n is guest meals, '
            '"off" means an entry exists with everything zero, — means no entry. '
            'Orange rows are holidays/feasts.',
            style: TextStyle(fontSize: 11, color: kFg38),
          ),
        ],
      ),
    );
  }
}
