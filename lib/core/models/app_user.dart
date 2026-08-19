import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app/constants.dart';

/// A `users/{uid}` document. `role` is assigned by the
/// `assignPatronRoleOnCreate` Cloud Function (first registered user becomes
/// [AppRole.patron], everyone after becomes [AppRole.personel]); a patron
/// may later change another user's role from the Personeller screen.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.fcmTokens = const [],
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final List<String> fcmTokens;
  final DateTime? createdAt;

  bool get isPatron => role == AppRole.patron;
  bool get isPersonel => role == AppRole.personel;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? AppRole.personel,
      fcmTokens:
          (data['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'name': name,
    'email': email,
    'role': role,
    'fcmTokens': fcmTokens,
    'createdAt': FieldValue.serverTimestamp(),
  };

  AppUser copyWith({String? name, String? role}) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role ?? this.role,
      fcmTokens: fcmTokens,
      createdAt: createdAt,
    );
  }
}
