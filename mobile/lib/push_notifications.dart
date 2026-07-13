import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'app_state.dart';

/// Registers this device for FCM push and mirrors the current token into
/// `fcm_tokens` (v22 migration) via the `register_fcm_token` RPC. Call once
/// after a session exists (see main.dart's AuthGate) — Firebase must already
/// be initialized via [initFirebase].
Future<void> initFirebase() async {
  await Firebase.initializeApp();
}

Future<void> registerPushToken() async {
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission();
  if (settings.authorizationStatus == AuthorizationStatus.denied) return;

  final token = await messaging.getToken();
  if (token != null) await _upsertToken(token);

  messaging.onTokenRefresh.listen(_upsertToken);
}

Future<void> _upsertToken(String token) async {
  try {
    await supabase.rpc('register_fcm_token', params: {
      'p_token': token,
      'p_platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    });
  } catch (_) {
    // Best-effort — a failed registration just means this device won't get
    // push until the next successful retry (e.g. next app launch).
  }
}

/// Wire up foreground message + notification-tap handling. [onLink] is
/// called with the notification's `link` field (mirrors meal_notifications'
/// `link` column) so the caller can navigate, matching the in-app bell's
/// existing tap behavior.
void listenForPushMessages({required void Function(String? link) onLink}) {
  FirebaseMessaging.onMessage.listen((message) {
    // Foreground messages don't auto-show a system notification; the in-app
    // notification bell (NotificationsList-equivalent) already covers this
    // case on next refresh, so foreground pushes are intentionally silent
    // here rather than duplicating a banner.
  });
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    onLink(message.data['link'] as String?);
  });
}
