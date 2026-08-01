import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/invite.dart';
import 'auth_repository.dart';

final inviteRepositoryProvider = Provider<InviteRepository>(
  (ref) => InviteRepository(ref.watch(firestoreProvider)),
);

/// Invites the signed-in user has sent.
final myInvitesProvider = StreamProvider<List<Invite>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream<List<Invite>>.value(const []);
  return ref.watch(inviteRepositoryProvider).watchInvites(uid);
});

class InviteRepository {
  InviteRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('invites');

  Stream<List<Invite>> watchInvites(String uid) => _invites
      .where('invitedByUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Invite.fromDoc).toList());

  /// Records an invite, or refreshes the existing one for the same number.
  ///
  /// Re-inviting is common (they ignored the first text), and a second row for
  /// the same person would be noise, so the phone number is the natural key.
  Future<void> record({
    required String invitedByUid,
    required String name,
    required String phone,
  }) async {
    final existing = await _invites
        .where('invitedByUid', isEqualTo: invitedByUid)
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update(<String, dynamic>{
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await _invites.add(
      Invite.newInviteMap(
        invitedByUid: invitedByUid,
        name: name,
        phone: phone,
      ),
    );
  }

  Future<void> cancel(String inviteId) => _invites.doc(inviteId).delete();
}
