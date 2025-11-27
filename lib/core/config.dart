/// Overall application configuration shared between UI and logic layers.
enum AppEnvironment { dev, prod }

class AppConfig {
  /// Flag to toggle Firebase integrations when building for offline/demo modes.
  static const bool firebaseEnabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: true,
  );

  /// Owner/venue identifier placeholder that should be injected via CI/secrets.
  static const String ownerId = String.fromEnvironment(
    'APP_OWNER_ID',
    defaultValue: 'OWNER_ID_PLACEHOLDER',
  );

  /// Threshold at which the bar inventory shows low warnings.
  static const int barLowThreshold = 5;

  /// Threshold for low stock warnings in the warehouse view.
  static const int warehouseLowThreshold = 15;

  /// Current runtime environment (dev/prod) to gate analytics, logging, etc.
  static const AppEnvironment environment = AppEnvironment.dev;
}
