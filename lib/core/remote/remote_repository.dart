import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../app_state.dart';
import 'backend_config.dart';

/// Defines read/write operations for remote persistence.
abstract class RemoteRepository {
  Future<AppState?> loadState(String barId);
  Future<void> saveState(String barId, AppState state);
  Stream<AppState?> watchState(String barId);
}

/// Firestore-backed implementation that stores a single AppState document.
class FirestoreRemoteRepository implements RemoteRepository {
  FirestoreRemoteRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String barId) {
    return _firestore
        .collection(BackendConfig.barsCollection)
        .doc(barId);
  }

  @override
  Future<AppState?> loadState(String barId) async {
    try {
      final snapshot = await _doc(barId).get();
      if (!snapshot.exists) return null;
      final raw = snapshot.data();
      final stateMap = raw?[BackendConfig.stateField];
      if (stateMap is Map<String, dynamic>) {
        return AppState.fromJson(stateMap);
      }
    } catch (err, stack) {
      debugPrint('Failed to load remote state: $err');
      debugPrint('$stack');
    }
    return null;
  }

  @override
  Future<void> saveState(String barId, AppState state) async {
    try {
      await _doc(barId).set({
        BackendConfig.stateField: state.toJson(),
        BackendConfig.updatedAtField: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (err, stack) {
      debugPrint('Failed to save remote state: $err');
      debugPrint('$stack');
    }
  }

  @override
  Stream<AppState?> watchState(String barId) {
    return _doc(barId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final raw = snapshot.data();
      final stateMap = raw?[BackendConfig.stateField];
      if (stateMap is Map<String, dynamic>) {
        try {
          return AppState.fromJson(stateMap);
        } catch (err, stack) {
          debugPrint('Failed to parse remote snapshot: $err');
          debugPrint('$stack');
        }
      }
      return null;
    });
  }
}
