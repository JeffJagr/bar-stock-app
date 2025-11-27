import 'dart:async';

import 'package:flutter/foundation.dart';

/// Centralized error reporter to collect uncaught and handled exceptions.
class ErrorReporter {
  const ErrorReporter._();

  /// Routes Flutter framework errors into the zone handler so we can
  /// capture them together with any other uncaught exceptions.
  static void recordFlutterError(FlutterErrorDetails details) {
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  }

  /// Used as the zone error handler entrypoint (see [runZonedGuarded]).
  static void recordZoneError(Object error, StackTrace stackTrace) {
    _presentError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'SmartBarApp',
      ),
    );
  }

  /// Logs explicit exceptions that we have already caught.
  static void logException(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) {
    _presentError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'SmartBarApp',
        context: reason != null ? ErrorDescription(reason) : null,
      ),
    );
  }

  /// Logs non-exception messages (e.g. validation failures) as errors so that
  /// crash/reporting tooling can inspect them if needed.
  static void logMessage(String message) {
    _presentError(
      FlutterErrorDetails(
        exception: FlutterError(message),
        stack: StackTrace.current,
        library: 'SmartBarApp',
      ),
    );
  }

  static void _presentError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
  }
}
