import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../ota_update.dart';
import '../theme.dart';
import 'activity_screen.dart';
import 'assets_screen.dart';
import 'backup_screen.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'charity_screen.dart';
import 'committee_screen.dart';
import 'debt_payoff_screen.dart';
import 'documents_screen.dart';
import 'emi_screen.dart';
import 'family_screen.dart';
import 'finance_notifications_screen.dart';
import 'forecast_screen.dart';
import 'goals_screen.dart';
import 'insights_screen.dart';
import 'insurance_screen.dart';
import 'inventory_screen.dart';
import 'investments_screen.dart';
import 'invoicing_screen.dart';
import 'lending_screen.dart';
import 'liabilities_screen.dart';
import 'meals_screen.dart';
import 'pocket_money_screen.dart';
import 'premium_screen.dart';
import 'reconcile_screen.dart';
import 'recurring_screen.dart';
import 'rent_screen.dart';
import 'reports_screen.dart';
import 'savings_screen.dart';
import 'scan_receipt_screen.dart';
import 'splitter_screen.dart';
import 'subscriptions_screen.dart';
import 'tax_screen.dart';
import 'transfers_screen.dart';
import 'utility_screen.dart';
import 'vehicle_screen.dart';
import 'warranty_screen.dart';
import 'zakat_screen.dart';

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

    // Module keys are the shared premium-gating contract with the web app
    // (module_access.module_key, v39). null key = never gated (e.g. Alerts).
    final features = <(IconData, String, Color, Widget Function(), String?)>[
      (Icons.restaurant, 'Meals', kEmerald, () => MealsScreen(state: state), 'meals'),
      (Icons.pie_chart_outline, 'Reports', kPurple, () => ReportsScreen(state: state), 'reports'),
      (Icons.account_balance_wallet_outlined, 'Budgets', kCyan, () => BudgetsScreen(state: state), 'budgets'),
      (Icons.notifications_active_outlined, 'Alerts', kRed, () => FinanceNotificationsScreen(state: state), null),
      (Icons.flag_outlined, 'Goals', kEmerald, () => GoalsScreen(state: state), 'goals'),
      (Icons.savings_outlined, 'Savings', kOrange, () => SavingsScreen(state: state), 'savings'),
      (Icons.swap_horiz, 'Transfers', kCyan, () => TransfersScreen(state: state), 'transfers'),
      (Icons.repeat, 'Recurring', kPurple, () => RecurringScreen(state: state), 'recurring'),
      (Icons.sell_outlined, 'Categories', kOrange, () => CategoriesScreen(state: state), 'categories'),
      (Icons.two_wheeler_outlined, 'Assets', kOrange, () => AssetsScreen(state: state), 'assets'),
      (Icons.shield_outlined, 'Liabilities', kRed, () => LiabilitiesScreen(state: state), 'liabilities'),
      (Icons.trending_up, 'Investments', kEmerald, () => InvestmentsScreen(state: state), 'investments'),
      (Icons.people_outline, 'Family', kCyan, () => FamilyScreen(state: state), 'family'),
      (Icons.handshake_outlined, 'Dena-Paona', kOrange, () => LendingScreen(state: state), 'lending'),
      (Icons.query_stats, 'Forecast', kCyan, () => ForecastScreen(state: state), 'forecast'),
      (Icons.mosque_outlined, 'Zakat', kEmerald, () => ZakatScreen(state: state), 'zakat'),
      (Icons.subscriptions_outlined, 'Subscriptions', kPurple, () => SubscriptionsScreen(state: state), 'subscriptions'),
      (Icons.health_and_safety_outlined, 'Insurance', kCyan, () => InsuranceScreen(state: state), 'insurance'),
      (Icons.bolt_outlined, 'Utility Bills', kOrange, () => UtilityScreen(state: state), 'utility'),
      (Icons.apartment_outlined, 'Rent', kEmerald, () => RentScreen(state: state), 'rent'),
      (Icons.verified_outlined, 'Warranty', kPurple, () => WarrantyScreen(state: state), 'warranty'),
      (Icons.call_split, 'Bill Splitter', kCyan, () => SplitterScreen(state: state), 'splitter'),
      (Icons.receipt_long_outlined, 'Tax', kRed, () => TaxScreen(state: state), 'tax'),
      (Icons.auto_awesome_outlined, 'AI Insights', kPurple, () => InsightsScreen(state: state), 'insights'),
      (Icons.document_scanner_outlined, 'Scan Receipt', kEmerald, () => ScanReceiptScreen(state: state), 'scan'),
      (Icons.calculate_outlined, 'EMI Calculator', kCyan, () => EmiScreen(state: state), 'emi'),
      (Icons.trending_down, 'Debt Payoff', kRed, () => DebtPayoffScreen(state: state), 'debt-payoff'),
      (Icons.local_gas_station_outlined, 'Vehicle', kOrange, () => VehicleScreen(state: state), 'vehicle'),
      (Icons.groups_outlined, 'Committee', kPurple, () => CommitteeScreen(state: state), 'committee'),
      (Icons.child_care_outlined, 'Pocket Money', kPurple, () => PocketMoneyScreen(state: state), 'pocket-money'),
      (Icons.volunteer_activism_outlined, 'Charity', kEmerald, () => CharityScreen(state: state), 'charity'),
      (Icons.receipt_outlined, 'Invoicing', kCyan, () => InvoicingScreen(state: state), 'invoicing'),
      (Icons.inventory_2_outlined, 'Inventory', kOrange, () => InventoryScreen(state: state), 'inventory'),
      (Icons.manage_search_outlined, 'Reconcile', kCyan, () => ReconcileScreen(state: state), 'reconcile'),
      (Icons.folder_special_outlined, 'Documents', kEmerald, () => DocumentsScreen(state: state), 'documents'),
      (Icons.history, 'Activity Log', kOrange, () => ActivityScreen(state: state), 'activity'),
      (Icons.cloud_download_outlined, 'Backup', kCyan, () => BackupScreen(state: state), 'backup'),
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
          children: features.map((f) {
            final locked = f.$5 != null && state.isLocked(f.$5!);
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _push(
                    context,
                    locked
                        ? PremiumScreen(state: state, lockedLabel: f.$2)
                        : f.$4()),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
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
                        if (locked)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: kOrange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.lock, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(f.$2, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.workspace_premium_outlined,
                    color: state.subActive ? kEmerald : kOrange),
                title: Text(
                    state.subActive
                        ? (state.subIsTrial ? 'Free trial active' : 'Premium active')
                        : 'Go Premium',
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                    state.subActive
                        ? (state.subLifetime ? 'Lifetime' : 'Manage your subscription')
                        : 'Unlock all Premium modules',
                    style: TextStyle(fontSize: 11, color: kFg38)),
                trailing: Icon(Icons.chevron_right, color: kFg24),
                onTap: () => _push(context, PremiumScreen(state: state)),
              ),
              Divider(height: 1, color: kFg.withValues(alpha: 0.06)),
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
