import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../ota_update.dart';
import '../theme.dart';
import 'assets_screen.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'family_screen.dart';
import 'finance_notifications_screen.dart';
import 'goals_screen.dart';
import 'investments_screen.dart';
import 'liabilities_screen.dart';
import 'meals_screen.dart';
import 'recurring_screen.dart';
import 'reports_screen.dart';
import 'savings_screen.dart';
import 'transfers_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  AppState get state => widget.state;
  bool _bioLock = false;
  String _version = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _bioLock = prefs.getBool('biometric_lock') ?? false);
    });
    currentVersionName().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    await checkForUpdate(context, manual: true);
    if (mounted) setState(() => _checkingUpdate = false);
  }

  Future<void> _toggleBioLock(bool enable) async {
    final auth = LocalAuthentication();
    if (enable) {
      try {
        final supported = await auth.isDeviceSupported();
        if (!supported) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No fingerprint/screen lock is set up on this device.')));
          }
          return;
        }
        // Confirm the fingerprint works before turning the lock on.
        final ok = await auth.authenticate(
          localizedReason: 'Confirm fingerprint to enable app lock',
          options: const AuthenticationOptions(stickyAuth: true),
        );
        if (!ok) return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometric error: $e')));
        }
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_lock', enable);
    if (mounted) setState(() => _bioLock = enable);
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    bool busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password', helperText: 'At least 6 characters'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = supabase.auth.currentUser?.email;
                      if (email == null) return;
                      if (next.text.length < 6 || next.text != confirm.text) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Passwords must match and be at least 6 characters.')));
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        // Verify the current password first — updateUser alone doesn't check it.
                        await supabase.auth.signInWithPassword(email: email, password: current.text);
                        await supabase.auth.updateUser(UserAttributes(password: next.text));
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password changed successfully!')));
                        }
                      } on AuthException catch (e) {
                        setState(() => busy = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.statusCode == '400'
                                  ? 'Current password is incorrect'
                                  : e.message)));
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'User';

    final features = <(IconData, String, Color, Widget Function())>[
      (Icons.restaurant, 'Meals', kEmerald, () => MealsScreen(state: state)),
      (Icons.pie_chart_outline, 'Reports', kPurple, () => ReportsScreen(state: state)),
      (Icons.account_balance_wallet_outlined, 'Budgets', kCyan, () => BudgetsScreen(state: state)),
      (Icons.notifications_active_outlined, 'Alerts', kRed, () => FinanceNotificationsScreen(state: state)),
      (Icons.flag_outlined, 'Goals', kEmerald, () => GoalsScreen(state: state)),
      (Icons.savings_outlined, 'Savings', kOrange, () => SavingsScreen(state: state)),
      (Icons.swap_horiz, 'Transfers', kCyan, () => TransfersScreen(state: state)),
      (Icons.repeat, 'Recurring', kPurple, () => RecurringScreen(state: state)),
      (Icons.sell_outlined, 'Categories', kOrange, () => CategoriesScreen(state: state)),
      (Icons.two_wheeler_outlined, 'Assets', kOrange, () => AssetsScreen(state: state)),
      (Icons.shield_outlined, 'Liabilities', kRed, () => LiabilitiesScreen(state: state)),
      (Icons.trending_up, 'Investments', kEmerald, () => InvestmentsScreen(state: state)),
      (Icons.people_outline, 'Family', kCyan, () => FamilyScreen(state: state)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: kGradient, shape: BoxShape.circle),
              child: Text(
                (user?.email ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            title: Text(fullName),
            subtitle: Text(user?.email ?? '',
                style: TextStyle(fontSize: 12, color: kFg.withValues(alpha: 0.35))),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: features
              .map((f) => Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _push(context, f.$4()),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: f.$3.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(f.$1, color: f.$3, size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(f.$2, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: kOrange),
                title: const Text('Light Mode', style: TextStyle(fontSize: 14)),
                subtitle: Text(isDark ? 'Dark theme active' : 'Light theme active',
                    style: TextStyle(fontSize: 11, color: kFg38)),
                value: !isDark,
                activeThumbColor: kCyan,
                onChanged: (v) => setLightMode(v),
              ),
              Divider(height: 1, color: kFg.withValues(alpha: 0.06)),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint, color: kEmerald),
                title: const Text('Fingerprint Lock', style: TextStyle(fontSize: 14)),
                subtitle: Text('Require fingerprint to open the app',
                    style: TextStyle(fontSize: 11, color: kFg38)),
                value: _bioLock,
                activeThumbColor: kCyan,
                onChanged: _toggleBioLock,
              ),
              Divider(height: 1, color: kFg.withValues(alpha: 0.06)),
              ListTile(
                leading: const Icon(Icons.key, color: kPurple),
                title: const Text('Change Password', style: TextStyle(fontSize: 14)),
                trailing: Icon(Icons.chevron_right, color: kFg24),
                onTap: () => _changePassword(context),
              ),
              Divider(height: 1, color: kFg.withValues(alpha: 0.06)),
              ListTile(
                leading: const Icon(Icons.system_update, color: kCyan),
                title: const Text('Check for Updates', style: TextStyle(fontSize: 14)),
                subtitle: Text(_version.isEmpty ? '' : 'Current version: v$_version',
                    style: TextStyle(fontSize: 11, color: kFg38)),
                trailing: _checkingUpdate
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kCyan))
                    : Icon(Icons.chevron_right, color: kFg24),
                onTap: _checkingUpdate ? null : _checkUpdate,
              ),
              Divider(height: 1, color: kFg.withValues(alpha: 0.06)),
              ListTile(
                leading: const Icon(Icons.logout, color: kRed),
                title: const Text('Sign Out', style: TextStyle(fontSize: 14, color: kRed)),
                onTap: () => supabase.auth.signOut(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
