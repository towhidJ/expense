import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Notice board (v18): manager posts announcements; everyone sees them.
/// Pinned notices also appear as a banner on the meal summary.
class MealNoticesScreen extends StatefulWidget {
  const MealNoticesScreen({
    super.key,
    required this.state,
    required this.membership,
    required this.isManager,
  });
  final AppState state;
  final MealGroupMember membership;
  final bool isManager;

  @override
  State<MealNoticesScreen> createState() => _MealNoticesScreenState();
}

class _MealNoticesScreenState extends State<MealNoticesScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  List<MealNotice>? _notices;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await state.fetchMealNotices(groupId);
      if (!mounted) return;
      setState(() => _notices = rows);
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

  Future<void> _noticeSheet({MealNotice? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final body = TextEditingController(text: existing?.body ?? '');
    var pinned = existing?.pinned ?? false;

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
                Text(existing == null ? 'New Notice' : 'Edit Notice',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                      labelText: 'Title', hintText: 'Mess meeting on Friday after dinner'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Details (optional)'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: pinned,
                  activeThumbColor: kCyan,
                  title: const Text('Pin this notice', style: TextStyle(fontSize: 14)),
                  subtitle: Text('Pinned notices show on the Summary',
                      style: TextStyle(fontSize: 11, color: kFg38)),
                  onChanged: (v) => setSheet(() => pinned = v),
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Save Notice',
                  onPressed: () {
                    if (title.text.trim().isNotEmpty) Navigator.pop(sheetContext, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;

    if (existing == null) {
      await _run(() => state.addMealNotice(groupId,
          title: title.text.trim(), body: body.text.trim(), pinned: pinned));
    } else {
      await _run(() => state.updateMealNotice(existing.id,
          title: title.text.trim(), body: body.text.trim(), pinned: pinned));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notices = _notices;
    return Scaffold(
      appBar: AppBar(title: const Text('Notice Board', style: TextStyle(fontWeight: FontWeight.bold))),
      floatingActionButton: widget.isManager
          ? FloatingActionButton.extended(
              onPressed: () => _noticeSheet(),
              backgroundColor: kCyan,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text('Notice', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: notices == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : notices.isEmpty
              ? Center(child: Text('No notices yet', style: TextStyle(color: kFg38)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  children: notices.map((n) => Card(
                        child: ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (n.pinned ? kOrange : kFg54).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(n.pinned ? Icons.push_pin : Icons.campaign_outlined,
                                size: 18, color: n.pinned ? kOrange : kFg54),
                          ),
                          title: Text(n.title, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${n.body.isNotEmpty ? '${n.body}\n' : ''}${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year}',
                            style: TextStyle(fontSize: 11, color: kFg38),
                          ),
                          isThreeLine: n.body.isNotEmpty,
                          trailing: widget.isManager
                              ? PopupMenuButton<String>(
                                  color: kCard,
                                  icon: Icon(Icons.more_vert, size: 18, color: kFg38),
                                  onSelected: (v) {
                                    if (v == 'edit') _noticeSheet(existing: n);
                                    if (v == 'delete') {
                                      _run(() => state.deleteMealNotice(n.id));
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('✏️ Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('🗑️ Delete', style: TextStyle(color: kRed))),
                                  ],
                                )
                              : null,
                        ),
                      )).toList(),
                ),
    );
  }
}
