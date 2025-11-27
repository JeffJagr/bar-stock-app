import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/firebase_service.dart';
import '../app_state.dart';
import '../error_reporter.dart';
import 'backend_config.dart';

/// Defines read/write operations for remote persistence.
abstract class RemoteRepository {
  Future<AppState?> loadState(String barId);
  Future<void> saveState(String barId, AppState state);
  Stream<AppState?> watchState(String barId);
}

/// Firestore-backed implementation that stores a single AppState document.
class FirestoreRemoteRepository implements RemoteRepository {
  FirestoreRemoteRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance;

  final FirebaseService _service;

  DocumentReference<Map<String, dynamic>> _doc(String barId) {
    return _service.barDocument(barId);
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
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Failed to load remote state',
      );
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
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Failed to save remote state',
      );
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
          ErrorReporter.logException(
            err,
            stack,
            reason: 'Failed to parse remote snapshot',
          );
        }
      }
      return null;
    });
  }
}

/// Local-only stub used when Firebase/Firestore is disabled.
class LocalRemoteRepository implements RemoteRepository {
  const LocalRemoteRepository();

  @override
  Future<AppState?> loadState(String barId) async => null;

  @override
  Future<void> saveState(String barId, AppState state) async {}

  @override
  Stream<AppState?> watchState(String barId) =>
      const Stream<AppState?>.empty();
}
