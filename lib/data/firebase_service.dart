import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/remote/backend_config.dart';

/// Centralized access point for Firebase Auth and Firestore instances.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  FirebaseFirestore get firestore =>
      _firestore ??= FirebaseFirestore.instance;
  FirebaseAuth get auth => _auth ??= FirebaseAuth.instance;

  /// Legacy single-bar storage (kept for backward compatibility until Phase C/D).
  CollectionReference<Map<String, dynamic>> get barsCollection =>
      firestore.collection(BackendConfig.barsCollection);

  DocumentReference<Map<String, dynamic>> barDocument(String barId) =>
      barsCollection.doc(barId);

  /// Top-level companies collection for multi-tenant data.
  CollectionReference<Map<String, dynamic>> get companiesCollection =>
      firestore.collection('companies');

  DocumentReference<Map<String, dynamic>> companyDocument(
    String companyId,
  ) =>
      companiesCollection.doc(companyId);

  /// Common scoped sub-collections -------------------------------------------------
  CollectionReference<Map<String, dynamic>> groupsCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('groups');

  CollectionReference<Map<String, dynamic>> companyMembersCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('members');

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

  CollectionReference<Map<String, dynamic>> staffCollection(
    String companyId,
  ) =>
      companyDocument(companyId).collection('staff');
}
