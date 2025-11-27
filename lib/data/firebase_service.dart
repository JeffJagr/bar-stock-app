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

  CollectionReference<Map<String, dynamic>> get barsCollection =>
      firestore.collection(BackendConfig.barsCollection);

  DocumentReference<Map<String, dynamic>> barDocument(String barId) =>
      barsCollection.doc(barId);
}
