import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/invite.dart';
import 'auth_repository.dart';
import 'user_repository.dart';

final inviteRepositoryProvider = Provider<InviteRepository>(
  (ref) => InviteRepository(ref.watch(firestoreProvider)),
);

/// Invites the signed-in user has sent.
final myInvitesProvider = StreamProvider<List<Invite>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream<List<Invite>>.value(const []);
  return ref.watch(inviteRepositoryProvider).watchInvites(uid);
});

/// Checks which invited numbers now belong to registered users and stamps
/// `acceptedUid` on those invites.
///
/// Watched by the Invited Friends screen, so resolution happens whenever the
/// inviter looks -- no Cloud Function required.
final resolveInvitesProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final invites = ref.watch(myInvitesProvider).valueOrNull ?? const <Invite>[];
  if (uid == null || invites.isEmpty) return;

  final unresolved = invites
      .where((i) => !i.accepted && i.phone.isNotEmpty)
      .map((i) => i.phone)
      .toSet()
      .toList();
  if (unresolved.isEmpty) return;

  final users = await ref.read(userRepositoryProvider).byPhones(unresolved);
  if (users.isEmpty) return;

  await ref
      .read(inviteRepositoryProvider)
      .resolveJoined(inviterUid: uid, phoneToUid: users);
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

  /// Stamps `acceptedUid` on invites whose number now belongs to a real user.
  ///
  /// `acceptedUid` and the "Joined" chip existed but nothing ever set them, so
  /// an invited friend who actually joined still showed as pending forever.
  ///
  /// Resolution runs on the inviter's side rather than the invitee's: the
  /// inviter already owns these documents, and matching phones against `users`
  /// is a query the rules permit. The reverse -- the new user hunting for
  /// invites addressed to their number -- is a query Firestore will not allow,
  /// because the rule could not be proven from the query's constraints.
  /// [phoneToUid] maps an E.164 number to the uid that now owns it.
  Future<void> resolveJoined({
    required String inviterUid,
    required Map<String, String> phoneToUid,
  }) async {
    if (phoneToUid.isEmpty || inviterUid.isEmpty) return;

    // Only this user's own invites -- the query the rules permit.
    final mine = await _invites
        .where('invitedByUid', isEqualTo: inviterUid)
        .get();

    final batch = _db.batch();
    var writes = 0;

    for (final doc in mine.docs) {
      final data = doc.data();
      final joinedUid = phoneToUid[data['phone'] as String? ?? ''];
      if (joinedUid == null) continue;
      if ((data['acceptedUid'] as String?) == joinedUid) continue;

      batch.update(doc.reference, <String, dynamic>{'acceptedUid': joinedUid});
      writes++;
    }

    if (writes > 0) await batch.commit();
  }
}
