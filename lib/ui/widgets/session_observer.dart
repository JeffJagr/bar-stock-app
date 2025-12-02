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
  bool _hadAuthSession = false;

  @override
  void initState() {
    super.initState();
    _authSub = widget.auth?.authStateChanges().listen((user) {
      if (user == null) {
        if (_hadAuthSession) {
        widget.onSignedOut();
      }
      } else {
        _hadAuthSession = true;
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
    final hasCompany = state.activeCompanyId != null;
    final hasStaffContext = widget.notifier.currentStaffMember != null ||
        state.activeStaffId != null;

    // Only treat as invalid if staff context exists without a company.
    // Owners are allowed to be signed in before choosing a company.
    if (!hasCompany && hasStaffContext) {
      widget.notifier.setCurrentStaffMember(null);
      widget.notifier.setActiveStaffId(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
