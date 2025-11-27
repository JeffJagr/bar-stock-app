class AppConstants {
  static const double barGreenThreshold = 0.95;
  static const double barYellowThreshold = 0.75;
  static const double barLowThreshold = 0.95;
  static const double warehouseLowThreshold = 0.30;
  static const bool warehouseTrackingEnabled =
      bool.fromEnvironment('WAREHOUSE_TRACKING_ENABLED', defaultValue: true);
  static const double restockClampMax = 9999.0;
  static const int historyMaxEntries = 500;
  static const int undoMaxEntries = 50;
  static const Duration undoTimeLimit = Duration(minutes: 5);
}
