import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Daily meal entry: pick a date, then +/- steppers per member for
/// breakfast / lunch / dinner (guest meals behind an expand).
class MealEntriesScreen extends StatefulWidget {
  const MealEntriesScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealEntriesScreen> createState() => _MealEntriesScreenState();
}

class _MealEntriesScreenState extends State<MealEntriesScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  DateTime _date = DateTime.now();
  List<MealGroupMember>? _members;
  List<MealEntry> _entries = [];
  MealHoliday? _holiday;
  final Set<String> _guestOpen = {};
  String? _savingMemberId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dayStart = DateTime(_date.year, _date.month, _date.day);
      final results = await Future.wait([
        state.fetchMealMembers(groupId),
        state.fetchMealEntries(groupId, dayStart, dayStart.add(const Duration(days: 1))),
        state.fetchMealHolidays(groupId, dayStart, dayStart.add(const Duration(days: 1))),
      ]);
      if (!mounted) return;
      setState(() {
        _members = (results[0] as List<MealGroupMember>)
            .where((m) => m.status == 'approved')
            .toList();
        _entries = results[1] as List<MealEntry>;
        _holiday = (results[2] as List<MealHoliday>).firstOrNull;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _holidaySheet() async {
    final title = TextEditingController(text: _holiday?.title ?? 'Meal Holiday');
    final menu = TextEditingController(text: _holiday?.menu ?? '');
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Holiday — ${DateFormat('EEE, MMM d').format(_date)}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Regular meals are usually off; record the feast cost as a "Feast / Special" expense.',
                  style: TextStyle(fontSize: 11, color: kFg38)),
              const SizedBox(height: 16),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Eid Day, Friday Feast')),
              const SizedBox(height: 12),
              TextField(
                controller: menu,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Special food / nasta plan (optional)',
                    hintText: 'e.g. Biriyani + borhani, morning khichuri'),
              ),
              const SizedBox(height: 20),
              GradientButton(label: 'Save Holiday', onPressed: () => Navigator.pop(sheetContext, 'save')),
              if (_holiday != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: kRed,
                    side: BorderSide(color: kRed.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(sheetContext, 'remove'),
                  child: const Text('Remove Holiday'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'remove' && _holiday != null) {
        await state.deleteMealHoliday(_holiday!.id);
      } else if (action == 'save') {
        await state.upsertMealHoliday(
            groupId: groupId, date: _date, title: title.text.trim(), menu: menu.text.trim());
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  MealEntry? _entryFor(String memberId) {
    for (final e in _entries) {
      if (e.memberId == memberId) return e;
    }
    return null;
  }

  void _shiftDate(int days) {
    setState(() {
      _date = _date.add(Duration(days: days));
      _entries = [];
      _holiday = null;
    });
    _load();
  }

  bool _canEdit(MealGroupMember m) => widget.isManager || m.userId == state.uid;

  Future<void> _save(MealGroupMember member, {
    double? breakfast, double? lunch, double? dinner,
    double? guestBreakfast, double? guestLunch, double? guestDinner,
  }) async {
    final e = _entryFor(member.id);
    setState(() => _savingMemberId = member.id);
    try {
      await state.upsertMealEntry(
        groupId: groupId,
        memberId: member.id,
        date: _date,
        breakfast: breakfast ?? e?.breakfast ?? 0,
        lunch: lunch ?? e?.lunch ?? 0,
        dinner: dinner ?? e?.dinner ?? 0,
        guestBreakfast: guestBreakfast ?? e?.guestBreakfast ?? 0,
        guestLunch: guestLunch ?? e?.guestLunch ?? 0,
        guestDinner: guestDinner ?? e?.guestDinner ?? 0,
      );
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _savingMemberId = null);
    }
  }

  Widget _stepper(double value, bool enabled, void Function(double) onChanged) {
    final label = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn(Icons.remove, enabled && value > 0, () => onChanged(value - 1)),
        SizedBox(width: 26, child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)))),
        _stepBtn(Icons.add, enabled, () => onChanged(value + 1)),
      ],
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kFg.withValues(alpha: enabled ? 0.07 : 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: enabled ? kFg70 : kFg24),
      ),
    );
  }

  Widget _slotColumn(String label, double value, bool enabled, void Function(double) onChanged) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10.5, color: kFg38)),
        const SizedBox(height: 4),
        _stepper(value, enabled, onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Meals', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (widget.isManager)
            IconButton(
              tooltip: _holiday == null ? 'Mark holiday' : 'Edit holiday',
              icon: Icon(Icons.celebration_outlined,
                  color: _holiday != null ? const Color(0xFFEC4899) : kFg38),
              onPressed: _holidaySheet,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => _shiftDate(-1), icon: Icon(Icons.chevron_left, color: kFg54)),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) {
                      setState(() {
                        _date = picked;
                        _entries = [];
                        _holiday = null;
                      });
                      _load();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      DateFormat('EEE, MMM d, yyyy').format(_date),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(onPressed: () => _shiftDate(1), icon: Icon(Icons.chevron_right, color: kFg54)),
              ],
            ),
          ),
          if (_holiday != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.celebration, size: 18, color: Color(0xFFEC4899)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_holiday!.title,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEC4899))),
                          if (_holiday!.menu.isNotEmpty)
                            Text('Special food / nasta: ${_holiday!.menu}',
                                style: TextStyle(fontSize: 12, color: kFg54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: members == null
                ? const Center(child: CircularProgressIndicator(color: kCyan))
                : members.isEmpty
                    ? Center(child: Text('No approved members yet', style: TextStyle(color: kFg38)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: members.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final m = members[i];
                          final e = _entryFor(m.id);
                          final enabled = _canEdit(m) && _savingMemberId != m.id;
                          final guestTotal = (e?.guestBreakfast ?? 0) + (e?.guestLunch ?? 0) + (e?.guestDinner ?? 0);
                          final guestOpen = _guestOpen.contains(m.id);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.userId == state.uid ? '${m.displayName} (you)' : m.displayName,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_savingMemberId == m.id)
                                        const SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: kCyan)),
                                      TextButton.icon(
                                        onPressed: () => setState(() {
                                          guestOpen ? _guestOpen.remove(m.id) : _guestOpen.add(m.id);
                                        }),
                                        icon: Icon(Icons.person_add_alt, size: 15,
                                            color: guestTotal > 0 ? kPurple : kFg38),
                                        label: Text(
                                          guestTotal > 0
                                              ? '${guestTotal % 1 == 0 ? guestTotal.toStringAsFixed(0) : guestTotal} guest'
                                              : 'Guests',
                                          style: TextStyle(fontSize: 11.5,
                                              color: guestTotal > 0 ? kPurple : kFg38),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _slotColumn('Breakfast', e?.breakfast ?? 0, enabled,
                                          (v) => _save(m, breakfast: v)),
                                      _slotColumn('Lunch', e?.lunch ?? 0, enabled,
                                          (v) => _save(m, lunch: v)),
                                      _slotColumn('Dinner', e?.dinner ?? 0, enabled,
                                          (v) => _save(m, dinner: v)),
                                    ],
                                  ),
                                  if (guestOpen) ...[
                                    const SizedBox(height: 10),
                                    Divider(height: 1, color: kFg.withValues(alpha: 0.06)),
                                    const SizedBox(height: 8),
                                    Text('Guest meals', style: TextStyle(fontSize: 11, color: kFg38)),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _slotColumn('Breakfast', e?.guestBreakfast ?? 0, enabled,
                                            (v) => _save(m, guestBreakfast: v)),
                                        _slotColumn('Lunch', e?.guestLunch ?? 0, enabled,
                                            (v) => _save(m, guestLunch: v)),
                                        _slotColumn('Dinner', e?.guestDinner ?? 0, enabled,
                                            (v) => _save(m, guestDinner: v)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (!widget.isManager)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('You can only record your own meals. The manager can edit everyone\'s.',
                  style: TextStyle(fontSize: 11, color: kFg38)),
            ),
        ],
      ),
    );
  }
}
