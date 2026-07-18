import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../theme.dart';

const _durationMeta = {
  'monthly': ('Monthly', '/month'),
  'yearly': ('Yearly', '/year'),
  'lifetime': ('Lifetime', 'one-time'),
};

/// Paywall + subscription status + manual bKash/Nagad payment submission.
/// Mirrors the web PremiumGate paywall; admin verification happens on web.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, required this.state, this.lockedLabel});
  final AppState state;
  final String? lockedLabel; // the module the user tried to open, if any

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  AppState get state => widget.state;

  List<Map<String, dynamic>>? _requests;
  String? _duration;
  String _method = 'bkash';
  final _trxId = TextEditingController();
  final _sender = TextEditingController();
  final _amount = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await state.refreshBillingState();
    try {
      final rows = await state.myPremiumRequests();
      if (!mounted) return;
      setState(() => _requests = rows);
    } catch (_) {
      if (mounted) setState(() => _requests = []);
    }
    // Preselect the first enabled duration.
    if (_duration == null) {
      final ds = _enabledDurations();
      if (ds.isNotEmpty) {
        setState(() {
          _duration = ds.first.$1;
          _amount.text = _fmtNum(ds.first.$2);
        });
      }
    }
  }

  List<(String, num)> _enabledDurations() {
    final b = state.billing;
    if (b == null) return [];
    return [
      for (final d in ['monthly', 'yearly', 'lifetime'])
        if (b['${d}_enabled'] == true) (d, (b['${d}_price'] as num?) ?? 0),
    ];
  }

  String _fmtNum(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Future<void> _submit() async {
    if (_duration == null) return;
    if (_trxId.text.trim().length < 4) {
      _snack('Please enter the transaction ID from your payment.');
      return;
    }
    if (_sender.text.trim().length < 6) {
      _snack('Please enter the mobile number you paid from.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await state.submitSubscriptionRequest(
        duration: _duration!,
        method: _method,
        trxId: _trxId.text.trim(),
        senderNumber: _sender.text.trim(),
        amount: double.tryParse(_amount.text),
      );
      _trxId.clear();
      _sender.clear();
      _snack('Request submitted! You will be notified once the payment is verified.');
      await _load();
    } catch (e) {
      _snack(e is PostgrestException ? e.message : 'Error: $e');
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('Copied: $text');
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests?.where((r) => r['status'] == 'pending').firstOrNull;
    final durations = _enabledDurations();
    final b = state.billing;

    return Scaffold(
      appBar: AppBar(title: const Text('Premium', style: TextStyle(fontWeight: FontWeight.bold))),
      body: RefreshIndicator(
        color: kCyan,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status / header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kOrange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.workspace_premium_outlined, color: kOrange, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.subActive
                          ? (state.subLifetime
                              ? 'Lifetime Premium active'
                              : state.subIsTrial
                                  ? "You're on a free trial"
                                  : 'Premium active')
                          : widget.lockedLabel != null
                              ? '${widget.lockedLabel} is a Premium module'
                              : 'Go Premium',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.subActive
                          ? (state.subLifetime
                              ? 'Enjoy every Premium module forever.'
                              : state.subIsTrial
                                  ? 'Your trial ends ${DateFormat('d MMM yyyy').format(state.subExpiresAt!)}. Subscribe below to keep Premium after it ends.'
                                  : 'Active until ${DateFormat('d MMM yyyy').format(state.subExpiresAt!)}')
                          : 'One subscription unlocks every Premium module in TakaKhata.',
                      style: TextStyle(fontSize: 12.5, color: kFg54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            if ((!state.subActive || state.subIsTrial) && pending == null) ...[
              const SizedBox(height: 12),
              // Pricing cards
              if (durations.isNotEmpty)
                Row(
                  children: [
                    for (final (i, d) in durations.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() {
                            _duration = d.$1;
                            _amount.text = _fmtNum(d.$2);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _duration == d.$1
                                  ? kOrange.withValues(alpha: 0.12)
                                  : kFg.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _duration == d.$1
                                    ? kOrange.withValues(alpha: 0.5)
                                    : kFg.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(_durationMeta[d.$1]!.$1,
                                    style: TextStyle(fontSize: 11.5, color: kFg54)),
                                const SizedBox(height: 4),
                                Text('৳${_fmtNum(d.$2)}',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w700)),
                                Text(_durationMeta[d.$1]!.$2,
                                    style: TextStyle(fontSize: 10, color: kFg38)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: 12),
              // Payment instructions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Send the money',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      if (b?['bkash_number'] == null && b?['nagad_number'] == null)
                        Text('Payment numbers are not configured yet — contact the admin.',
                            style: TextStyle(fontSize: 12.5, color: kOrange))
                      else ...[
                        if (b?['bkash_number'] != null)
                          _payNumberTile('bKash (${b?['bkash_account_type'] ?? 'personal'})',
                              b!['bkash_number'], const Color(0xFFE2136E)),
                        if (b?['nagad_number'] != null)
                          _payNumberTile('Nagad (${b?['nagad_account_type'] ?? 'personal'})',
                              b!['nagad_number'], kOrange),
                      ],
                      if ((b?['instructions'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kFg.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(b!['instructions'],
                              style: TextStyle(fontSize: 12.5, color: kFg54, height: 1.4)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Submit form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('2. Submit the transaction ID',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final m in ['bkash', 'nagad']) ...[
                            if (m == 'nagad') const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(m == 'bkash' ? 'bKash' : 'Nagad'),
                              selected: _method == m,
                              selectedColor: (m == 'bkash'
                                      ? const Color(0xFFE2136E)
                                      : kOrange)
                                  .withValues(alpha: 0.2),
                              onSelected: (_) => setState(() => _method = m),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _trxId,
                        decoration: const InputDecoration(
                            labelText: 'Transaction ID', hintText: 'e.g. 9HK7A2B3C4'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sender,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            labelText: 'Number you paid from', hintText: '01XXXXXXXXX'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount sent (৳)'),
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        label: _submitting ? 'Submitting…' : 'Submit for verification',
                        onPressed: _submitting || durations.isEmpty ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (pending != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Icon(Icons.hourglass_top, color: kOrange, size: 30),
                      const SizedBox(height: 8),
                      const Text('Waiting for verification',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        'Your ${pending['duration']} request (${pending['method']}, '
                        'trx ${pending['trx_id']}) is being reviewed. You\'ll get a '
                        'notification when it\'s approved. Pull down to refresh.',
                        style: TextStyle(fontSize: 12.5, color: kFg54, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Request history
            if ((_requests ?? []).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('MY REQUESTS',
                  style: TextStyle(
                      fontSize: 11, letterSpacing: 1.2, color: kFg38, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final r in _requests!)
                Card(
                  child: ListTile(
                    leading: Icon(
                      r['status'] == 'approved'
                          ? Icons.check_circle_outline
                          : r['status'] == 'rejected'
                              ? Icons.cancel_outlined
                              : Icons.hourglass_top,
                      size: 20,
                      color: r['status'] == 'approved'
                          ? kEmerald
                          : r['status'] == 'rejected'
                              ? kRed
                              : kOrange,
                    ),
                    title: Text(
                      '${r['duration']} • ${r['method']} • ${r['trx_id']}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      '${DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(r['created_at']).toLocal())}'
                      '${r['status'] == 'rejected' && r['reject_reason'] != null ? '\n${r['reject_reason']}' : ''}',
                      style: TextStyle(fontSize: 11, color: kFg38),
                    ),
                    trailing: Text(r['status'],
                        style: TextStyle(fontSize: 11, color: kFg54)),
                  ),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _payNumberTile(String label, String number, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _copy(number),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 11, color: kFg54)),
                    Text(number,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ],
                ),
              ),
              Icon(Icons.copy, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
