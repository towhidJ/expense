import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Duty roster: pick a day from the week strip (Saturday-first, BD style),
/// see who does which duty; the manager assigns/removes members per duty.
class MealDutyScreen extends StatefulWidget {
  const MealDutyScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealDutyScreen> createState() => _MealDutyScreenState();
}

class _MealDutyScreenState extends State<MealDutyScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  late DateTime _weekStart; // Saturday
  late DateTime _selected;
  MealGroup? _group;
  List<MealDutyType>? _dutyTypes;
  List<MealDutyAssignment> _assignments = [];
  List<MealGroupMember> _members = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Saturday-first week: getDay Sat=6 → offset (weekday % 7 + 1) % 7
    final offset = (today.weekday + 1) % 7; // Sat=0, Sun=1, ... Fri=6
    _weekStart = today.subtract(Duration(days: offset));
    _selected = today;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        state.fetchMealGroup(groupId),
        state.fetchMealDutyTypes(groupId),
        state.fetchMealDutyAssignments(groupId, _weekStart, _weekStart.add(const Duration(days: 7))),
        state.fetchMealMembers(groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _group = results[0] as MealGroup?;
        _dutyTypes = results[1] as List<MealDutyType>;
        _assignments = results[2] as List<MealDutyAssignment>;
        _members = results[3] as List<MealGroupMember>;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _shiftWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
      _selected = _weekStart;
      _assignments = [];
    });
    _load();
  }

  List<MealDutyType> get _activeTypes => (_dutyTypes ?? [])
      .where((t) => t.isActive && !((_group?.hasMaid ?? false) && t.excludedWhenMaid))
      .toList();

  List<MealGroupMember> get _approvedMembers =>
      _members.where((m) => m.status == 'approved').toList();

  String _memberName(String id) {
    for (final m in _members) {
      if (m.id == id) return m.displayName;
    }
    return '?';
  }

  List<MealDutyAssignment> _assignmentsFor(String dutyTypeId) => _assignments
      .where((a) =>
          a.dutyTypeId == dutyTypeId &&
          a.date.year == _selected.year &&
          a.date.month == _selected.month &&
          a.date.day == _selected.day)
      .toList();

  Future<void> _pickMember(MealDutyType type) async {
    final memberId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('${type.name} — ${DateFormat('EEE, MMM d').format(_selected)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ..._approvedMembers.map((m) => ListTile(
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: kCyan.withValues(alpha: 0.12),
                    child: Text(m.displayName.isEmpty ? '?' : m.displayName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 12, color: kCyan)),
                  ),
                  title: Text(m.displayName, style: const TextStyle(fontSize: 14)),
                  onTap: () => Navigator.pop(sheetContext, m.id),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (memberId == null) return;
    try {
      await state.assignMealDuty(
        groupId: groupId,
        dutyTypeId: type.id,
        memberId: memberId,
        date: _selected,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _manageTypes() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final newName = TextEditingController();
        return StatefulBuilder(
          builder: (sheetContext, setSheet) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Duty Types', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...(_dutyTypes ?? []).map((t) => Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.excludedWhenMaid ? '${t.name} (skipped when maid)' : t.name,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                          Switch(
                            value: t.isActive,
                            activeThumbColor: kCyan,
                            onChanged: (v) async {
                              await state.updateMealDutyType(t.id, isActive: v);
                              await _load();
                              setSheet(() {});
                            },
                          ),
                          if (!t.isBuiltin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: kRed),
                              onPressed: () async {
                                await state.deleteMealDutyType(t.id);
                                await _load();
                                setSheet(() {});
                              },
                            ),
                        ],
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newName,
                          decoration: const InputDecoration(labelText: 'New duty type', hintText: 'e.g. Sweeping'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: kCyan),
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () async {
                          if (newName.text.trim().isEmpty) return;
                          final maxOrder = (_dutyTypes ?? [])
                              .fold<int>(0, (mx, t) => t.sortOrder > mx ? t.sortOrder : mx);
                          await state.addMealDutyType(groupId, newName.text.trim(), maxOrder + 1);
                          newName.clear();
                          await _load();
                          setSheet(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = _dutyTypes;
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duty Roster', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (widget.isManager)
            IconButton(
              tooltip: 'Manage duty types',
              icon: const Icon(Icons.tune, color: kCyan),
              onPressed: _manageTypes,
            ),
        ],
      ),
      body: types == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : Column(
              children: [
                // Week strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(onPressed: () => _shiftWeek(-1), icon: Icon(Icons.chevron_left, color: kFg54)),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: days.map((d) {
                            final isSelected = d == _selected;
                            final isToday = d == today;
                            return Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(() => _selected = d),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: isSelected ? kGradient : null,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isToday && !isSelected
                                        ? Border.all(color: kCyan.withValues(alpha: 0.5))
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(DateFormat('E').format(d).substring(0, 2),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: isSelected ? Colors.white70 : kFg38)),
                                      const SizedBox(height: 2),
                                      Text('${d.day}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected ? Colors.white : kFg70)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      IconButton(onPressed: () => _shiftWeek(1), icon: Icon(Icons.chevron_right, color: kFg54)),
                    ],
                  ),
                ),
                if (_group?.hasMaid ?? false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.cleaning_services_outlined, size: 14, color: kPurple),
                        const SizedBox(width: 6),
                        Text('Maid cooks — cooking duty hidden',
                            style: TextStyle(fontSize: 11, color: kFg38)),
                      ],
                    ),
                  ),
                Expanded(
                  child: _activeTypes.isEmpty
                      ? Center(child: Text('No active duty types', style: TextStyle(color: kFg38)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _activeTypes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final type = _activeTypes[i];
                            final assigned = _assignmentsFor(type.id);
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(type.name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        ...assigned.map((a) => Chip(
                                              label: Text(_memberName(a.memberId),
                                                  style: const TextStyle(fontSize: 12)),
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: kCyan.withValues(alpha: 0.1),
                                              side: BorderSide(color: kCyan.withValues(alpha: 0.3)),
                                              deleteIcon: widget.isManager
                                                  ? const Icon(Icons.close, size: 14)
                                                  : null,
                                              onDeleted: widget.isManager
                                                  ? () async {
                                                      await state.removeMealDutyAssignment(a.id);
                                                      _load();
                                                    }
                                                  : null,
                                            )),
                                        if (assigned.isEmpty && !widget.isManager)
                                          Text('Nobody assigned',
                                              style: TextStyle(fontSize: 12, color: kFg38)),
                                        if (widget.isManager)
                                          ActionChip(
                                            label: const Text('Assign', style: TextStyle(fontSize: 12)),
                                            avatar: const Icon(Icons.add, size: 14),
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => _pickMember(type),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
