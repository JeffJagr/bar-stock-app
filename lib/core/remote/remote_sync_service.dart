import 'dart:async';

import '../app_state.dart';
import 'remote_repository.dart';

typedef RemoteStateListener = void Function(AppState state);

/// Listens for remote changes and forwards them to the UI layer.
class RemoteSyncService {
  RemoteSyncService({
    required this.repository,
    required this.onRemoteState,
  });

  final RemoteRepository repository;
  final RemoteStateListener onRemoteState;

  StreamSubscription<AppState?>? _subscription;
  String? _activeBarId;

  void start(String barId) {
    if (_activeBarId == barId && _subscription != null) return;
    _subscription?.cancel();
    _activeBarId = barId;
    _subscription = repository.watchState(barId).listen((remoteState) {
      if (remoteState != null) {
        onRemoteState(remoteState);
      }
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
