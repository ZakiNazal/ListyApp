import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

/// Emits the raw Firebase user, or null when signed out.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// The signed-in user's Firestore profile.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream<AppUser?>.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(auth.uid);
});

/// Result of asking Firebase to send an SMS code.
class OtpSession {
  const OtpSession({required this.verificationId, this.resendToken});

  final String verificationId;
  final int? resendToken;
}

class PhoneAuthFailure implements Exception {
  const PhoneAuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Sends an SMS verification code to [e164Phone].
  ///
  /// On Android the SMS can be auto-retrieved, in which case Firebase completes
  /// sign-in itself and [onAutoVerified] fires instead of [onCodeSent].
  Future<void> sendOtp({
    required String e164Phone,
    required void Function(OtpSession session) onCodeSent,
    required void Function(UserCredential credential) onAutoVerified,
    required void Function(PhoneAuthFailure failure) onFailed,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);
          await _ensureProfile(result.user, e164Phone);
          onAutoVerified(result);
        } on FirebaseAuthException catch (e) {
          onFailed(PhoneAuthFailure(_messageFor(e)));
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onFailed(PhoneAuthFailure(_messageFor(e)));
      },
      codeSent: (String verificationId, int? token) {
        onCodeSent(OtpSession(verificationId: verificationId, resendToken: token));
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // The auto-retrieval window closed; the user must type the code.
        // The verificationId stays valid, so nothing to do here.
      },
    );
  }

  /// Completes sign-in with the code the user typed.
  Future<AppUser> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String e164Phone,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      return await _ensureProfile(result.user, e164Phone);
    } on FirebaseAuthException catch (e) {
      throw PhoneAuthFailure(_messageFor(e));
    }
  }

  /// Creates the `users/{uid}` document on first sign-in, or refreshes the
  /// phone number on subsequent ones.
  ///
  /// This document is what makes a contact show up as an existing Listy user in
  /// the Select user sheet, so it must be written before the user lands on Home.
  Future<AppUser> _ensureProfile(User? user, String e164Phone) async {
    if (user == null) {
      throw const PhoneAuthFailure('Sign-in did not return a user.');
    }

    final doc = _users.doc(user.uid);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      await doc.set(<String, dynamic>{
        'phone': e164Phone,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if ((snapshot.data()?['phone'] as String?) != e164Phone) {
      await doc.update(<String, dynamic>{'phone': e164Phone});
    }

    return AppUser.fromDoc(await doc.get());
  }

  Stream<AppUser?> watchProfile(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  Future<void> updateDisplayName(String uid, String name) =>
      _users.doc(uid).update(<String, dynamic>{'displayName': name.trim()});

  Future<void> signOut() => _auth.signOut();

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'operation-not-allowed':
        // Three different console settings surface as this one code, so name
        // all three rather than sending the user hunting.
        return 'Phone sign-in is blocked by the Firebase project. Check: '
            '(1) Authentication > Sign-in method > Phone is enabled, '
            '(2) Authentication > Settings > SMS region policy allows this '
            'country, and (3) Project settings > Your apps has this app\'s '
            'SHA-1 and SHA-256 fingerprints. [${e.code}]';
      case 'invalid-phone-number':
        return 'That phone number is not valid.';
      case 'invalid-verification-code':
        return 'That code is not correct. Please try again.';
      case 'session-expired':
        return 'The code expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'missing-client-identifier':
        // Almost always a missing SHA-1/SHA-256 fingerprint in the Firebase
        // console, or google-services.json not re-downloaded after adding one.
        return 'This device could not be verified. Check the app\'s SHA '
            'fingerprints in the Firebase console.';
      default:
        // Keep the raw code visible: without it an unmapped Firebase error is
        // indistinguishable from any other failure.
        return '${e.message ?? 'Something went wrong.'} [${e.code}]';
    }
  }
}
