import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_state.dart';
import '../theme.dart';

/// Full-workspace JSON export (v35 web parity). Missing tables (unapplied
/// migrations) are skipped silently.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.state});
  final AppState state;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  Map<String, int>? _lastCounts;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await widget.state.fetchBackupData();
      final counts = {for (final e in data.entries) e.key: e.value.length};
      final payload = jsonEncode({
        'app': 'TakaKhata',
        'exported_at': DateTime.now().toIso8601String(),
        'entity': widget.state.currentEntity?.name,
        'tables': data,
      });
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/takakhata_backup_$stamp.json');
      await file.writeAsString(payload);
      if (mounted) setState(() => _lastCounts = counts);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'TakaKhata backup $stamp',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final counts = _lastCounts;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📦 Export everything', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    'Downloads all data of the "${widget.state.currentEntity?.name ?? ''}" workspace as one JSON file — accounts, transactions, loans, rent, meals-adjacent finance tables and more. Share it to Drive, email or keep it offline.',
                    style: TextStyle(fontSize: 12.5, color: kFg54),
                  ),
                  const SizedBox(height: 14),
                  GradientButton(label: 'Export & Share JSON', busy: _busy, onPressed: _export),
                ],
              ),
            ),
          ),
          if (counts != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last export', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kFg70)),
                    const SizedBox(height: 8),
                    ...counts.entries.where((e) => e.value > 0).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            Expanded(child: Text(e.key, style: TextStyle(fontSize: 12, color: kFg54))),
                            Text('${e.value} rows', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Note: this is a data export, not an automatic restore — the file is for safe-keeping and manual recovery.',
            style: TextStyle(fontSize: 11, color: kFg38),
          ),
        ],
      ),
    );
  }
}
