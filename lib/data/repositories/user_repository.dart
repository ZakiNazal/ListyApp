import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> markNotificationsSeen(String uid) =>
      _db.collection('users').doc(uid).update(<String, dynamic>{
        'lastSeenNotifications': FieldValue.serverTimestamp(),
      });
}
