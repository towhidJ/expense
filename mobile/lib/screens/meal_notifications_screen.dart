import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// In-app notification feed (v19), filled by DB triggers — new meal request,
/// request response, notice, join request. Opening the screen marks
/// everything read.
class MealNotificationsScreen extends StatefulWidget {
  const MealNotificationsScreen({
    super.key,
    required this.state,
    required this.membership,
  });
  final AppState state;
  final MealGroupMember membership;

  @override
  State<MealNotificationsScreen> createState() => _MealNotificationsScreenState();
}

class _MealNotificationsScreenState extends State<MealNotificationsScreen> {
  AppState get state => widget.state;
  String get groupId => widget.membership.groupId;

  List<MealNotification>? _notifications;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await state.fetchMealNotifications(groupId);
      if (!mounted) return;
      setState(() => _notifications = rows);
      if (rows.any((n) => !n.isRead)) {
        // mark read after showing, so the unread highlight is visible once
        await state.markMealNotificationsRead(groupId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'request_new':
        return Icons.pending_actions;
      case 'request_response':
        return Icons.task_alt;
      case 'notice':
        return Icons.campaign_outlined;
      case 'join_request':
        return Icons.person_add_alt;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime ts) {
    final mins = DateTime.now().difference(ts).inMinutes;
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    final hours = mins ~/ 60;
    if (hours < 24) return '${hours}h ago';
    final days = hours ~/ 24;
    if (days < 7) return '${days}d ago';
    return '${ts.day}/${ts.month}/${ts.year}';
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold))),
      body: notifications == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : notifications.isEmpty
              ? Center(
                  child: Text('Nothing yet — requests, notices and join alerts show here.',
                      style: TextStyle(color: kFg38, fontSize: 13)))
              : RefreshIndicator(
                  color: kCyan,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: notifications.map((n) => Card(
                          child: ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (n.isRead ? kFg54 : kCyan).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_icon(n.type), size: 18, color: n.isRead ? kFg54 : kCyan),
                            ),
                            title: Text(n.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                                )),
                            subtitle: Text(
                              '${n.body.isNotEmpty ? '${n.body}\n' : ''}${_timeAgo(n.createdAt)}',
                              style: TextStyle(fontSize: 11, color: kFg38),
                            ),
                            isThreeLine: n.body.isNotEmpty,
                            trailing: IconButton(
                              icon: Icon(Icons.close, size: 16, color: kFg24),
                              onPressed: () async {
                                try {
                                  await state.deleteMealNotification(n.id);
                                  await _load();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                }
                              },
                            ),
                          ),
                        )).toList(),
                  ),
                ),
    );
  }
}
