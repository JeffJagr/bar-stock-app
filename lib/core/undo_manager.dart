import 'app_state.dart';
import 'constants.dart';
import 'models/staff_member.dart';

enum UndoActionKind {
  stockChange,
  orderChange,
}

class _UndoEntry {
  final AppState snapshot;
  final DateTime timestamp;
  final UndoActionKind kind;

  _UndoEntry({
    required this.snapshot,
    required this.timestamp,
    required this.kind,
  });
}

/// Handles capturing and restoring undoable state snapshots.
class UndoManager {
  UndoManager({
    Duration? timeLimit,
    int? maxEntries,
    Set<UndoActionKind>? allowedKinds,
  })  : maxEntries = maxEntries ?? AppConstants.undoMaxEntries,
        _timeLimit = timeLimit ?? AppConstants.undoTimeLimit,
        _allowedKinds = allowedKinds ??
            const {
              UndoActionKind.stockChange,
              UndoActionKind.orderChange,
            };

  final List<_UndoEntry> _undoStack = [];
  final Duration _timeLimit;
  final int maxEntries;
  final Set<UndoActionKind> _allowedKinds;

  bool get hasUndoEntries => _undoStack.isNotEmpty;

  bool hasUndoForRole(StaffRole? role) {
    final allowed = _allowedKindsForRole(role);
    return _undoStack.any((entry) => allowed.contains(entry.kind));
  }

  void pushSnapshot(AppState state, UndoActionKind kind) {
    if (!_allowedKinds.contains(kind)) return;
    _undoStack.add(
      _UndoEntry(
        snapshot: state.copy(),
        timestamp: DateTime.now(),
        kind: kind,
      ),
    );
    if (_undoStack.length > maxEntries) {
      _undoStack.removeAt(0);
    }
  }

  /// Returns the last valid snapshot respecting role-specific permissions.
  AppState? restoreLatestForRole(StaffRole? role) {
    final now = DateTime.now();
    final allowedKinds = _allowedKindsForRole(role);
    while (_undoStack.isNotEmpty) {
      final entry = _undoStack.removeLast();
      if (!allowedKinds.contains(entry.kind)) {
        continue;
      }
      final age = now.difference(entry.timestamp);
      if (age > _timeLimit) {
        continue;
      }
      return entry.snapshot.copy();
    }
    return null;
  }

  void clear() => _undoStack.clear();

  Set<UndoActionKind> _allowedKindsForRole(StaffRole? role) {
    if (role == StaffRole.worker) {
      return const {UndoActionKind.stockChange};
    }
    return const {UndoActionKind.stockChange, UndoActionKind.orderChange};
  }
}
