import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/security/password_utils.dart';
import '../models/company_member.dart';
import 'firebase_service.dart';

/// Handles staff membership CRUD and PIN validation.
class StaffRepository {
  StaffRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance;

  final FirebaseService _service;

  Future<CompanyMember> createOrUpdateMember({
    required String companyId,
    String? memberId,
    required String displayName,
    required String role,
    String? pin,
    bool disabled = false,
  }) async {
    final doc = memberId != null && memberId.isNotEmpty
        ? _service.companyMembersCollection(companyId).doc(memberId)
        : _service.companyMembersCollection(companyId).doc();

    final existingSnapshot = await doc.get();
    final existing = existingSnapshot.data();

    var pinSalt = existing?['pinSalt'] as String? ?? '';
    var pinHash = existing?['pinHash'] as String? ?? '';
    if (pin != null && pin.isNotEmpty) {
      pinSalt = PasswordUtils.generateSalt();
      pinHash = PasswordUtils.hashPassword(pin, pinSalt);
    }

    final payload = {
      'memberId': doc.id,
      'companyId': companyId,
      'displayName': displayName.trim(),
      'role': role.toLowerCase(),
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'disabled': disabled,
      'createdAt': existing?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await doc.set(payload, SetOptions(merge: true));
    final persisted = await doc.get();
    return CompanyMember.fromJson({
      ...?persisted.data(),
      'memberId': doc.id,
      'companyId': companyId,
    });
  }

  Future<List<CompanyMember>> listMembers(String companyId) async {
    final snapshot =
        await _service.companyMembersCollection(companyId).get();
    return snapshot.docs
        .map(
          (doc) => CompanyMember.fromJson({
            ...doc.data(),
            'memberId': doc.id,
            'companyId': companyId,
          }),
        )
        .toList();
  }

  Future<CompanyMember?> findByPin({
    required String companyId,
    required String pin,
  }) async {
    final snapshot =
        await _service.companyMembersCollection(companyId).get();
    for (final doc in snapshot.docs) {
      final member = CompanyMember.fromJson({
        ...doc.data(),
        'memberId': doc.id,
        'companyId': companyId,
      });
      if (member.disabled) continue;
      if (member.verifyPin(pin)) {
        return member;
      }
    }
    return null;
  }
}
