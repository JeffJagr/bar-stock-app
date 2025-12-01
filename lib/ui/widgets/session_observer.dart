import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../core/app_notifier.dart';

/// Observes auth/session state and triggers callbacks on sign-out or invalid state.
class SessionObserver extends StatefulWidget {
  const SessionObserver({
    super.key,
    required this.notifier,
    required this.child,
    this.auth,
    required this.onSignedOut,
    required this.onInvalidState,
  });

  final FirebaseAuth? auth;
  final AppNotifier notifier;
  final VoidCallback onSignedOut;
  final VoidCallback onInvalidState;
  final Widget child;

  @override
  State<SessionObserver> createState() => _SessionObserverState();
}

class _SessionObserverState extends State<SessionObserver> {
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = widget.auth?.authStateChanges().listen((user) {
      if (user == null) {
        widget.onSignedOut();
      }
    });
    widget.notifier.addListener(_onNotifierChanged);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    widget.notifier.removeListener(_onNotifierChanged);
    super.dispose();
  }

  void _onNotifierChanged() {
    final state = widget.notifier.state;
    // If staff/user context exists but company is missing, treat as invalid.
    if (state.activeCompanyId == null &&
        (widget.notifier.currentStaffMember != null ||
            widget.notifier.currentUserId != null)) {
      widget.onInvalidState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
