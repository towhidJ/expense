import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Warranty vault (v35): warranty_expiry/warranty_notes live on assets.
class WarrantyScreen extends StatefulWidget {
  const WarrantyScreen({super.key, required this.state});
  final AppState state;

  @override
  State<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends State<WarrantyScreen> {
  List<Asset>? _assets;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.state.fetchAssets();
    if (mounted) setState(() => _assets = rows);
  }

  Future<void> _editWarranty(Asset a) async {
    DateTime? expiry = a.warrantyExpiry;
    final notes = TextEditingController(text: a.warrantyNotes);
    bool busy = false;

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
                Text('Warranty — ${a.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Warranty expires', style: TextStyle(fontSize: 13, color: kFg54)),
                  trailing: Text(expiry == null ? 'Not set' : DateFormat('MMM d, yyyy').format(expiry!),
                      style: TextStyle(fontSize: 13, color: expiry == null ? kFg38 : kFg)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: expiry ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setSheet(() => expiry = picked);
                  },
                ),
                TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (shop, serial no, terms…)')),
                const SizedBox(height: 16),
                Row(children: [
                  if (a.warrantyExpiry != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setSheet(() => busy = true);
                              try {
                                await widget.state.updateAssetWarranty(a.id, warrantyExpiry: null, warrantyNotes: '');
                                if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                              } catch (e) {
                                setSheet(() => busy = false);
                              }
                            },
                      child: const Text('Remove', style: TextStyle(color: kRed)),
                    ),
                  Expanded(
                    child: GradientButton(
                      label: 'Save Warranty',
                      busy: busy,
                      onPressed: () async {
                        if (expiry == null) return;
                        setSheet(() => busy = true);
                        try {
                          await widget.state.updateAssetWarranty(a.id,
                              warrantyExpiry: expiry, warrantyNotes: notes.text.trim());
                          if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                        } catch (e) {
                          setSheet(() => busy = false);
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                    ),
                  ),
                ]),
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
    final assets = _assets;
    final now = DateTime.now();
    final withWarranty = (assets ?? []).where((a) => a.warrantyExpiry != null).toList()
      ..sort((a, b) => a.warrantyExpiry!.compareTo(b.warrantyExpiry!));
    final without = (assets ?? []).where((a) => a.warrantyExpiry == null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Warranty Vault', style: TextStyle(fontWeight: FontWeight.bold))),
      body: assets == null
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : RefreshIndicator(
              color: kOrange,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (assets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                          child: Text('No assets yet — add gadgets/appliances on the Assets screen first.',
                              textAlign: TextAlign.center, style: TextStyle(color: kFg38))),
                    ),
                  ...withWarranty.map((a) {
                    final expired = a.warrantyExpiry!.isBefore(now);
                    final daysLeft = a.warrantyExpiry!.difference(now).inDays;
                    final expiringSoon = !expired && daysLeft <= 30;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: Icon(Icons.verified_outlined,
                              color: expired ? kRed : expiringSoon ? kOrange : kEmerald),
                          title: Text(a.name, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${expired ? 'EXPIRED' : '$daysLeft days left'} · until ${DateFormat('MMM d, yyyy').format(a.warrantyExpiry!)}'
                            '${a.warrantyNotes.isNotEmpty ? '\n${a.warrantyNotes}' : ''}',
                            style: TextStyle(
                                fontSize: 11, color: expired ? kRed : expiringSoon ? kOrange : kFg38),
                          ),
                          isThreeLine: a.warrantyNotes.isNotEmpty,
                          trailing: IconButton(
                            icon: Icon(Icons.edit_outlined, size: 18, color: kFg38),
                            onPressed: () => _editWarranty(a),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (without.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('No warranty set', style: TextStyle(fontSize: 12, color: kFg38)),
                    ),
                    ...without.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.devices_other, color: kFg24),
                              title: Text(a.name, style: TextStyle(fontSize: 13, color: kFg70)),
                              trailing: TextButton(
                                onPressed: () => _editWarranty(a),
                                child: const Text('Add warranty', style: TextStyle(fontSize: 12, color: kCyan)),
                              ),
                            ),
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }
}
