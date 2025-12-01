import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cloud_user_role.dart';
import 'firebase_service.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance;

  final FirebaseService _service;

  DocumentReference<Map<String, dynamic>> _doc(String userId) =>
      _service.usersCollection.doc(userId);

  Future<void> setRole(String userId, CloudUserRole role) {
    return _doc(userId).set(
      {
        'userId': userId,
        'role': role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<CloudUserRole?> fetchRole(String userId) async {
    final snapshot = await _doc(userId).get();
    final data = snapshot.data();
    if (data == null) return null;
    final rawRole = data['role'] as String?;
    if (rawRole == null) return null;
    for (final role in CloudUserRole.values) {
      if (role.name == rawRole) return role;
    }
    return null;
  }

  /// Removes the user profile document. Does not affect authentication
  /// credentials; the caller is responsible for auth user deletion/sign-out.
  Future<void> deleteUser(String userId) {
    return _doc(userId).delete();
  }
}
