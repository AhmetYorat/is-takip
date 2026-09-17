import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../models/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Raw Firebase auth state (signed in / signed out).
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// The signed-in user's `users/{uid}` profile document, including `role`.
/// Null while signed out or before the profile doc has been written.
///
/// Self-healing: if a user is authenticated but has no profile doc (e.g. it
/// was deleted out-of-band, or a previous registration attempt failed
/// after the Auth account was created), this recreates it once so the app
/// never gets stuck waiting for a doc that will never appear on its own.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.valueOrNull;
  if (user == null) return Stream.value(null);

  final docRef = FirebaseFirestore.instance
      .collection(FirestoreCollections.users)
      .doc(user.uid);
  var creatingProfile = false;

  return docRef.snapshots().asyncMap((doc) async {
    if (doc.exists) return AppUser.fromFirestore(doc);
    // Skip self-heal while the `deleteAccount` Cloud Function is deleting
    // this exact doc — the still-signed-in client would otherwise recreate
    // it out from under the deletion (see accountDeletionInProgressProvider).
    if (!creatingProfile && !ref.read(accountDeletionInProgressProvider)) {
      creatingProfile = true;
      await docRef.set(defaultUserProfileMap(user));
    }
    return null;
  });
});

/// True for the brief window between requesting server-side account
/// deletion and the client actually signing out. Guards
/// [currentAppUserProvider]'s self-heal from racing the `deleteAccount`
/// Cloud Function: the client is still authenticated while the function
/// deletes `users/{uid}`, and without this flag that doc-missing event
/// would make the client recreate the very profile being deleted.
final accountDeletionInProgressProvider = StateProvider<bool>((ref) => false);

/// Default `users/{uid}` document for a freshly authenticated user. `role`
/// always starts as `personel` here — `assignPatronRoleOnCreate` (Cloud
/// Function) corrects it to `patron` for the first-ever user.
Map<String, dynamic> defaultUserProfileMap(User user) {
  final fallbackName = user.displayName?.trim();
  return {
    'name': (fallbackName != null && fallbackName.isNotEmpty)
        ? fallbackName
        : (user.email?.split('@').first ?? ''),
    'email': user.email ?? '',
    'role': AppRole.personel,
    'fcmTokens': <String>[],
    'createdAt': FieldValue.serverTimestamp(),
  };
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

/// Wraps Firebase email/password auth. Role assignment on registration is
/// intentionally NOT done here: the `users/{uid}` doc is created with no
/// role, and the `assignPatronRoleOnCreate` Cloud Function assigns
/// `patron` (first user) or `personel` (everyone after) server-side so a
/// client can never grant itself the patron role.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;
    await credential.user!.updateDisplayName(name.trim());
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(uid)
        .set({...defaultUserProfileMap(credential.user!), 'name': name.trim()});
  }

  /// Lets a signed-in user fix their own display name — e.g. if it was
  /// ever defaulted to their email prefix (see `defaultUserProfileMap`'s
  /// self-heal fallback) because Firebase Auth had no displayName set.
  /// Updates both Firebase Auth (so any future self-heal has a real name
  /// to fall back to) and the Firestore profile doc (what the app
  /// actually displays).
  Future<void> updateOwnName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final trimmed = name.trim();
    await user.updateDisplayName(trimmed);
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .update({'name': trimmed});
  }

  Future<void> signOut() => _auth.signOut();

  /// Permanently deletes the signed-in user's account: the Firebase Auth
  /// user itself (not a soft-disable — required by Apple guideline
  /// 5.1.1(v)) plus their personal Firestore data, via the `deleteAccount`
  /// Cloud Function (server-side, so it isn't subject to client
  /// firestore.rules and doesn't require a recent login). Does not sign
  /// out locally — call [signOut] afterwards once the caller is done
  /// (e.g. after clearing [accountDeletionInProgressProvider]).
  Future<void> deleteAccount() async {
    await FirebaseFunctions.instance.httpsCallable('deleteAccount').call();
  }
}

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'weak-password':
        return 'Şifre çok zayıf (en az 6 karakter).';
      case 'network-request-failed':
        return 'Bağlantı hatası. İnternetinizi kontrol edin.';
      default:
        return 'Bir hata oluştu: ${error.message ?? error.code}';
    }
  }
  if (error is FirebaseFunctionsException) {
    return 'Bir hata oluştu: ${error.message ?? error.code}';
  }
  return 'Beklenmeyen bir hata oluştu.';
}
