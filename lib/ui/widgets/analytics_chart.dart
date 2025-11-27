import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/analytics/statistics_service.dart';

enum ChartType { line, bar, pie }

enum StatsMetric { restocked, used, delivered, ordered }

class AnalyticsChart extends StatelessWidget {
  final ChartType chartType;
  final StatsMetric metric;
  final DateTimeRange range;
  final StatisticsResult result;
  final StatisticsResult? comparisonResult;

  const AnalyticsChart({
    super.key,
    required this.chartType,
    required this.metric,
    required this.range,
    required this.result,
    this.comparisonResult,
  });

  @override
  Widget build(BuildContext context) {
    switch (chartType) {
      case ChartType.line:
        return _buildLineChart();
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.pie:
        return _buildPieChart();
    }
  }

  Widget _buildLineChart() {
    final series = _seriesForMetric(result);
    final comparison = comparisonResult == null
        ? const []
        : _seriesForMetric(comparisonResult!, suffix: ' (prev)');
    final merged = [...series, ...comparison]
        .where((s) => s.points.isNotEmpty)
        .toList();
    if (merged.isEmpty) {
      return const _ChartPlaceholder(message: 'Not enough data for line chart');
    }
    final colors = Colors.primaries;
    final spotsData = merged.map((series) {
      final spots = <FlSpot>[];
      final baseDate = DateTime(range.start.year, range.start.month,
          range.start.day);
      for (final point in series.points) {
        final diff = point.date.difference(baseDate).inDays.toDouble();
        spots.add(FlSpot(diff, point.value));
      }
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 3,
        color: colors[merged.indexOf(series) % colors.length],
        dotData: const FlDotData(show: false),
      );
    }).toList();
    final maxY = merged
        .expand((series) => series.points)
        .fold<double>(0, (prev, p) => prev > p.value ? prev : p.value);
    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: range.end.difference(range.start).inDays
              .clamp(1, 365)
              .toDouble(),
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.2,
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (range.end
                            .difference(range.start)
                            .inDays
                            .clamp(1, 31) /
                        4)
                    .toDouble(),
                getTitlesWidget: (value, meta) {
                  final date = range.start.add(Duration(days: value.toInt()));
                  return Text('${date.month}/${date.day}',
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
          lineBarsData: spotsData,
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final totals = _totalsForMetric(result);
    if (totals.isEmpty) {
      return const _ChartPlaceholder(message: 'Not enough data for bar chart');
    }
    final colors = Colors.primaries;
    final groups = totals.entries.map((entry) {
      final index = totals.keys.toList().indexOf(entry.key).toDouble();
      return BarChartGroupData(
        x: index.toInt(),
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: colors[index.toInt() % colors.length],
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final labels = totals.keys.toList();
                  if (value.toInt() < 0 ||
                      value.toInt() >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final totals = _totalsForMetric(result);
    if (totals.isEmpty) {
      return const _ChartPlaceholder(message: 'Not enough data for pie chart');
    }
    final colors = Colors.accents;
    final sections = totals.entries.map((entry) {
      final idx = totals.keys.toList().indexOf(entry.key);
      return PieChartSectionData(
        color: colors[idx % colors.length],
        value: entry.value,
        title:
            '${entry.key}\n${entry.value.toStringAsFixed(1)}',
        radius: 80,
        titleStyle: const TextStyle(fontSize: 12),
      );
    }).toList();
    return SizedBox(
      height: 260,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 0,
          sections: sections,
        ),
      ),
    );
  }

  List<LineSeries> _seriesForMetric(
    StatisticsResult result, {
    String suffix = '',
  }) {
    switch (metric) {
      case StatsMetric.restocked:
        return result.restockSeries
            .map(
              (series) => LineSeries(
                productId: series.productId,
                label: '${series.label}$suffix',
                points: series.points,
              ),
            )
            .toList();
      case StatsMetric.used:
        return result.usageSeries
            .map(
              (series) => LineSeries(
                productId: series.productId,
                label: '${series.label}$suffix',
                points: series.points,
              ),
            )
            .toList();
      case StatsMetric.delivered:
      case StatsMetric.ordered:
        final totals = _totalsForMetric(result);
        return totals.entries
            .map(
              (entry) => LineSeries(
                productId: entry.key,
                label: '${entry.key}$suffix',
                points: [
                  TimeSeriesPoint(range.start, entry.value),
                  TimeSeriesPoint(range.end, entry.value),
                ],
              ),
            )
            .toList();
    }
  }

  Map<String, double> _totalsForMetric(StatisticsResult result) {
    switch (metric) {
      case StatsMetric.restocked:
        return {
          for (final stat in result.productStats)
            stat.name: stat.restocked,
        };
      case StatsMetric.used:
        return {
          for (final stat in result.productStats) stat.name: stat.used,
        };
      case StatsMetric.delivered:
        return {
          for (final stat in result.productStats)
            stat.name: stat.delivered,
        };
      case StatsMetric.ordered:
        return {
          for (final stat in result.productStats)
            stat.name: stat.ordered,
        };
    }
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String message;
  const _ChartPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}
