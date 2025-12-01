/// Centralized stock thresholds for bar and warehouse views.
class StockThresholds {
  // Ratio thresholds for bar levels (0.0 - 1.0)
  static const double barCritical = 0.25; // red
  static const double barLow = 0.75; // yellow cutoff
  static const double barOk = 0.95; // green cutoff

  // Warehouse ratio thresholds (percentage of target)
  static const double warehouseLow = 0.3;
  static const double warehouseOk = 0.8;
}
