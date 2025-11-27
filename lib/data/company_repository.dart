import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/company.dart';
import 'firebase_service.dart';

/// Handles company creation and membership queries.
class CompanyRepository {
  CompanyRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance;

  final FirebaseService _service;

  Future<String> createCompany({
    required String name,
    required String ownerUserId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Company name is required');
    }
    final companies = _service.companiesCollection;
    final doc = companies.doc();
    final payload = {
      'companyId': doc.id,
      'name': trimmed,
      'ownerUserId': ownerUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'memberIds': [ownerUserId],
    };
    await doc.set(payload);
    await _service.companyMembersCollection(doc.id).doc(ownerUserId).set({
      'userId': ownerUserId,
      'role': 'owner',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
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
}
