import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'config.dart';
import 'push_notifications.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  await initFirebase();
  await loadThemeMode();
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'TakaKhata',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(dark: false),
        darkTheme: buildTheme(dark: true),
        themeMode: mode,
        home: const SplashGate(child: AuthGate()),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AppState _state = AppState();
  bool? _lockEnabled; // null = still reading prefs
  bool _unlocked = false;
  bool _pushRegistered = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _lockEnabled = prefs.getBool('biometric_lock') ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session == null) {
          _pushRegistered = false;
          return const LoginScreen();
        }
        if (!_pushRegistered) {
          _pushRegistered = true;
          // Fire-and-forget: registerPushToken already swallows its own
          // errors, so a denied/unavailable permission never blocks login.
          registerPushToken();
        }
        if (_lockEnabled == null) {
          return Scaffold(body: Center(child: CircularProgressIndicator(color: kCyan)));
        }
        if (_lockEnabled! && !_unlocked) {
          return BiometricLockScreen(onUnlocked: () => setState(() => _unlocked = true));
        }
        return HomeShell(state: _state);
      },
    );
  }
}

/// Shown on launch when the fingerprint lock is enabled: the Supabase session
/// stays signed in, but the app's content is gated behind a biometric check.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final _auth = LocalAuthentication();
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Prompt as soon as the screen appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock TakaKhata',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (ok) {
        widget.onUnlocked();
      } else if (mounted) {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: kGradient, shape: BoxShape.circle),
                child: const Icon(Icons.fingerprint, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text('TakaKhata Locked',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kFg)),
              const SizedBox(height: 6),
              Text('Use your fingerprint to unlock',
                  style: TextStyle(fontSize: 13, color: kFg38)),
              const SizedBox(height: 28),
              if (_failed)
                SizedBox(
                  width: 220,
                  child: GradientButton(label: 'Try Again', onPressed: () {
                    setState(() => _failed = false);
                    _tryUnlock();
                  }),
                ),
              TextButton(
                onPressed: () => supabase.auth.signOut(),
                child: Text('Sign out instead', style: TextStyle(color: kFg38, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
