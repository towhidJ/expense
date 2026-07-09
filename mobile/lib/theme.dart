import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Theme mode (light/dark), persisted in SharedPreferences.
// Surface/text colors below are getters that read the current mode, so the
// whole app recolors when `appThemeMode` flips (MaterialApp rebuilds).
// ---------------------------------------------------------------------------
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.dark);

bool get isDark => appThemeMode.value != ThemeMode.light;

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  appThemeMode.value = (prefs.getBool('light_mode') ?? false) ? ThemeMode.light : ThemeMode.dark;
}

Future<void> setLightMode(bool light) async {
  appThemeMode.value = light ? ThemeMode.light : ThemeMode.dark;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('light_mode', light);
}

// Accents (same in both modes) — matches the web app's palette.
const kCyan = Color(0xFF06B6D4);
const kPurple = Color(0xFF8B5CF6);
const kEmerald = Color(0xFF10B981);
const kRed = Color(0xFFEF4444);
const kOrange = Color(0xFFF59E0B);

const kGradient = LinearGradient(colors: [kCyan, kPurple]);

// Mode-aware surfaces & foregrounds.
Color get kBg => isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF2F4FA);
Color get kCard => isDark ? const Color(0xFF12122A) : Colors.white;
Color get kFg => isDark ? Colors.white : const Color(0xFF111827);

// Alpha steps of the foreground — replaces the old hardcoded Colors.whiteXX.
Color get kFg70 => kFg.withValues(alpha: 0.70);
Color get kFg54 => kFg.withValues(alpha: isDark ? 0.54 : 0.62);
Color get kFg38 => kFg.withValues(alpha: isDark ? 0.38 : 0.48);
Color get kFg24 => kFg.withValues(alpha: isDark ? 0.24 : 0.34);
Color get kFg12 => kFg.withValues(alpha: 0.12);

final _money = NumberFormat('#,##0.##');
String taka(num v) => '৳${_money.format(v)}';

/// Fade + slide-up page route used everywhere for smooth navigation.
class _FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

ThemeData buildTheme({required bool dark}) {
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final bg = dark ? const Color(0xFF0A0A1A) : const Color(0xFFF2F4FA);
  final card = dark ? const Color(0xFF12122A) : Colors.white;
  final fg = dark ? Colors.white : const Color(0xFF111827);
  final border = fg.withValues(alpha: dark ? 0.08 : 0.09);

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    colorScheme: base.colorScheme.copyWith(
      primary: kCyan,
      secondary: kPurple,
      surface: card,
      error: kRed,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fg.withValues(alpha: dark ? 0.05 : 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: fg.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: fg.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kCyan),
      ),
      hintStyle: TextStyle(color: fg.withValues(alpha: 0.25)),
      labelStyle: TextStyle(color: fg.withValues(alpha: 0.5)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: card,
      selectedItemColor: kCyan,
      unselectedItemColor: fg.withValues(alpha: 0.38),
      type: BottomNavigationBarType.fixed,
    ),
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: card),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: card),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: kCyan,
      unselectedLabelColor: fg.withValues(alpha: 0.4),
      indicatorColor: kCyan,
      dividerColor: border,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _FadeSlideTransitionsBuilder(),
      TargetPlatform.iOS: _FadeSlideTransitionsBuilder(),
    }),
  );
}

/// Gradient "primary" button used across the app.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: kGradient, borderRadius: BorderRadius.circular(12)),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Staggered entrance: fades + slides its child up when first built.
/// Wrap list items with an increasing [index] for a smooth cascade.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 45 * widget.index.clamp(0, 10)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}
