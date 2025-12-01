import 'dart:async';

import 'package:flutter/foundation.dart';

/// Handles inactivity timers and warning dispatch.
class SessionManager {
  SessionManager({
    required this.onTimeout,
    this.ownerTimeout = const Duration(minutes: 30),
    this.staffTimeout = const Duration(minutes: 20),
    this.warningDuration = const Duration(seconds: 10),
  });

  final Duration ownerTimeout;
  final Duration staffTimeout;
  final Duration warningDuration;
  final VoidCallback onTimeout;

  Timer? _timer;
  bool _isRunning = false;
  Duration _currentTimeout = Duration.zero;

  bool get isRunning => _isRunning;

  void startForOwner() {
    _start(ownerTimeout);
  }

  void startForStaff() {
    _start(staffTimeout);
  }

  void _start(Duration timeout) {
    _currentTimeout = timeout;
    resetTimer();
  }

  void resetTimer() {
    if (_currentTimeout == Duration.zero) return;
    _timer?.cancel();
    _isRunning = true;
    _timer = Timer(_currentTimeout, onTimeout);
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _currentTimeout = Duration.zero;
  }
}
