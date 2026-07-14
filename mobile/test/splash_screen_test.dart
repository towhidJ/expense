import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/screens/splash_screen.dart';

void main() {
  testWidgets('SplashGate shows the branded splash, then hands over to the app',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SplashGate(child: Scaffold(body: Text('APP'))),
    ));

    // First frame: splash is up, the app is not.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('TakaKhata'), findsOneWidget);
    expect(find.text('APP'), findsNothing);

    // Still up well past the first frame — this is the bug we fixed.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('APP'), findsNothing);

    // After the minimum hold plus the cross-fade, the app has taken over.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('APP'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
