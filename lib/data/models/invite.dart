import 'package:cloud_firestore/cloud_firestore.dart';

/// Someone the user invited from the Select user sheet who had no Listy
/// account at the time. Stored at `invites/{inviteId}`.
///
/// This exists so the "Invited Friends" screen has something to show. Firebase
/// cannot tell you who you texted, so the invite is recorded locally-then-
/// remotely at the moment the SMS composer opens.
class Invite {
  const Invite({
    required this.id,
    required this.invitedByUid,
    required this.name,
    required this.phone,
    this.acceptedUid,
    this.createdAt,
  });

  final String id;
  final String invitedByUid;
  final String name;

  /// E.164, matched against `users.phone` to detect that they joined.
  final String phone;

  /// Set once someone with this number registers.
  final String? acceptedUid;
  final DateTime? createdAt;

  bool get accepted => acceptedUid != null;

  factory Invite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Invite(
      id: doc.id,
      invitedByUid: (data['invitedByUid'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      acceptedUid: data['acceptedUid'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> newInviteMap({
    required String invitedByUid,
    required String name,
    required String phone,
  }) => <String, dynamic>{
    'invitedByUid': invitedByUid,
    'name': name,
    'phone': phone,
    'acceptedUid': null,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
