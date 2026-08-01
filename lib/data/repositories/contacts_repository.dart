import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/phone_utils.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

/// One row in the "Select user" sheet.
///
/// When [registeredUser] is non-null the contact already has a Listy account,
/// so the row is tappable and selects them. When it is null the row shows the
/// blue "Invite" link instead -- this is exactly the two row states drawn in
/// the Figma frame.
class ContactEntry {
  const ContactEntry({
    required this.displayName,
    required this.phone,
    this.photo,
    this.registeredUser,
  });

  final String displayName;

  /// E.164.
  final String phone;
  final Uint8List? photo;
  final AppUser? registeredUser;

  bool get isRegistered => registeredUser != null;

  String get initials => AppUser.initialsOf(displayName);
}

/// The full picker payload: registered contacts first, then invitable ones.
class ContactDirectory {
  const ContactDirectory({
    this.registered = const [],
    this.invitable = const [],
  });

  final List<ContactEntry> registered;
  final List<ContactEntry> invitable;

  bool get isEmpty => registered.isEmpty && invitable.isEmpty;

  /// Case-insensitive filter used by the search field.
  ContactDirectory search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return this;
    bool matches(ContactEntry c) =>
        c.displayName.toLowerCase().contains(q) || c.phone.contains(q);
    return ContactDirectory(
      registered: registered.where(matches).toList(),
      invitable: invitable.where(matches).toList(),
    );
  }
}

class ContactsPermissionDenied implements Exception {
  const ContactsPermissionDenied({required this.permanently});

  /// True when the OS will no longer show a prompt (Android "Don't ask again",
  /// or a restriction such as parental controls). The UI must send the user to
  /// system settings rather than asking again.
  final bool permanently;
}

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepository(ref.watch(firestoreProvider)),
);

/// Loads the device address book and marks which contacts are Listy users.
final contactDirectoryProvider = FutureProvider<ContactDirectory>((ref) async {
  final me = ref.watch(currentAppUserProvider).valueOrNull;
  return ref.watch(contactsRepositoryProvider).loadDirectory(currentUser: me);
});

class ContactsRepository {
  ContactsRepository(this._db);

  final FirebaseFirestore _db;

  /// Firestore caps `whereIn` at 30 values per query, so contact phone numbers
  /// are matched in chunks of this size and the results merged.
  static const int _whereInLimit = 30;

  /// Opens the system settings page for this app, for the permanently-denied
  /// case. Routed through flutter_contacts so the app needs no separate
  /// permissions plugin.
  Future<void> openSettings() => FlutterContacts.permissions.openSettings();

  Future<ContactDirectory> loadDirectory({AppUser? currentUser}) async {
    final status =
        await FlutterContacts.permissions.request(PermissionType.read);

    // `limited` is iOS 18+, where the user picked a subset of contacts to
    // share. That is still usable -- we just see fewer of them.
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      throw ContactsPermissionDenied(
        permanently: status == PermissionStatus.permanentlyDenied ||
            status == PermissionStatus.restricted,
      );
    }

    // id and displayName always come back; everything else must be requested.
    // Only phones and a thumbnail are needed, and asking for less keeps the
    // fetch fast on large address books.
    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.phone,
        ContactProperty.photoThumbnail,
      },
    );

    // Contacts are stored in whatever format the user typed, so fold every
    // number to E.164 against the signed-in user's own country code.
    final dialCode = PhoneUtils.dialCodeOf(currentUser?.phone);

    // phone -> best display name. A person can have several numbers and several
    // numbers can collapse to the same E.164, so de-duplicate on the number.
    final byPhone = <String, String>{};
    final photos = <String, Uint8List?>{};

    for (final contact in contacts) {
      final name = contact.displayName?.trim() ?? '';
      for (final phone in contact.phones) {
        // Android hands back an E.164 `normalizedNumber` for free; fall back to
        // the raw number elsewhere. Either way it goes through normalize so the
        // result is validated and consistent.
        final normalized = PhoneUtils.normalize(
          phone.normalizedNumber ?? phone.number,
          dialCode: dialCode,
        );
        if (normalized == null) continue;
        if (normalized == currentUser?.phone) continue; // never list yourself
        byPhone.putIfAbsent(normalized, () => name.isEmpty ? normalized : name);
        photos.putIfAbsent(normalized, () => contact.photo?.thumbnail);
      }
    }

    if (byPhone.isEmpty) return const ContactDirectory();

    final matches = await _findRegistered(byPhone.keys.toList());

    final registered = <ContactEntry>[];
    final invitable = <ContactEntry>[];

    byPhone.forEach((phone, name) {
      final entry = ContactEntry(
        displayName: name,
        phone: phone,
        photo: photos[phone],
        registeredUser: matches[phone],
      );
      (entry.isRegistered ? registered : invitable).add(entry);
    });

    int byName(ContactEntry a, ContactEntry b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    registered.sort(byName);
    invitable.sort(byName);

    return ContactDirectory(registered: registered, invitable: invitable);
  }

  /// Queries `users` for any profile whose `phone` matches one of [phones].
  Future<Map<String, AppUser>> _findRegistered(List<String> phones) async {
    final results = <String, AppUser>{};

    final chunks = <List<String>>[];
    for (var i = 0; i < phones.length; i += _whereInLimit) {
      chunks.add(phones.sublist(
        i,
        (i + _whereInLimit).clamp(0, phones.length),
      ));
    }

    // Run the chunks concurrently -- a 500-contact address book is ~17 queries.
    final snapshots = await Future.wait(
      chunks.map(
        (chunk) => _db.collection('users').where('phone', whereIn: chunk).get(),
      ),
    );

    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        final user = AppUser.fromDoc(doc);
        if (user.phone.isNotEmpty) results[user.phone] = user;
      }
    }

    return results;
  }
}
