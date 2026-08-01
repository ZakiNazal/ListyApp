import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_notification.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

/// Looks up a single profile by uid.
///
/// Lists store `ownerUid` / `assignedToUid`, not names, so every screen that
/// wants to say "from Yaser" needs this. Riverpod caches per-uid, so a list of
/// twenty lists from the same three people costs three reads, not twenty.
final userByIdProvider = FutureProvider.family<AppUser?, String>((
  ref,
  uid,
) async {
  if (uid.isEmpty) return null;
  final doc = await ref.watch(firestoreProvider).collection('users').doc(uid).get();
  return doc.exists ? AppUser.fromDoc(doc) : null;
});

/// The display name for a uid, falling back to something readable rather than
/// leaking a raw Firebase uid into the UI.
final userLabelProvider = Provider.family<String, String>((ref, uid) {
  final user = ref.watch(userByIdProvider(uid)).valueOrNull;
  if (user == null) return 'Someone';
  return user.label;
});

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

final userNotificationsProvider = StreamProvider.family<List<ActivityNotification>, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(ActivityNotification.fromDoc).toList());
});

class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  Future<AppUser?> byId(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  /// Batch lookup used when several lists need their sender resolved at once.
  Future<Map<String, AppUser>> byIds(Iterable<String> uids) async {
    final unique = uids.where((u) => u.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const {};

    // whereIn caps at 30, same as the contacts matcher.
    const limit = 30;
    final chunks = <List<String>>[];
    for (var i = 0; i < unique.length; i += limit) {
      chunks.add(unique.sublist(i, (i + limit).clamp(0, unique.length)));
    }

    final snapshots = await Future.wait(
      chunks.map(
        (chunk) => _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get(),
      ),
    );

    return {
      for (final snapshot in snapshots)
        for (final doc in snapshot.docs) doc.id: AppUser.fromDoc(doc),
    };
  }

  /// Maps E.164 numbers to the uid that owns them, for numbers that have
  /// registered. Used to resolve outstanding invites.
  Future<Map<String, String>> byPhones(List<String> phones) async {
    final unique = phones.where((p) => p.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const {};

    // whereIn caps at 30, same as the contacts matcher.
    const limit = 30;
    final chunks = <List<String>>[];
    for (var i = 0; i < unique.length; i += limit) {
      chunks.add(unique.sublist(i, (i + limit).clamp(0, unique.length)));
    }

    final snapshots = await Future.wait(
      chunks.map(
        (chunk) => _db.collection('users').where('phone', whereIn: chunk).get(),
      ),
    );

    return {
      for (final snapshot in snapshots)
        for (final doc in snapshot.docs)
          if ((doc.data()['phone'] as String?)?.isNotEmpty ?? false)
            doc.data()['phone'] as String: doc.id,
    };
  }

  Future<void> markNotificationsSeen(String uid) =>
      _db.collection('users').doc(uid).update(<String, dynamic>{
        'lastSeenNotifications': FieldValue.serverTimestamp(),
      });

  /// Drops a notification into [targetUid]'s feed.
  ///
  /// [fromUid] must be the signed-in user: the security rules reject any
  /// notification that is not stamped with its real author, which is what stops
  /// one account spamming another's feed.
  Future<void> sendNotification({
    required String targetUid,
    required String fromUid,
    required String listId,
    required String message,
  }) async {
    // Never notify yourself -- acting on your own list would otherwise ping you.
    if (targetUid == fromUid) return;

    final doc =
        _db.collection('users').doc(targetUid).collection('notifications').doc();
    await doc.set(<String, dynamic>{
      'fromUid': fromUid,
      'listId': listId,
      // Trimmed to the rules' 300-char cap so a long list title cannot make
      // the write bounce.
      'message': message.length > 300 ? message.substring(0, 300) : message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markNotificationRead(String uid, String notificationId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}
