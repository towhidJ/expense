import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

const _logTypes = {
  'fuel': ('⛽', 'Fuel'),
  'service': ('🔧', 'Maintenance'),
  'other': ('📋', 'Other'),
};

/// Vehicle fuel/maintenance tracker — mirrors web /vehicle. Every log posts a
/// real expense via process_transaction and links its transaction_id.
class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key, required this.state});
  final AppState state;

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  List<Map<String, dynamic>>? _vehicles;
  List<Map<String, dynamic>> _logs = [];
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.state.entityRows('vehicles'),
        widget.state.entityRows('vehicle_logs', orderBy: 'log_date'),
      ]);
      if (!mounted) return;
      setState(() {
        _vehicles = results[0];
        _logs = results[1];
        if (_vehicles!.isNotEmpty && (_activeId == null || !_vehicles!.any((v) => v['id'] == _activeId))) {
          _activeId = _vehicles!.first['id'];
        }
      });
    } catch (_) {
      if (mounted) setState(() => _vehicles = []);
    }
  }

  List<Map<String, dynamic>> get _shownLogs =>
      _logs.where((l) => l['vehicle_id'] == _activeId).toList()
        ..sort((a, b) => (b['log_date'] as String).compareTo(a['log_date'] as String));

  double? get _mileage {
    final fuel = _shownLogs
        .where((l) => l['log_type'] == 'fuel' && l['odometer'] != null)
        .toList()
      ..sort((a, b) => ((a['odometer'] as num).compareTo(b['odometer'] as num)));
    if (fuel.length < 2) return null;
    double km = 0, liters = 0;
    for (var i = 1; i < fuel.length; i++) {
      km += (fuel[i]['odometer'] as num) - (fuel[i - 1]['odometer'] as num);
      liters += (fuel[i]['liters'] as num?)?.toDouble() ?? 0;
    }
    return liters > 0 ? km / liters : null;
  }

  Future<void> _addVehicle() async {
    final name = TextEditingController();
    final type = TextEditingController();
    final reg = TextEditingController();
    String? assetId;
    bool busy = false;
    List<Asset> vehicleAssets = [];
    try {
      final assets = await widget.state.fetchAssets();
      final linked = (_vehicles ?? []).map((v) => v['asset_id']).whereType<String>().toSet();
      vehicleAssets = assets.where((a) => a.type == 'Vehicle' && !linked.contains(a.id)).toList();
    } catch (_) {}
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
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
                const Text('New Vehicle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                if (vehicleAssets.isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    dropdownColor: kCard,
                    initialValue: assetId,
                    decoration: const InputDecoration(
                        labelText: 'Already in Assets?', helperText: 'Links it instead of double-entering'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('No — enter manually')),
                      ...vehicleAssets.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (v) => setSheet(() {
                      assetId = v;
                      final a = vehicleAssets.where((x) => x.id == v).firstOrNull;
                      if (a != null) name.text = a.name;
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (e.g. Yamaha FZ)')),
                const SizedBox(height: 12),
                TextField(controller: type, decoration: const InputDecoration(labelText: 'Type (Bike / Car)')),
                const SizedBox(height: 12),
                TextField(controller: reg, decoration: const InputDecoration(labelText: 'Registration number')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Vehicle',
                  busy: busy,
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    setSheet(() => busy = true);
                    try {
                      await widget.state.insertEntityRow('vehicles', {
                        'name': name.text.trim(),
                        'vehicle_type': type.text.trim().isEmpty ? null : type.text.trim(),
                        'reg_number': reg.text.trim().isEmpty ? null : reg.text.trim(),
                        'asset_id': assetId,
                      });
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _addLog() async {
    if (_activeId == null) return;
    final vehicle = _vehicles!.firstWhere((v) => v['id'] == _activeId);
    final amount = TextEditingController();
    final odometer = TextEditingController();
    final liters = TextEditingController();
    final notes = TextEditingController();
    String logType = 'fuel';
    String? accountId;
    String? categoryId;
    DateTime date = DateTime.now();
    bool busy = false;
    final expenseCats = widget.state.categories.where((c) => c.type == 'expense').toList();

    final saved = await showModalBottomSheet<bool>(
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
                Text('New Log — ${vehicle['name']}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: logType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _logTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value.$1} ${e.value.$2}')))
                      .toList(),
                  onChanged: (v) => setSheet(() => logType = v ?? 'fuel'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Amount (৳)'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: odometer,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Odometer (km)'))),
                ]),
                if (logType == 'fuel') ...[
                  const SizedBox(height: 12),
                  TextField(
                      controller: liters,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Liters')),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: accountId,
                  decoration: const InputDecoration(labelText: 'Pay from account'),
                  items: widget.state.accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setSheet(() => accountId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  dropdownColor: kCard,
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Expense category'),
                  items: expenseCats
                      .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.icon} ${c.name}')))
                      .toList(),
                  onChanged: (v) => setSheet(() => categoryId = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(DateFormat('MMM d, yyyy').format(date),
                      style: TextStyle(fontSize: 13, color: kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Save Log',
                  busy: busy,
                  onPressed: () async {
                    final amt = double.tryParse(amount.text.trim());
                    if (amt == null || amt <= 0 || accountId == null || categoryId == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Amount, account and category are required.')));
                      return;
                    }
                    setSheet(() => busy = true);
                    try {
                      final txId = await widget.state.processTransactionId(
                        accountId: accountId!,
                        categoryId: categoryId!,
                        type: 'expense',
                        amount: amt,
                        date: date,
                        description: '${vehicle['name']} — ${_logTypes[logType]!.$2}',
                      );
                      await widget.state.insertEntityRow('vehicle_logs', {
                        'vehicle_id': _activeId,
                        'log_type': logType,
                        'log_date':
                            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        'odometer': double.tryParse(odometer.text.trim()),
                        'amount': amt,
                        'liters': logType == 'fuel' ? double.tryParse(liters.text.trim()) : null,
                        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                        'transaction_id': txId,
                      });
                      if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _vehicles;
    final logs = _shownLogs;
    final yearStart = DateTime(DateTime.now().year, 1, 1);
    final yearLogs = logs.where((l) => DateTime.parse(l['log_date']).isAfter(yearStart.subtract(const Duration(days: 1)))).toList();
    final yearSpend = yearLogs.fold<double>(0, (s, l) => s + ((l['amount'] as num?)?.toDouble() ?? 0));
    final maintSpend = yearLogs
        .where((l) => l['log_type'] == 'service')
        .fold<double>(0, (s, l) => s + ((l['amount'] as num?)?.toDouble() ?? 0));
    final mileage = _mileage;

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Expense', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: FloatingActionButton(
        onPressed: vehicles == null || vehicles.isEmpty ? _addVehicle : _addLog,
        backgroundColor: kCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: vehicles == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : RefreshIndicator(
              color: kCyan,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  if (vehicles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No vehicles yet — tap + to add a bike or car.',
                              style: TextStyle(color: kFg38))),
                    )
                  else ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...vehicles.map((v) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('🏍️ ${v['name']}', style: const TextStyle(fontSize: 12)),
                                  selected: _activeId == v['id'],
                                  selectedColor: kCyan.withValues(alpha: 0.2),
                                  onSelected: (_) => setState(() => _activeId = v['id']),
                                ),
                              )),
                          ActionChip(
                            label: const Text('+ Vehicle', style: TextStyle(fontSize: 12)),
                            onPressed: _addVehicle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _stat('This Year', taka(yearSpend), kRed)),
                      const SizedBox(width: 10),
                      Expanded(child: _stat('Maintenance', taka(maintSpend), kCyan)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _stat('Mileage', mileage == null ? '—' : '${mileage.toStringAsFixed(1)} km/L',
                              kEmerald)),
                    ]),
                    const SizedBox(height: 12),
                    if (logs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                            child: Text('No logs yet — tap + to add fuel or maintenance.',
                                style: TextStyle(color: kFg38))),
                      ),
                    ...logs.map((l) {
                      final meta = _logTypes[l['log_type']] ?? _logTypes['other']!;
                      return Card(
                        child: ListTile(
                          leading: Text(meta.$1, style: const TextStyle(fontSize: 20)),
                          title: Text(
                              '${meta.$2}${l['liters'] != null ? ' (${l['liters']}L)' : ''}',
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${DateFormat('MMM d, yyyy').format(DateTime.parse(l['log_date']))}'
                            '${l['odometer'] != null ? ' · ${l['odometer']} km' : ''}'
                            '${(l['notes'] ?? '').toString().isNotEmpty ? ' · ${l['notes']}' : ''}',
                            style: TextStyle(fontSize: 11.5, color: kFg38),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(taka((l['amount'] as num?) ?? 0),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              PopupMenuButton<String>(
                                color: kCard,
                                icon: Icon(Icons.more_vert, color: kFg38, size: 20),
                                onSelected: (v) async {
                                  if (v == 'delete') {
                                    try {
                                      await widget.state.deleteEntityRow('vehicle_logs', l['id']);
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
                                  PopupMenuItem(value: 'delete', child: Text('Delete (transaction stays)')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (_activeId != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Delete vehicle?'),
                                content: const Text('All its logs are deleted too. Linked transactions stay.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(dialogContext, true),
                                      child: const Text('Delete', style: TextStyle(color: kRed))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              try {
                                await widget.state.deleteEntityRow('vehicles', _activeId!);
                                setState(() => _activeId = null);
                                _load();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            }
                          },
                          child: Text('Delete this vehicle',
                              style: TextStyle(fontSize: 12, color: kRed.withValues(alpha: 0.7))),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: kFg38)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: color),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
