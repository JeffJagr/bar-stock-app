import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/remote/backend_config.dart';

/// Centralized access point for Firebase Auth and Firestore instances.
/// No business logic lives here—only collection/document helpers.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  FirebaseFirestore? _db;
  FirebaseAuth? _auth;

  FirebaseFirestore get db => _db ??= FirebaseFirestore.instance;

  /// Backwards-compat alias used by existing repositories.
  FirebaseFirestore get firestore => db;

  FirebaseAuth get auth => _auth ??= FirebaseAuth.instance;

  /// Legacy single-bar storage (kept for backward compatibility until Phase C/D).
  CollectionReference<Map<String, dynamic>> get barsCollection =>
      db.collection(BackendConfig.barsCollection);

  DocumentReference<Map<String, dynamic>> barDocument(String barId) =>
      barsCollection.doc(_requireId(barId, 'barId'));

  /// Top-level companies collection for multi-tenant data.
  CollectionReference<Map<String, dynamic>> get companiesCollection =>
      db.collection('companies');

  DocumentReference<Map<String, dynamic>> companyDocument(
    String companyId,
  ) =>
      companiesCollection.doc(_requireId(companyId, 'companyId'));

  /// Common scoped sub-collections -------------------------------------------------
  CollectionReference<Map<String, dynamic>> groupsCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('groups');

  CollectionReference<Map<String, dynamic>> companyMembersCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('members');

  CollectionReference<Map<String, dynamic>> staffCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('staff');

  CollectionReference<Map<String, dynamic>> productsCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('products');

  CollectionReference<Map<String, dynamic>> inventoryCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('inventory');

  CollectionReference<Map<String, dynamic>> ordersCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('orders');

  CollectionReference<Map<String, dynamic>> historyCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('history');

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      db.collection('users');

  /// Ensures all business payloads carry the companyId field.
  Map<String, dynamic> withCompanyScope(
    String companyId,
    Map<String, dynamic> data,
  ) {
    return {
      ...data,
      'companyId': data['companyId'] ?? _requireId(companyId, 'companyId'),
    };
  }

  String _requireId(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName cannot be empty');
    }
    return trimmed;
  }
}
