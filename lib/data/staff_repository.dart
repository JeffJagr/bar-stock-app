import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/security/password_utils.dart';
import '../models/company_member.dart';
import '../models/staff_member.dart';
import 'firebase_service.dart';

/// Staff CRUD + PIN validation scoped per company.
class StaffRepository {
  StaffRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance;

  final FirebaseService _service;

  Future<String> createOrUpdateStaffMember({
    required String companyId,
    String? staffId,
    required String displayName,
    required String role,
    String? pin,
    bool isActive = true,
  }) async {
    final doc = staffId != null && staffId.isNotEmpty
        ? _service.staffCollection(companyId).doc(staffId)
        : _service.staffCollection(companyId).doc();

    final existingSnapshot = await doc.get();
    final existing = existingSnapshot.data();

    var pinHash = existing?['pinHash'] as String? ?? '';
    if (pin != null && pin.isNotEmpty) {
      pinHash = PasswordUtils.hashPassword(pin, companyId);
    }

    final payload = _service.withCompanyScope(companyId, {
      'staffId': doc.id,
      'displayName': displayName.trim(),
      'role': role.toLowerCase(),
      'pinHash': pinHash,
      'isActive': isActive,
      'pinSalt': companyId,
      'createdAt': existing?['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await doc.set(payload, SetOptions(merge: true));
    return doc.id;
  }

  Stream<List<CompanyStaffMember>> streamStaffForCompany(String companyId) {
    return _service.staffCollection(companyId).snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => CompanyStaffMember.fromJson({
                  ...doc.data(),
                  'staffId': doc.id,
                  'companyId': companyId,
                }),
              )
              .toList(),
        );
  }

  Future<CompanyStaffMember?> getStaffByPin({
    required String companyId,
    required String pin,
  }) async {
    final snapshot = await _service.staffCollection(companyId).get();
    for (final doc in snapshot.docs) {
      final member = CompanyStaffMember.fromJson({
        ...doc.data(),
        'staffId': doc.id,
        'companyId': companyId,
      });
      if (!member.isActive) continue;
      if (member.verifyPin(pin)) {
        return member;
      }
    }
    return null;
  }

  // Compatibility helpers for existing UI layers using CompanyMember ------------

  Future<List<CompanyMember>> listMembers(String companyId) async {
    final staff = await _service.staffCollection(companyId).get();
    return staff.docs
        .map(
          (doc) => _toCompanyMember(
            CompanyStaffMember.fromJson({
              ...doc.data(),
              'staffId': doc.id,
              'companyId': companyId,
            }),
          ),
        )
        .toList();
  }

  Future<CompanyMember?> findByPin({
    required String companyId,
    required String pin,
  }) async {
    final member = await getStaffByPin(companyId: companyId, pin: pin);
    if (member == null) return null;
    return _toCompanyMember(member);
  }

  Future<CompanyMember> createOrUpdateMember({
    required String companyId,
    String? memberId,
    required String displayName,
    required String role,
    String? pin,
    bool disabled = false,
  }) async {
    final id = await createOrUpdateStaffMember(
      companyId: companyId,
      staffId: memberId,
      displayName: displayName,
      role: role,
      pin: pin,
      isActive: !disabled,
    );
    final member = await getStaffById(companyId, id);
    if (member != null) return _toCompanyMember(member);
    return CompanyMember(
      memberId: id,
      companyId: companyId,
      displayName: displayName.trim(),
      role: role.toLowerCase(),
      pinHash: pin != null ? PasswordUtils.hashPassword(pin, companyId) : '',
      pinSalt: companyId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      disabled: disabled,
    );
  }

  Future<CompanyStaffMember?> getStaffById(
    String companyId,
    String staffId,
  ) async {
    final snap = await _service.staffCollection(companyId).doc(staffId).get();
    final data = snap.data();
    if (data == null) return null;
    return CompanyStaffMember.fromJson({
      ...data,
      'staffId': snap.id,
      'companyId': companyId,
    });
  }

  CompanyMember _toCompanyMember(CompanyStaffMember staff) {
    return CompanyMember(
      memberId: staff.staffId,
      companyId: staff.companyId,
      displayName: staff.displayName,
      role: staff.role,
      pinHash: staff.pinHash,
      pinSalt: staff.companyId,
      createdAt: staff.createdAt,
      updatedAt: staff.updatedAt,
      disabled: !staff.isActive,
    );
  }
}
