import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Meal off / guest requests (v18): a member requests for themselves, the
/// manager approves (which writes the meal entry) or rejects. The group's
/// cutoff time is enforced by the submit RPC.
class MealRequestsScreen extends StatefulWidget {
  const MealRequestsScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealRequestsScreen> createState() => _MealRequestsScreenState();
}

class _MealRequestsScreenState extends State<MealRequestsScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  MealGroup? _group;
  List<MealRequest>? _requests;
  List<MealGroupMember> _members = [];
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    try {
      final start = DateTime(_year, _month, 1);
      final end = DateTime(_year, _month + 1, 1);
      final results = await Future.wait([
        state.fetchMealGroup(groupId),
        state.fetchMealRequests(groupId, start, end),
        state.fetchMealMembers(groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _group = results[0] as MealGroup?;
        _requests = results[1] as List<MealRequest>;
        _members = results[2] as List<MealGroupMember>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _memberName(String memberId) {
    for (final m in _members) {
      if (m.id == memberId) return m.displayName;
    }
    return 'Member';
  }

  bool _isMine(MealRequest r) {
    for (final m in _members) {
      if (m.id == r.memberId) return m.userId == state.uid;
    }
    return false;
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
      _requests = null;
    });
    _load();
  }

  // ---- New request sheet ----

  Future<void> _newRequestSheet() async {
    var type = 'off';
    var date = DateTime.now().add(const Duration(days: 1));
    var offB = false, offL = false, offD = false;
    final gB = TextEditingController(text: '0');
    final gL = TextEditingController(text: '0');
    final gD = TextEditingController(text: '0');
    final note = TextEditingController();
    final cutoff = _group?.cutoffHHmm;

    final ok = await showModalBottomSheet<bool>(
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
                const Text('New Request', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                if (cutoff != null) ...[
                  const SizedBox(height: 4),
                  Text('Cutoff: requests for a date must be in by $cutoff the day before',
                      style: const TextStyle(fontSize: 11, color: kOrange)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Meal Off'),
                        selected: type == 'off',
                        selectedColor: kCyan.withValues(alpha: 0.2),
                        onSelected: (_) => setSheet(() => type = 'off'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Guest Meal'),
                        selected: type == 'guest',
                        selectedColor: kPurple.withValues(alpha: 0.2),
                        onSelected: (_) => setSheet(() => type = 'guest'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 18, color: kCyan),
                  title: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                const SizedBox(height: 8),
                if (type == 'off') ...[
                  const Text('Which meals are off?', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(label: const Text('Breakfast'), selected: offB, onSelected: (v) => setSheet(() => offB = v)),
                      FilterChip(label: const Text('Lunch'), selected: offL, onSelected: (v) => setSheet(() => offL = v)),
                      FilterChip(label: const Text('Dinner'), selected: offD, onSelected: (v) => setSheet(() => offD = v)),
                    ],
                  ),
                ] else ...[
                  const Text('Guests per meal', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: gB, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Breakfast'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: gL, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Lunch'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: gD, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dinner'))),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Send Request',
                  onPressed: () => Navigator.pop(sheetContext, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;

    final b = type == 'off' ? (offB ? 1.0 : 0.0) : (double.tryParse(gB.text) ?? 0);
    final l = type == 'off' ? (offL ? 1.0 : 0.0) : (double.tryParse(gL.text) ?? 0);
    final d = type == 'off' ? (offD ? 1.0 : 0.0) : (double.tryParse(gD.text) ?? 0);
    await _run(() => state.submitMealRequest(
          groupId: groupId,
          date: date,
          type: type,
          breakfast: b,
          lunch: l,
          dinner: d,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        ));
  }

  String _slotSummary(MealRequest r) {
    final parts = <String>[];
    if (r.breakfast > 0) parts.add(r.type == 'guest' ? 'Breakfast ×${r.breakfast.toStringAsFixed(0)}' : 'Breakfast');
    if (r.lunch > 0) parts.add(r.type == 'guest' ? 'Lunch ×${r.lunch.toStringAsFixed(0)}' : 'Lunch');
    if (r.dinner > 0) parts.add(r.type == 'guest' ? 'Dinner ×${r.dinner.toStringAsFixed(0)}' : 'Dinner');
    return parts.join(', ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return kEmerald;
      case 'rejected':
        return kRed;
      case 'cancelled':
        return kFg38;
      default:
        return kOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Requests', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () => _shiftMonth(-1), icon: Icon(Icons.chevron_left, color: kFg54)),
          Center(child: Text('$_month/$_year', style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(onPressed: () => _shiftMonth(1), icon: Icon(Icons.chevron_right, color: kFg54)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequestSheet,
        backgroundColor: kCyan,
        icon: const Icon(Icons.send, size: 18, color: Colors.white),
        label: const Text('Request', style: TextStyle(color: Colors.white)),
      ),
      body: requests == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : requests.isEmpty
              ? Center(child: Text('No requests this month', style: TextStyle(color: kFg38)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: requests.map((r) {
                    final mine = _isMine(r);
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: (r.type == 'off' ? kCyan : kPurple).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            r.type == 'off' ? Icons.no_meals : Icons.person_add_alt,
                            size: 18,
                            color: r.type == 'off' ? kCyan : kPurple,
                          ),
                        ),
                        title: Text(
                          '${_memberName(r.memberId)}${mine ? ' (you)' : ''}',
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        subtitle: Text(
                          '${r.date.day}/${r.date.month} — ${r.type == 'off' ? 'Off' : 'Guest'}: ${_slotSummary(r)}'
                          '${r.note.isNotEmpty ? '\n${r.note}' : ''}',
                          style: TextStyle(fontSize: 11, color: kFg38),
                        ),
                        isThreeLine: r.note.isNotEmpty,
                        trailing: r.status == 'pending' && widget.isManager
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Approve',
                                    icon: const Icon(Icons.check_circle, color: kEmerald),
                                    onPressed: () => _run(() => state.respondMealRequest(r.id, true)),
                                  ),
                                  IconButton(
                                    tooltip: 'Reject',
                                    icon: const Icon(Icons.cancel, color: kRed),
                                    onPressed: () => _run(() => state.respondMealRequest(r.id, false)),
                                  ),
                                ],
                              )
                            : r.status == 'pending' && mine
                                ? TextButton(
                                    onPressed: () => _run(() => state.cancelMealRequest(r.id)),
                                    child: const Text('Cancel', style: TextStyle(fontSize: 12, color: kRed)),
                                  )
                                : Text(
                                    r.status,
                                    style: TextStyle(fontSize: 11, color: _statusColor(r.status), fontWeight: FontWeight.w600),
                                  ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}
