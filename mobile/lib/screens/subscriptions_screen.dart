import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

/// View over recurring expenses flagged is_subscription (v35) — pause/resume
/// stops the auto-charge. Items are flagged on the Recurring screen.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<Recurring>? _recurring;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.state.fetchRecurring();
    if (mounted) setState(() => _recurring = rows);
  }

  @override
  Widget build(BuildContext context) {
    final subs = (_recurring ?? []).where((r) => r.isSubscription && r.type == 'expense').toList();
    final active = subs.where((s) => s.isActive).toList();
    final monthly = active.fold<double>(0, (s, r) => s + r.monthlyAmount);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _recurring == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : RefreshIndicator(
              color: kCyan,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Row(children: [
                    Expanded(child: _stat('Monthly Cost', taka(monthly), kRed)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Yearly Cost', taka(monthly * 12), kOrange)),
                    const SizedBox(width: 10),
                    Expanded(child: _stat('Active / Paused', '${active.length} / ${subs.length - active.length}', kCyan)),
                  ]),
                  const SizedBox(height: 14),
                  if (subs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          'No subscriptions yet.\nOn the Recurring screen, tick "Subscription" on items like Netflix or hosting.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kFg38, fontSize: 13),
                        ),
                      ),
                    ),
                  ...subs.map((sub) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: Opacity(
                            opacity: sub.isActive ? 1 : 0.55,
                            child: ListTile(
                              leading: Text(sub.categoryIcon, style: const TextStyle(fontSize: 22)),
                              title: Text(sub.title, style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                '${taka(sub.amount)}/${sub.frequency.replaceAll('ly', '')}'
                                '${sub.frequency != 'monthly' ? ' · ≈${taka(sub.monthlyAmount)}/month' : ''}'
                                '${sub.isActive ? ' · next ${DateFormat('MMM d').format(sub.nextRunDate)}' : ' · paused — saving ${taka(sub.monthlyAmount)}/mo 🎉'}',
                                style: TextStyle(fontSize: 11, color: kFg38),
                              ),
                              trailing: TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await widget.state.setRecurringActive(sub.id, !sub.isActive);
                                    _load();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  }
                                },
                                icon: Icon(sub.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                    size: 18, color: sub.isActive ? kOrange : kEmerald),
                                label: Text(sub.isActive ? 'Pause' : 'Resume',
                                    style: TextStyle(fontSize: 12, color: sub.isActive ? kOrange : kEmerald)),
                              ),
                            ),
                          ),
                        ),
                      )),
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
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
