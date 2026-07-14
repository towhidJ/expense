import 'package:flutter/material.dart';
import '../theme.dart';

/// Branded launch screen. The native splash (flutter_native_splash) only lives
/// until Flutter paints its first frame — a few hundred milliseconds — so this
/// picks up the same logo and holds it for [_minVisible] before handing over to
/// the app, giving the launch a visible identity on every cold start.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.86, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: kPurple.withValues(alpha: 0.35),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/branding/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('TakaKhata',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Manage your finances with ease',
                    style: TextStyle(color: kFg38, fontSize: 13)),
                const SizedBox(height: 32),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kCyan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Holds [SplashScreen] on screen for a minimum beat, then cross-fades to
/// [child] (the real app). Without the floor the splash would blink out as soon
/// as the first frame lands and the user would never register it.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  static const _minVisible = Duration(milliseconds: 1600);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _elapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(SplashGate._minVisible, () {
      if (mounted) setState(() => _elapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _elapsed ? widget.child : const SplashScreen(),
    );
  }
}
