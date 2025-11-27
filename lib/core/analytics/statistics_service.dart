import '../app_state.dart';
import '../models/history_entry.dart';

class ProductStats {
  final String productId;
  final String name;
  double ordered = 0;
  double delivered = 0;
  double restocked = 0;
  double used = 0;
  double currentBar = 0;
  double currentWarehouse = 0;

  ProductStats({
    required this.productId,
    required this.name,
  });
}

class TimeSeriesPoint {
  final DateTime date;
  final double value;

  TimeSeriesPoint(this.date, this.value);
}

class LineSeries {
  final String productId;
  final String label;
  final List<TimeSeriesPoint> points;

  LineSeries({
    required this.productId,
    required this.label,
    required this.points,
  });
}

class StatisticsResult {
  final List<ProductStats> productStats;
  final List<LineSeries> restockSeries;
  final List<LineSeries> usageSeries;

  StatisticsResult({
    required this.productStats,
    required this.restockSeries,
    required this.usageSeries,
  });

  double get totalOrdered =>
      productStats.fold(0, (sum, ps) => sum + ps.ordered);
  double get totalDelivered =>
      productStats.fold(0, (sum, ps) => sum + ps.delivered);
  double get totalRestocked =>
      productStats.fold(0, (sum, ps) => sum + ps.restocked);
  double get totalUsed =>
      productStats.fold(0, (sum, ps) => sum + ps.used);
}

/// Analytics helper that aggregates statistics from history entries.
/// In the future this can be swapped for remote API calls to leverage
/// server-side querying over large datasets.
class StatisticsService {
  static StatisticsResult calculate({
    required AppState state,
    required DateTime start,
    required DateTime end,
    required Set<String> productFilter,
  }) {
    final inventoryMap = {
      for (final item in state.inventory) item.product.id: item,
    };
    final filteredIds =
        productFilter.isNotEmpty ? productFilter : inventoryMap.keys.toSet();

    final statsMap = <String, ProductStats>{
      for (final id in filteredIds)
        id: ProductStats(
          productId: id,
          name: inventoryMap[id]?.product.name ?? id,
        ),
    };

    void ensureStatsFor(String productId) {
      statsMap.putIfAbsent(
        productId,
        () => ProductStats(
          productId: productId,
          name: inventoryMap[productId]?.product.name ?? productId,
        ),
      );
    }

    final restockBuckets = <String, Map<DateTime, double>>{};
    final usageBuckets = <String, Map<DateTime, double>>{};

    for (final entry in state.history) {
      if (entry.timestamp.isBefore(start) ||
          entry.timestamp.isAfter(end)) {
        continue;
      }
      final productId = entry.meta?['productId'] as String?;
      if (productId == null || !filteredIds.contains(productId)) continue;
      ensureStatsFor(productId);
      final stats = statsMap[productId]!;
      final double? quantity =
          _toDouble(entry.meta?['quantity']);
      switch (entry.kind) {
        case HistoryKind.order:
          if (quantity != null && quantity > 0) {
            stats.ordered += quantity;
          }
          break;
        case HistoryKind.warehouse:
          if (quantity != null && quantity > 0) {
            stats.delivered += quantity;
          }
          break;
        case HistoryKind.restock:
          final restocked = _toDouble(entry.meta?['restocked']);
          if (restocked != null && restocked > 0) {
            stats.restocked += restocked;
            _bucketValue(
              restockBuckets,
              productId,
              entry.timestamp,
              restocked,
            );
          }
          break;
        case HistoryKind.bar:
          final delta = _toDouble(entry.meta?['delta']);
          if (delta != null && delta < 0) {
            final used = delta.abs();
            stats.used += used;
            _bucketValue(
              usageBuckets,
              productId,
              entry.timestamp,
              used,
            );
          }
          break;
        default:
          break;
      }
    }

    // populate current stock figures
    for (final id in filteredIds) {
      final item = inventoryMap[id];
      if (item == null) continue;
      final stats = statsMap[id] ??
          ProductStats(productId: id, name: item.product.name);
      stats.currentBar = item.approxQty;
      stats.currentWarehouse = item.warehouseQty.toDouble();
      statsMap[id] = stats;
    }

    final restockSeries = restockBuckets.entries
        .map(
          (entry) => LineSeries(
            productId: entry.key,
            label: statsMap[entry.key]?.name ?? entry.key,
            points: _mapBucketToSeries(entry.value),
          ),
        )
        .toList();
    final usageSeries = usageBuckets.entries
        .map(
          (entry) => LineSeries(
            productId: entry.key,
            label: statsMap[entry.key]?.name ?? entry.key,
            points: _mapBucketToSeries(entry.value),
          ),
        )
        .toList();

    return StatisticsResult(
      productStats: statsMap.values.toList(),
      restockSeries: restockSeries,
      usageSeries: usageSeries,
    );
  }

  static List<TimeSeriesPoint> _mapBucketToSeries(
      Map<DateTime, double> bucket) {
    final dates = bucket.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    return [
      for (final date in dates) TimeSeriesPoint(date, bucket[date] ?? 0),
    ];
  }

  static void _bucketValue(
    Map<String, Map<DateTime, double>> buckets,
    String productId,
    DateTime timestamp,
    double value,
  ) {
    final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final productBucket =
        buckets.putIfAbsent(productId, () => <DateTime, double>{});
    productBucket.update(day, (existing) => existing + value,
        ifAbsent: () => value);
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
