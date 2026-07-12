import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../item_editor.dart';
import '../models.dart';
import '../theme.dart';
import 'meals_screen.dart' show kMonthNames;

const _expenseTypes = {
  'bazar': ('Bazar', Icons.shopping_basket_outlined, kCyan),
  'utility': ('Utility', Icons.bolt_outlined, kOrange),
  'maid': ('Maid', Icons.cleaning_services_outlined, kPurple),
  'feast': ('Feast / Special', Icons.celebration_outlined, Color(0xFFEC4899)),
  'other': ('Other', Icons.category_outlined, kEmerald),
};

const _advanceTypes = {
  'taken': ('Take advance (member gives money)', Icons.south_west, kEmerald),
  'returned': ('Return advance (member leaving)', Icons.north_east, kOrange),
  'adjusted': ('Adjust against dues (bokeya kata)', Icons.balance, kPurple),
};

/// Mess ledger: member deposits (manager records) and shared expenses
/// (whoever did the bazar records it). Standalone — never touches accounts.
class MealLedgerScreen extends StatefulWidget {
  const MealLedgerScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
    required this.year,
    required this.month,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;
  final int year;
  final int month;

  @override
  State<MealLedgerScreen> createState() => _MealLedgerScreenState();
}

class _MealLedgerScreenState extends State<MealLedgerScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  late int _year = widget.year;
  late int _month = widget.month;
  int _tab = 0; // 0 = deposits, 1 = expenses, 2 = advance (জামানত)
  List<MealDeposit>? _deposits;
  List<MealExpense>? _expenses;
  List<MealAdvance>? _advances;
  List<MealGroupMember> _members = [];
  final Set<String> _expandedItems = {};

  DateTime get _start => DateTime(_year, _month, 1);
  DateTime get _end => DateTime(_year, _month + 1, 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        state.fetchMealDeposits(groupId, _start, _end),
        state.fetchMealExpenses(groupId, _start, _end),
        state.fetchMealMembers(groupId),
        state.fetchMealAdvances(groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _deposits = results[0] as List<MealDeposit>;
        _expenses = results[1] as List<MealExpense>;
        _members = results[2] as List<MealGroupMember>;
        _advances = results[3] as List<MealAdvance>;
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
      _deposits = null;
      _expenses = null;
    });
    _load();
  }

  String _memberName(String? id) {
    for (final m in _members) {
      if (m.id == id) return m.displayName;
    }
    return 'Unknown';
  }

  List<MealGroupMember> get _approvedMembers =>
      _members.where((m) => m.status == 'approved').toList();

  // ---- Deposit form ----

  Future<void> _depositForm({MealDeposit? edit}) async {
    String? memberId = edit?.memberId;
    final amount = TextEditingController(text: edit == null ? '' : edit.amount.toString());
    final note = TextEditingController(text: edit?.note ?? '');
    DateTime date = edit?.date ?? DateTime.now();

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
                Text(edit == null ? 'New Deposit' : 'Edit Deposit',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: memberId,
                  decoration: const InputDecoration(labelText: 'Member'),
                  dropdownColor: kCard,
                  items: _approvedMembers
                      .map((m) => DropdownMenuItem(value: m.id, child: Text(m.displayName)))
                      .toList(),
                  onChanged: (v) => setSheet(() => memberId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('MMM d, yyyy').format(date)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 20),
                GradientButton(
                  label: edit == null ? 'Add Deposit' : 'Save',
                  onPressed: () {
                    if (memberId == null || double.tryParse(amount.text.trim()) == null) return;
                    Navigator.pop(sheetContext, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      if (edit == null) {
        await state.addMealDeposit(
          groupId: groupId,
          memberId: memberId!,
          amount: double.parse(amount.text.trim()),
          date: date,
          note: note.text.trim(),
        );
      } else {
        await state.updateMealDeposit(
          edit.id,
          memberId: memberId!,
          amount: double.parse(amount.text.trim()),
          date: date,
          note: note.text.trim(),
        );
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ---- Expense form ----

  Future<void> _expenseForm({MealExpense? edit}) async {
    String type = edit?.expenseType ?? 'bazar';
    String? spentBy = edit?.spentBy;
    final amount = TextEditingController(text: edit == null ? '' : edit.amount.toString());
    final note = TextEditingController(text: edit?.note ?? '');
    DateTime date = edit?.date ?? DateTime.now();
    final drafts = (edit?.items ?? []).map(ItemDraft.new).toList();
    XFile? pickedReceipt;
    bool removeReceipt = false;

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
                Text(edit == null ? 'New Expense' : 'Edit Expense',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  dropdownColor: kCard,
                  items: _expenseTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.$1)))
                      .toList(),
                  onChanged: (v) => setSheet(() => type = v ?? 'bazar'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('MMM d, yyyy').format(date)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: spentBy,
                  decoration: const InputDecoration(labelText: 'Spent by (who did bazar, optional)'),
                  dropdownColor: kCard,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('—')),
                    ..._approvedMembers
                        .map((m) => DropdownMenuItem<String?>(value: m.id, child: Text(m.displayName))),
                  ],
                  onChanged: (v) => setSheet(() => spentBy = v),
                ),
                const SizedBox(height: 12),
                ItemRowsEditor(drafts: drafts, onChanged: () => setSheet(() {})),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                ),
                const SizedBox(height: 12),
                // Receipt (রশিদ) photo
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kCyan,
                        side: BorderSide(color: kCyan.withValues(alpha: 0.4)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: Text(pickedReceipt != null ? 'Photo selected ✓' : 'Attach receipt',
                          style: const TextStyle(fontSize: 12.5)),
                      onPressed: () async {
                        final source = await showModalBottomSheet<ImageSource>(
                          context: sheetContext,
                          builder: (c) => SafeArea(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              ListTile(
                                  leading: const Icon(Icons.photo_camera_outlined),
                                  title: const Text('Camera'),
                                  onTap: () => Navigator.pop(c, ImageSource.camera)),
                              ListTile(
                                  leading: const Icon(Icons.photo_library_outlined),
                                  title: const Text('Gallery'),
                                  onTap: () => Navigator.pop(c, ImageSource.gallery)),
                            ]),
                          ),
                        );
                        if (source == null) return;
                        final img = await ImagePicker()
                            .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
                        if (img != null) setSheet(() { pickedReceipt = img; removeReceipt = false; });
                      },
                    ),
                    const SizedBox(width: 8),
                    if (edit?.attachmentUrl != null && pickedReceipt == null && !removeReceipt)
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: kRed, visualDensity: VisualDensity.compact),
                        onPressed: () => setSheet(() => removeReceipt = true),
                        child: const Text('Remove receipt', style: TextStyle(fontSize: 12)),
                      ),
                    if (removeReceipt)
                      Text('Will be removed', style: TextStyle(fontSize: 11, color: kRed.withValues(alpha: 0.8))),
                  ],
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: edit == null ? 'Add Expense' : 'Save',
                  onPressed: () {
                    if (double.tryParse(amount.text.trim()) == null) return;
                    Navigator.pop(sheetContext, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final items = draftsToItems(drafts);
      String? attachUrl;
      String? attachPath;
      if (pickedReceipt != null) {
        final bytes = await pickedReceipt!.readAsBytes();
        (attachUrl, attachPath) =
            await state.uploadMealReceipt(groupId, bytes, pickedReceipt!.name);
      }
      if (edit == null) {
        await state.addMealExpense(
          groupId: groupId,
          expenseType: type,
          amount: double.parse(amount.text.trim()),
          date: date,
          note: note.text.trim(),
          spentBy: spentBy,
          items: items,
          attachmentUrl: attachUrl,
          attachmentPath: attachPath,
        );
      } else {
        await state.updateMealExpense(
          edit.id,
          expenseType: type,
          amount: double.parse(amount.text.trim()),
          date: date,
          note: note.text.trim(),
          spentBy: spentBy,
          items: items,
          attachmentUrl: attachUrl,
          attachmentPath: attachPath,
          keepAttachment: !removeReceipt,
        );
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ---- Advance (জামানত) form ----

  Future<void> _advanceForm() async {
    String? memberId;
    String type = 'taken';
    final amount = TextEditingController();
    final note = TextEditingController();
    DateTime date = DateTime.now();

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
                const Text('Advance (জামানত) Entry',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: memberId,
                  decoration: const InputDecoration(labelText: 'Member'),
                  dropdownColor: kCard,
                  items: _members
                      .where((m) => m.status == 'approved' || _advanceBalance(m.id) > 0)
                      .map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text('${m.displayName} (${taka(_advanceBalance(m.id))})')))
                      .toList(),
                  onChanged: (v) => setSheet(() => memberId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  dropdownColor: kCard,
                  items: _advanceTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.$1, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setSheet(() => type = v ?? 'taken'),
                ),
                if (type == 'adjusted')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Creates a deposit for the member — meal balance goes up, advance goes down.',
                      style: TextStyle(fontSize: 11, color: kPurple.withValues(alpha: 0.8)),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('MMM d, yyyy').format(date)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Save',
                  onPressed: () {
                    if (memberId == null || double.tryParse(amount.text.trim()) == null) return;
                    Navigator.pop(sheetContext, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final amt = double.parse(amount.text.trim());
      if (type == 'adjusted') {
        await state.adjustMealAdvance(
            memberId: memberId!, amount: amt, date: date, note: note.text.trim());
      } else {
        if (type == 'returned' && amt > _advanceBalance(memberId!)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Return is more than the advance balance (${taka(_advanceBalance(memberId!))}).')));
          }
          return;
        }
        await state.addMealAdvance(
            groupId: groupId, memberId: memberId!, type: type, amount: amt,
            date: date, note: note.text.trim());
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  double _advanceBalance(String memberId) => (_advances ?? [])
      .where((a) => a.memberId == memberId)
      .fold(0.0, (s, a) => s + a.signed);

  @override
  Widget build(BuildContext context) {
    final deposits = _deposits;
    final expenses = _expenses;
    // Any member records expenses; deposits and advances are manager-only
    final canAdd = _tab == 1 || widget.isManager;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
          Center(child: Text('${kMonthNames[_month - 1].substring(0, 3)} $_year',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () => _tab == 0
                  ? _depositForm()
                  : _tab == 1
                      ? _expenseForm()
                      : _advanceForm(),
              backgroundColor: _tab == 0 ? kEmerald : (_tab == 1 ? kCyan : kPurple),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Deposits', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 1, label: Text('Expenses', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 2, label: Text('Advance', style: TextStyle(fontSize: 12))),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _buildDeposits(deposits)
                : _tab == 1
                    ? _buildExpenses(expenses)
                    : _buildAdvances(_advances),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvances(List<MealAdvance>? advances) {
    if (advances == null) return const Center(child: CircularProgressIndicator(color: kCyan));
    final withBalance = _members
        .where((m) => m.status == 'approved' || _advanceBalance(m.id) != 0)
        .toList();
    final totalHeld = withBalance.fold(0.0, (s, m) => s + _advanceBalance(m.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 16, color: kEmerald),
                    const SizedBox(width: 6),
                    const Expanded(
                        child: Text('Advance (জামানত)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    Text(taka(totalHeld),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kEmerald)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Taken when a member joins; returned when they leave, or adjusted against their dues.',
                  style: TextStyle(fontSize: 11, color: kFg38),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: withBalance
                      .map((m) => Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: _advanceBalance(m.id) > 0
                                ? kEmerald.withValues(alpha: 0.1)
                                : kFg.withValues(alpha: 0.04),
                            side: BorderSide(
                                color: _advanceBalance(m.id) > 0
                                    ? kEmerald.withValues(alpha: 0.3)
                                    : kFg12),
                            label: Text('${m.displayName}: ${taka(_advanceBalance(m.id))}',
                                style: TextStyle(fontSize: 11.5, color: kFg70)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (advances.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
                child: Text('🛡️  No advance entries yet', style: TextStyle(color: kFg38))),
          )
        else
          ...advances.map((a) {
            final meta = _advanceTypes[a.type] ?? _advanceTypes['taken']!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: meta.$3.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(meta.$2, color: meta.$3, size: 18),
                  ),
                  title: Text(_memberName(a.memberId), style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${meta.$1.split(' (').first} · ${DateFormat('MMM d').format(a.date)}${a.note.isEmpty ? '' : ' · ${a.note}'}',
                    style: TextStyle(fontSize: 11, color: kFg38),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${a.type == 'taken' ? '+' : '−'}${taka(a.amount)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: a.type == 'taken' ? kEmerald : kOrange)),
                      if (widget.isManager)
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: kFg38),
                          onPressed: () async {
                            try {
                              await state.deleteMealAdvance(a.id);
                              _load();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDeposits(List<MealDeposit>? deposits) {
    if (deposits == null) return const Center(child: CircularProgressIndicator(color: kCyan));
    if (deposits.isEmpty) {
      return Center(child: Text('💰  No deposits this month', style: TextStyle(color: kFg38)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: deposits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final d = deposits[i];
        return Card(
          child: ListTile(
            leading: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.savings_outlined, color: kEmerald, size: 18),
            ),
            title: Text(_memberName(d.memberId), style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              '${DateFormat('MMM d').format(d.date)}${d.note.isEmpty ? '' : ' · ${d.note}'}',
              style: TextStyle(fontSize: 11, color: kFg38),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(taka(d.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: kEmerald)),
                if (widget.isManager)
                  PopupMenuButton<String>(
                    color: kCard,
                    icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                    onSelected: (v) async {
                      if (v == 'edit') _depositForm(edit: d);
                      if (v == 'delete') {
                        try {
                          await state.deleteMealDeposit(d.id);
                          _load();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                      PopupMenuItem(value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpenses(List<MealExpense>? expenses) {
    if (expenses == null) return const Center(child: CircularProgressIndicator(color: kCyan));
    if (expenses.isEmpty) {
      return Center(child: Text('🛒  No expenses this month', style: TextStyle(color: kFg38)));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: expenses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = expenses[i];
        final meta = _expenseTypes[e.expenseType] ?? _expenseTypes['other']!;
        final canEdit = widget.isManager || e.addedBy == state.uid;
        final isOpen = _expandedItems.contains(e.id);
        return Card(
          child: Column(
          children: [
          ListTile(
            onTap: e.items.isEmpty
                ? null
                : () => setState(() {
                      isOpen ? _expandedItems.remove(e.id) : _expandedItems.add(e.id);
                    }),
            leading: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: meta.$3.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(meta.$2, color: meta.$3, size: 18),
            ),
            title: Text(
              e.spentBy != null ? '${meta.$1} · ${_memberName(e.spentBy)}' : meta.$1,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              '${DateFormat('MMM d').format(e.date)}'
              '${e.items.isNotEmpty ? ' · ${e.items.length} item${e.items.length > 1 ? 's' : ''}' : ''}'
              '${e.note.isEmpty ? '' : ' · ${e.note}'}',
              style: TextStyle(fontSize: 11, color: kFg38),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.attachmentUrl != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.attach_file, size: 17, color: kCyan),
                    tooltip: 'View receipt',
                    onPressed: () => _viewReceipt(e.attachmentUrl!),
                  ),
                Text(taka(e.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                if (canEdit)
                  PopupMenuButton<String>(
                    color: kCard,
                    icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                    onSelected: (v) async {
                      if (v == 'edit') _expenseForm(edit: e);
                      if (v == 'delete') {
                        try {
                          await state.deleteMealExpense(e.id);
                          _load();
                        } catch (err) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('Error: $err')));
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                      PopupMenuItem(value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                    ],
                  ),
              ],
            ),
          ),
          if (isOpen && e.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ItemListView(items: e.items),
            ),
          ],
          ),
        );
      },
    );
  }

  void _viewReceipt(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: kCard,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) => progress == null
                        ? child
                        : const Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(color: kCyan),
                          ),
                    errorBuilder: (c, err, st) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load the receipt.',
                          style: TextStyle(color: kFg54)),
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
