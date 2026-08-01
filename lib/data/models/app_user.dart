import 'package:cloud_firestore/cloud_firestore.dart';

/// A registered Listy user. Stored at `users/{uid}`.
///
/// [phone] is always E.164 and is the field the contacts picker matches on,
/// so it must be kept in sync with whatever Firebase Auth reports.
class AppUser {
  const AppUser({
    required this.uid,
    required this.phone,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.lastSeenNotifications,
  });

  final String uid;
  final String phone;
  final String? displayName;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastSeenNotifications;

  /// Name to show in lists, falling back to the phone number.
  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : phone;

  /// Up to two initials for the avatar placeholder.
  String get initials => initialsOf(displayName);

  /// Shared by [AppUser] and by device contacts, which have no uid.
  static String initialsOf(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      phone: (data['phone'] as String?) ?? '',
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastSeenNotifications: (data['lastSeenNotifications'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'phone': phone,
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        if (lastSeenNotifications != null)
          'lastSeenNotifications': Timestamp.fromDate(lastSeenNotifications!),
      };

  AppUser copyWith({String? displayName, String? photoUrl}) => AppUser(
        uid: uid,
        phone: phone,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt,
        lastSeenNotifications: lastSeenNotifications,
      );
}
