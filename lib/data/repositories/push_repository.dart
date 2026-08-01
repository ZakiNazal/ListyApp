import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => PushRepository(ref.watch(firestoreProvider)),
);

/// Registers the device for push and keeps its token on the user document.
///
/// The Cloud Function in `functions/index.js` reads `users/{uid}.fcmTokens` and
/// pushes every notification document to those devices. Without this the app
/// only ever shows the in-app banner, which means nothing when the app is
/// closed -- the case that matters most for "someone sent you a list".
final pushRegistrationProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return;

  final repo = ref.watch(pushRepositoryProvider);
  await repo.register(uid);

  // Tokens rotate. Without this the user silently stops receiving pushes.
  final sub = FirebaseMessaging.instance.onTokenRefresh.listen(
    (token) => repo.saveToken(uid, token),
  );
  ref.onDispose(sub.cancel);
});

class PushRepository {
  PushRepository(this._db);

  final FirebaseFirestore _db;

  Future<void> register(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ and iOS both require an explicit grant. Declining is not an
      // error -- the app simply falls back to in-app banners only.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // iOS will not issue an FCM token until APNs has handed one over.
      final token = await messaging.getToken();
      if (token != null) await saveToken(uid, token);
    } catch (e) {
      // Push is an enhancement; never let it break sign-in.
      debugPrint('push registration failed: $e');
    }
  }

  /// arrayUnion so one account can receive on several devices at once.
  Future<void> saveToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update(<String, dynamic>{
        'fcmTokens': FieldValue.arrayUnion(<String>[token]),
      });
    } catch (e) {
      debugPrint('saving fcm token failed: $e');
    }
  }

  /// Drops this device's token so a signed-out phone stops receiving pushes
  /// for the account that used to be on it.
  Future<void> unregister(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _db.collection('users').doc(uid).update(<String, dynamic>{
        'fcmTokens': FieldValue.arrayRemove(<String>[token]),
      });
    } catch (e) {
      debugPrint('removing fcm token failed: $e');
    }
  }
}
