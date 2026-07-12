import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Group settings: meal slot values, maid (kajer bua) toggle, invite code.
/// Read-only for non-managers.
class MealSettingsScreen extends StatefulWidget {
  const MealSettingsScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealSettingsScreen> createState() => _MealSettingsScreenState();
}

class _MealSettingsScreenState extends State<MealSettingsScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  MealGroup? _group;
  final _name = TextEditingController();
  final _breakfast = TextEditingController();
  final _lunch = TextEditingController();
  final _dinner = TextEditingController();
  bool _hasMaid = false;
  TimeOfDay? _cutoff; // meal request deadline, null = none
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await state.fetchMealGroup(groupId);
      if (!mounted || g == null) return;
      setState(() {
        _group = g;
        _name.text = g.name;
        _breakfast.text = g.breakfastValue.toString();
        _lunch.text = g.lunchValue.toString();
        _dinner.text = g.dinnerValue.toString();
        _hasMaid = g.hasMaid;
        final hhmm = g.cutoffHHmm;
        _cutoff = hhmm == null
            ? null
            : TimeOfDay(
                hour: int.parse(hhmm.split(':')[0]),
                minute: int.parse(hhmm.split(':')[1]));
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _save() async {
    final b = double.tryParse(_breakfast.text.trim());
    final l = double.tryParse(_lunch.text.trim());
    final d = double.tryParse(_dinner.text.trim());
    if (_name.text.trim().isEmpty || b == null || l == null || d == null || b < 0 || l < 0 || d < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a name and valid meal values.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await state.updateMealGroupSettings(
        groupId,
        name: _name.text.trim(),
        hasMaid: _hasMaid,
        breakfastValue: b,
        lunchValue: l,
        dinnerValue: d,
        cutoffTime: _cutoff == null
            ? null
            : '${_cutoff!.hour.toString().padLeft(2, '0')}:${_cutoff!.minute.toString().padLeft(2, '0')}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved.')));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('Regenerate the invite code? The old code stops working.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Regenerate', style: TextStyle(color: kOrange))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await state.regenerateMealInviteCode(groupId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    return Scaffold(
      appBar: AppBar(title: const Text('Mess Settings', style: TextStyle(fontWeight: FontWeight.bold))),
      body: group == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.key, color: kCyan),
                    title: Text(group.inviteCode,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4, color: kCyan)),
                    subtitle: Text('Invite code', style: TextStyle(fontSize: 11, color: kFg38)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Copy',
                          icon: Icon(Icons.copy, size: 18, color: kFg54),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: group.inviteCode));
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Invite code copied!')));
                          },
                        ),
                        if (widget.isManager)
                          IconButton(
                            tooltip: 'Regenerate',
                            icon: const Icon(Icons.refresh, size: 18, color: kOrange),
                            onPressed: _regenerate,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.isManager) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Mess name')),
                          const SizedBox(height: 16),
                          Text('Meal values — how much one meal of each slot counts',
                              style: TextStyle(fontSize: 12, color: kFg54)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _breakfast,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Breakfast'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _lunch,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Lunch'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _dinner,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Dinner'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('E.g. breakfast 0.5 = two breakfasts count as one full meal.',
                              style: TextStyle(fontSize: 11, color: kFg38)),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('We have a maid (kajer bua) who cooks',
                                style: TextStyle(fontSize: 13.5)),
                            subtitle: Text('Hides cooking duty from the roster',
                                style: TextStyle(fontSize: 11, color: kFg38)),
                            value: _hasMaid,
                            activeThumbColor: kCyan,
                            onChanged: (v) => setState(() => _hasMaid = v),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule, size: 20, color: kOrange),
                            title: const Text('Meal request cutoff time',
                                style: TextStyle(fontSize: 13.5)),
                            subtitle: Text(
                              _cutoff == null
                                  ? 'No deadline — members can request any time'
                                  : 'Requests for tomorrow must be in by ${_cutoff!.format(context)} tonight',
                              style: TextStyle(fontSize: 11, color: kFg38),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_cutoff != null)
                                  IconButton(
                                    tooltip: 'Remove cutoff',
                                    icon: Icon(Icons.close, size: 16, color: kFg38),
                                    onPressed: () => setState(() => _cutoff = null),
                                  ),
                                TextButton(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _cutoff ?? const TimeOfDay(hour: 21, minute: 0),
                                    );
                                    if (picked != null) setState(() => _cutoff = picked);
                                  },
                                  child: Text(_cutoff == null ? 'Set' : _cutoff!.format(context),
                                      style: const TextStyle(fontSize: 12, color: kCyan)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          GradientButton(label: 'Save Settings', busy: _busy, onPressed: _save),
                        ],
                      ),
                    ),
                  ),
                ] else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Meal values', style: TextStyle(fontSize: 12, color: kFg54)),
                          const SizedBox(height: 6),
                          Text(
                            'Breakfast ${group.breakfastValue} · Lunch ${group.lunchValue} · Dinner ${group.dinnerValue}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Text('Maid (kajer bua)', style: TextStyle(fontSize: 12, color: kFg54)),
                          const SizedBox(height: 6),
                          Text(group.hasMaid ? 'Yes — maid cooks' : 'No',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Text('Meal request cutoff', style: TextStyle(fontSize: 12, color: kFg54)),
                          const SizedBox(height: 6),
                          Text(
                              group.cutoffHHmm == null
                                  ? 'None'
                                  : '${group.cutoffHHmm} (the day before)',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Text('Only the manager can change these.',
                              style: TextStyle(fontSize: 11, color: kFg38)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
