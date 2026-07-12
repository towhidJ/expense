import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'meal_entries_screen.dart';
import 'meal_ledger_screen.dart';
import 'meal_duty_screen.dart';
import 'meal_members_screen.dart';
import 'meal_report_screen.dart';
import 'meal_settings_screen.dart';

const kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

/// The meal workspace: a separate shell with its own bottom navigation
/// (Summary / Meals / Ledger / Duty / More), mirroring the web's /meals
/// workspace. Without an approved mess it shows the create/join onboarding.
class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  AppState get state => widget.state;

  List<MealGroupMember>? _memberships;
  String? _activeGroupId;
  int _tab = 0;
  MealMonthSummary? _summary;
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

  List<MealGroupMember> get _approved =>
      (_memberships ?? []).where((m) => m.status == 'approved').toList();
  List<MealGroupMember> get _pending =>
      (_memberships ?? []).where((m) => m.status == 'pending').toList();

  MealGroupMember? get _active {
    final approved = _approved;
    if (approved.isEmpty) return null;
    return approved.firstWhere((m) => m.groupId == _activeGroupId,
        orElse: () => approved.first);
  }

  bool get _isManager => _active?.role == 'manager';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeGroupId = prefs.getString('meal_active_group');
      final rows = await state.fetchMyMealMemberships();
      if (!mounted) return;
      setState(() => _memberships = rows);
      await _loadGroupData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _loadGroupData() async {
    final active = _active;
    if (active == null) {
      setState(() {
        _summary = null;
        _members = [];
      });
      return;
    }
    try {
      final results = await Future.wait([
        state.fetchMealMonthSummary(active.groupId, _year, _month),
        state.fetchMealMembers(active.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as MealMonthSummary;
        _members = results[1] as List<MealGroupMember>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _switchGroup(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meal_active_group', groupId);
    setState(() {
      _activeGroupId = groupId;
      _summary = null;
      _tab = 0;
    });
    await _loadGroupData();
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
      _summary = null;
    });
    _loadGroupData();
  }

  // ---- Create / join sheets ----

  Future<void> _createGroupSheet() async {
    final name = TextEditingController();
    final display = TextEditingController();
    final ok = await _sheet('Create a Mess', 'You become the manager and get an invite code.', [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Mess name', hintText: 'e.g. Green House Mess')),
      const SizedBox(height: 12),
      TextField(controller: display, decoration: const InputDecoration(labelText: 'Your display name (optional)')),
    ], 'Create Group', () => name.text.trim().isNotEmpty);
    if (ok != true) return;
    try {
      final groupId = await state.createMealGroup(name.text.trim(),
          displayName: display.text.trim().isEmpty ? null : display.text.trim());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('meal_active_group', groupId);
      _activeGroupId = groupId;
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _joinGroupSheet() async {
    final code = TextEditingController();
    final display = TextEditingController();
    final ok = await _sheet('Join a Mess', 'Enter the invite code from your mess manager.', [
      TextField(
        controller: code,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Invite code', hintText: 'e.g. ABCD2345'),
      ),
      const SizedBox(height: 12),
      TextField(controller: display, decoration: const InputDecoration(labelText: 'Your display name (optional)')),
    ], 'Request to Join', () => code.text.trim().isNotEmpty);
    if (ok != true) return;
    try {
      await state.joinMealGroup(code.text.trim(),
          displayName: display.text.trim().isEmpty ? null : display.text.trim());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request sent — waiting for the manager to approve.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<bool?> _sheet(String title, String subtitle, List<Widget> fields,
      String buttonLabel, bool Function() validate) {
    return showModalBottomSheet<bool>(
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
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: kFg38)),
              const SizedBox(height: 16),
              ...fields,
              const SizedBox(height: 20),
              GradientButton(
                label: buttonLabel,
                onPressed: () {
                  if (validate()) Navigator.pop(sheetContext, true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await _load(); // refresh after returning (approvals, settings...)
  }

  @override
  Widget build(BuildContext context) {
    final memberships = _memberships;
    final active = _active;

    if (memberships == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meals', style: TextStyle(fontWeight: FontWeight.bold))),
        body: const Center(child: CircularProgressIndicator(color: kCyan)),
      );
    }

    if (active == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meals', style: TextStyle(fontWeight: FontWeight.bold))),
        body: _buildOnboarding(),
      );
    }

    // Workspace shell: each tab keeps its own AppBar; back leaves the workspace.
    final gid = active.groupId;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _buildSummaryTab(active),
          MealEntriesScreen(key: ValueKey('entries-$gid'), state: state, membership: active, isManager: _isManager),
          MealLedgerScreen(key: ValueKey('ledger-$gid-$_year-$_month'), state: state, membership: active, isManager: _isManager, year: _year, month: _month),
          MealDutyScreen(key: ValueKey('duty-$gid'), state: state, membership: active, isManager: _isManager),
          _buildMoreTab(active),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) {
          setState(() => _tab = i);
          if (i == 0) _loadGroupData(); // summary reflects edits from other tabs
        },
        selectedItemColor: kEmerald,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: 'Summary'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: 'Meals'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Ledger'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist_rtl), label: 'Duty'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  Widget _buildOnboarding() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_pending.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.hourglass_top, color: kOrange),
              title: const Text('Waiting for approval', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _pending.map((p) => p.group?.name ?? 'a mess').join(', '),
                style: TextStyle(fontSize: 12, color: kFg38),
              ),
            ),
          ),
        if (_pending.isNotEmpty) const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 12),
                const Text('Create a Mess', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Start a meal group for your bachelor house. You become the manager.',
                    style: TextStyle(fontSize: 12, color: kFg38)),
                const SizedBox(height: 14),
                GradientButton(label: 'Create Group', onPressed: _createGroupSheet),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.key, color: kPurple, size: 22),
                ),
                const SizedBox(height: 12),
                const Text('Join a Mess', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Got an invite code? Join your mess mates.',
                    style: TextStyle(fontSize: 12, color: kFg38)),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: kPurple,
                    side: const BorderSide(color: kPurple),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _joinGroupSheet,
                  child: const Text('Enter Invite Code', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- Summary tab ----

  Widget _buildSummaryTab(MealGroupMember active) {
    final summary = _summary;
    final me = summary?.members.where((m) => m.userId == state.uid).toList();
    final myRow = (me != null && me.isNotEmpty) ? me.first : null;
    final group = active.group;

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? 'Mess',
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Monthly report',
            icon: const Icon(Icons.print_outlined, color: kCyan),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MealReportScreen(
                        state: state, membership: active, year: _year, month: _month))),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kCyan,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(
              children: [
                if (_isManager)
                  Expanded(
                    child: Text('You are the manager',
                        style: TextStyle(fontSize: 11, color: kFg38)),
                  )
                else
                  const Spacer(),
                IconButton(onPressed: () => _shiftMonth(-1), icon: Icon(Icons.chevron_left, color: kFg54)),
                Text('${kMonthNames[_month - 1].substring(0, 3)} $_year',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(onPressed: () => _shiftMonth(1), icon: Icon(Icons.chevron_right, color: kFg54)),
              ],
            ),
            summary == null
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: kCyan)),
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          _statCard('Total Bazar', taka(summary.totalBazar), Icons.shopping_basket_outlined, kCyan),
                          const SizedBox(width: 10),
                          _statCard('Total Meals', summary.totalMeals.toStringAsFixed(summary.totalMeals % 1 == 0 ? 0 : 1), Icons.restaurant_outlined, kPurple),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _statCard('Meal Rate', taka(summary.mealRate), Icons.calculate_outlined, kOrange),
                          const SizedBox(width: 10),
                          _statCard(
                            'My Balance',
                            myRow == null ? '—' : taka(myRow.balance),
                            Icons.account_balance_wallet_outlined,
                            (myRow != null && myRow.balance < 0) ? kRed : kEmerald,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              for (final m in summary.members)
                                ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: kCyan.withValues(alpha: 0.12),
                                    child: Text(m.displayName.isEmpty ? '?' : m.displayName.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(fontSize: 12, color: kCyan)),
                                  ),
                                  title: Text(
                                    m.userId == state.uid ? '${m.displayName} (you)' : m.displayName,
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                  subtitle: Text(
                                    '${m.meals % 1 == 0 ? m.meals.toStringAsFixed(0) : m.meals.toStringAsFixed(1)} meals · deposit ${taka(m.deposits)}${m.advance > 0 ? ' · জামানত ${taka(m.advance)}' : ''}',
                                    style: TextStyle(fontSize: 11, color: kFg38),
                                  ),
                                  trailing: Text(
                                    taka(m.balance),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: m.balance < 0 ? kRed : kEmerald,
                                    ),
                                  ),
                                ),
                              if (summary.members.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('No members yet', style: TextStyle(color: kFg38)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // ---- More tab (inside the meal workspace) ----

  Widget _buildMoreTab(MealGroupMember active) {
    final pendingCount = _members.where((m) => m.status == 'pending').length;
    return Scaffold(
      appBar: AppBar(title: const Text('Mess More', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                _moreTile(Icons.group_outlined, 'Members',
                    pendingCount > 0 ? '$pendingCount pending request${pendingCount > 1 ? 's' : ''}' : 'Approve, roles, invite code',
                    kPurple,
                    () => _push(MealMembersScreen(state: state, membership: active, isManager: _isManager)),
                    badge: _isManager && pendingCount > 0 ? pendingCount : null),
                _divider(),
                _moreTile(Icons.print_outlined, 'Monthly Report', 'Printable meal report / voucher', kCyan,
                    () => _push(MealReportScreen(state: state, membership: active, year: _year, month: _month))),
                _divider(),
                _moreTile(Icons.settings_outlined, 'Settings', 'Meal values, maid, invite code', kFg54,
                    () => _push(MealSettingsScreen(state: state, membership: active, isManager: _isManager))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                if (_approved.length > 1) ...[
                  ...(_approved.where((m) => m.groupId != active.groupId).map((m) => ListTile(
                        leading: const Icon(Icons.swap_horiz, color: kCyan),
                        title: Text('Switch to ${m.group?.name ?? 'Mess'}', style: const TextStyle(fontSize: 14)),
                        onTap: () => _switchGroup(m.groupId),
                      ))),
                  _divider(),
                ],
                _moreTile(Icons.add_circle_outline, 'Create a Mess', 'Start another meal group', kEmerald, _createGroupSheet),
                _divider(),
                _moreTile(Icons.key, 'Join a Mess', 'Enter an invite code', kPurple, _joinGroupSheet),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: _moreTile(Icons.arrow_back, 'Expense Tracker', 'Back to the finance workspace', kOrange,
                () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: kFg.withValues(alpha: 0.06));

  Widget _moreTile(IconData icon, String title, String subtitle, Color color,
      VoidCallback onTap, {int? badge}) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: kFg38)),
      trailing: badge != null
          ? CircleAvatar(radius: 10, backgroundColor: kOrange,
              child: Text('$badge', style: const TextStyle(fontSize: 11, color: Colors.white)))
          : Icon(Icons.chevron_right, color: kFg24),
      onTap: onTap,
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: kFg38),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(fontSize: 11, color: kFg38),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
