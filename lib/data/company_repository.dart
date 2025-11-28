import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cloud_user_role.dart';
import '../models/company.dart';
import '../models/company_member.dart';
import 'firebase_service.dart';

/// Handles company creation, membership management and join-by-code lookups.
class CompanyRepository {
  CompanyRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance,
        _random = Random();

  final FirebaseService _service;
  final Random _random;

  Future<Company> createCompany({
    required String name,
    required String ownerUserId,
    String? ownerEmail,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Company name is required');
    }
    final companies = _service.companiesCollection;
    final doc = companies.doc();
    final joinCode = _generateJoinCode();
    final businessId = await _generateUniqueBusinessId();
    final payload = {
      'companyId': doc.id,
      'name': trimmed,
      'ownerUserId': ownerUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'joinCode': joinCode,
      'businessId': businessId,
      'memberIds': [ownerUserId],
    };
    await doc.set(payload);
    await _setMembership(
      companyId: doc.id,
      userId: ownerUserId,
      email: ownerEmail,
      role: CloudUserRole.owner,
    );
    return Company(
      companyId: doc.id,
      name: trimmed,
      ownerUserId: ownerUserId,
      createdAt: DateTime.now(),
      joinCode: joinCode,
      businessId: businessId,
    );
  }

  Stream<List<Company>> watchUserCompanies(String userId) {
    final query =
        _service.companiesCollection.where('memberIds', arrayContains: userId);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Company.fromJson({
                ...doc.data(),
                'companyId': doc.id,
              }))
          .toList(),
    );
  }

  Future<Company?> fetchCompanyByCode(String joinCode) async {
    final snapshot = await _service.companiesCollection
        .where('joinCode', isEqualTo: joinCode.trim().toUpperCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Company.fromJson({
      ...doc.data(),
      'companyId': doc.id,
    });
  }

  Future<Company?> fetchCompanyByBusinessId(String businessId) async {
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
      {'businessId': normalized},
      SetOptions(merge: true),
    );
    return normalized;
  }

  Future<void> joinCompany({
    required Company company,
    required String userId,
    String? email,
  }) async {
    await _service.companiesCollection.doc(company.companyId).set({
      'memberIds': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
    await _setMembership(
      companyId: company.companyId,
      userId: userId,
      email: email,
      role: CloudUserRole.worker,
    );
  }

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
    }, SetOptions(merge: true));
  }

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

  Future<String> regenerateJoinCode(String companyId) async {
    final newCode = _generateJoinCode();
    await _service.companyDocument(companyId).set(
      {'joinCode': newCode},
      SetOptions(merge: true),
    );
    return newCode;
  }

  Future<String> regenerateBusinessId(String companyId) async {
    final newCode = await _generateUniqueBusinessId();
    await _service.companyDocument(companyId).set(
      {'businessId': newCode},
      SetOptions(merge: true),
    );
    return newCode;
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
