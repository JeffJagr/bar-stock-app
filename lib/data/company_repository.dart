import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cloud_user_role.dart';
import '../models/company.dart';
import '../models/company_member.dart';
import 'firebase_service.dart';

/// Company persistence helpers (no UI/business logic).
class CompanyRepository {
  CompanyRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance,
        _random = Random();

  final FirebaseService _service;
  final Random _random;

  /// Creates a company, generates a unique businessId, and returns the companyId.
  Future<String> createCompany({
    required String name,
    required String ownerUserId,
    String? ownerEmail,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Company name is required');
    }
    final doc = _service.companiesCollection.doc();
    final joinCode = _generateJoinCode();
    final businessId = await _generateUniqueBusinessId();
    final payload = _service.withCompanyScope(doc.id, {
      'companyId': doc.id,
      'name': trimmed,
      'ownerUserId': ownerUserId,
      'businessId': businessId,
      'joinCode': joinCode,
      'memberIds': [ownerUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await doc.set(payload);
    await _setMembership(
      companyId: doc.id,
      userId: ownerUserId,
      role: CloudUserRole.owner,
      email: ownerEmail,
    );
    return doc.id;
  }

  /// Streams companies a user belongs to.
  Stream<List<Company>> streamUserCompanies(String ownerUserId) {
    final query = _service.companiesCollection.where(
      'memberIds',
      arrayContains: ownerUserId,
    );
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Company.fromJson({
                  ...doc.data(),
                  'companyId': doc.id,
                }),
              )
              .toList(),
        );
  }

  Future<Company?> getCompanyByBusinessId(String businessId) async {
    final normalized = businessId.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final snapshot = await _service.companiesCollection
        .where('businessId', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Company.fromJson({
      ...doc.data(),
      'companyId': doc.id,
    });
  }

  Future<Company?> fetchCompany(String companyId) async {
    final snap = await _service.companyDocument(companyId).get();
    final data = snap.data();
    if (data == null) return null;
    return Company.fromJson({
      ...data,
      'companyId': snap.id,
    });
  }

  Future<void> regenerateBusinessId(String companyId) async {
    final newCode = await _generateUniqueBusinessId();
    await _service.companyDocument(companyId).set(
      {
        'companyId': companyId,
        'businessId': newCode,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> updateBusinessId(
    String companyId,
    String desiredBusinessId,
  ) async {
    final normalized = desiredBusinessId.trim().toUpperCase();
    final isValid = RegExp(r'^[A-Z0-9]{4,8}$').hasMatch(normalized);
    if (!isValid) {
      throw ArgumentError(
        'Business ID must be 4-8 characters, letters and numbers only.',
      );
    }
    final existing = await _service.companiesCollection
        .where('businessId', isEqualTo: normalized)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty &&
        existing.docs.first.id != companyId) {
      throw StateError('That Business ID is already taken');
    }
    await _service.companyDocument(companyId).set(
      {
        'companyId': companyId,
        'businessId': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return normalized;
  }

  // Backwards-compat helpers -------------------------------------------------

  Stream<Company> watchCompany(String companyId) {
    return _service.companyDocument(companyId).snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return Company.fromJson({
        ...data,
        'companyId': snapshot.id,
      });
    });
  }

  Stream<List<CompanyMember>> watchMembers(String companyId) {
    return _service.companyMembersCollection(companyId).snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => CompanyMember.fromJson({
                  ...doc.data(),
                  'memberId': doc.id,
                  'companyId': companyId,
                }),
              )
              .toList(),
        );
  }

  Future<Company?> fetchCompanyByCode(String joinCode) async {
    final normalized = joinCode.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final snapshot = await _service.companiesCollection
        .where('joinCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Company.fromJson({
      ...doc.data(),
      'companyId': doc.id,
    });
  }

  Future<String> regenerateJoinCode(String companyId) async {
    final newCode = _generateJoinCode();
    await _service.companyDocument(companyId).set(
      {
        'companyId': companyId,
        'joinCode': newCode,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return newCode;
  }

  Future<void> joinCompany({
    required Company company,
    required String userId,
    String? email,
  }) async {
    await _service.companyDocument(company.companyId).set(
      {
        'memberIds': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _setMembership(
      companyId: company.companyId,
      userId: userId,
      email: email,
      role: CloudUserRole.worker,
    );
  }

  /// Hard-deletes a company and its scoped subcollections. Intended for
  /// owner-driven account deletion flows. Does not delete auth credentials.
  Future<void> deleteCompanyCascade(String companyId) async {
    // Delete subcollections that hold company data. If collections are large,
    // this should be replaced with a backend-driven delete job.
    final collections = [
      _service.groupsCollection(companyId),
      _service.productsCollection(companyId),
      _service.inventoryCollection(companyId),
      _service.ordersCollection(companyId),
      _service.historyCollection(companyId),
      _service.staffCollection(companyId),
      _service.companyMembersCollection(companyId),
    ];
    for (final collection in collections) {
      final snapshot = await collection.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
    await _service.companyDocument(companyId).delete();
  }

  // Internal helpers ---------------------------------------------------------

  Future<void> _setMembership({
    required String companyId,
    required String userId,
    required CloudUserRole role,
    String? email,
  }) {
    return _service.companyMembersCollection(companyId).doc(userId).set({
      'userId': userId,
      'role': role.name,
      'userEmail': email,
      'createdAt': FieldValue.serverTimestamp(),
      'companyId': companyId,
    }, SetOptions(merge: true));
  }

  String _generateJoinCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(
      6,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return code;
  }

  Future<String> _generateUniqueBusinessId() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    while (true) {
      final candidate = List.generate(
        6,
        (_) => alphabet[_random.nextInt(alphabet.length)],
      ).join();
      final existing = await _service.companiesCollection
          .where('businessId', isEqualTo: candidate)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        return candidate;
      }
    }
  }
}
