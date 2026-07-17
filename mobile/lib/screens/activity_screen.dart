import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Read-only audit trail (v35) — rows are written by DB triggers on
/// transactions / transfers / liabilities / accounts.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<ActivityEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.state.fetchActivity();
    if (mounted) setState(() => _entries = rows);
  }

  (IconData, Color) _style(String action) => switch (action) {
        'created' => (Icons.add_circle_outline, kEmerald),
        'updated' => (Icons.edit_outlined, kCyan),
        _ => (Icons.delete_outline, kRed),
      };

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log', style: TextStyle(fontWeight: FontWeight.bold))),
      body: entries == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : entries.isEmpty
              ? Center(
                  child: Text('No activity recorded yet.\n(Requires migration v35 applied.)',
                      textAlign: TextAlign.center, style: TextStyle(color: kFg38)))
              : RefreshIndicator(
                  color: kCyan,
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      final (icon, color) = _style(e.action);
                      return Card(
                        child: ListTile(
                          dense: true,
                          leading: Icon(icon, color: color, size: 20),
                          title: Text(e.summary.isEmpty ? e.tableName : e.summary,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            '${e.action} · ${e.tableName} · ${DateFormat('MMM d, h:mm a').format(e.createdAt.toLocal())}',
                            style: TextStyle(fontSize: 11, color: kFg38),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
