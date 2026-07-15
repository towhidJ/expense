import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// Budget overspend / bill-due alerts (v28), server-generated daily by
/// check_budget_and_bill_alerts() — same push pipe as the meal module's
/// notifications, reusing the FCM registration from push_notifications.dart.
class FinanceNotificationsScreen extends StatefulWidget {
  const FinanceNotificationsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<FinanceNotificationsScreen> createState() => _FinanceNotificationsScreenState();
}

class _FinanceNotificationsScreenState extends State<FinanceNotificationsScreen> {
  AppState get state => widget.state;

  List<FinanceNotification>? _notifications;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await state.fetchFinanceNotifications();
      if (!mounted) return;
      setState(() => _notifications = rows);
      final unread = rows.where((n) => !n.isRead).map((n) => n.id).toList();
      if (unread.isNotEmpty) await state.markFinanceNotificationsRead(unread);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  IconData _icon(String type) => switch (type) {
        'budget_overspend' => Icons.warning_amber_rounded,
        'recurring_posted' => Icons.repeat_rounded,
        'weekly_digest' => Icons.pie_chart_outline_rounded,
        'goal_milestone' => Icons.flag_rounded,
        'large_expense' => Icons.trending_up_rounded,
        _ => Icons.event_busy_outlined,
      };

  Color _color(String type) => switch (type) {
        'budget_overspend' || 'large_expense' => kRed,
        'recurring_posted' => kCyan,
        'weekly_digest' => kPurple,
        'goal_milestone' => kEmerald,
        _ => kOrange,
      };

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
      appBar: AppBar(title: const Text('Alerts', style: TextStyle(fontWeight: FontWeight.bold))),
      body: notifications == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : notifications.isEmpty
              ? Center(
                  child: Text('Nothing yet — budget overspend and bill-due reminders show here.',
                      style: TextStyle(color: kFg38, fontSize: 13), textAlign: TextAlign.center))
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
                                color: (n.isRead ? kFg54 : _color(n.type)).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_icon(n.type), size: 18, color: n.isRead ? kFg54 : _color(n.type)),
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
                                  await state.deleteFinanceNotification(n.id);
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
