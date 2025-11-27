import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/statistics_service.dart';
import '../../../core/app_notifier.dart';
import '../../../core/app_state.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/print_service.dart';
import '../../widgets/print_preview_dialog.dart';

enum StatsRangePreset {
  day,
  week,
  month,
  threeMonths,
  sixMonths,
  year,
  custom,
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  AppNotifier? _notifier;
  StatsRangePreset _preset = StatsRangePreset.month;
  DateTimeRange _range = _initialRange(StatsRangePreset.month);
  DateTimeRange? _customRange;
  final Set<String> _selectedProductIds = {};
  final Set<String> _selectedGroupNames = {};
  StatisticsResult? _result;
  StatisticsResult? _comparisonResult;
  bool _comparePrevious = false;
  TextEditingController? _productSearchController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calculate();
    });
  }

  static DateTimeRange _initialRange(StatsRangePreset preset) {
    final now = DateTime.now();
    DateTime start;
    switch (preset) {
      case StatsRangePreset.day:
        start = now.subtract(const Duration(days: 1));
        break;
      case StatsRangePreset.week:
        start = now.subtract(const Duration(days: 7));
        break;
      case StatsRangePreset.month:
        start = now.subtract(const Duration(days: 30));
        break;
      case StatsRangePreset.threeMonths:
        start = now.subtract(const Duration(days: 90));
        break;
      case StatsRangePreset.sixMonths:
        start = now.subtract(const Duration(days: 180));
        break;
      case StatsRangePreset.year:
        start = now.subtract(const Duration(days: 365));
        break;
      case StatsRangePreset.custom:
        start = now.subtract(const Duration(days: 30));
        break;
    }
    return DateTimeRange(start: start, end: now);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = Provider.of<AppNotifier>(context, listen: false);
    if (!identical(_notifier, notifier)) {
      _notifier?.removeListener(_handleNotifierChanged);
      _notifier = notifier;
      _notifier?.addListener(_handleNotifierChanged);
    }
  }

  @override
  void dispose() {
    _notifier?.removeListener(_handleNotifierChanged);
    super.dispose();
  }

  void _handleNotifierChanged() {
    if (!mounted) return;
    _calculate();
  }

  void _calculate() {
    final state = _notifier?.state;
    if (state == null) return;
    final filteredProducts = _effectiveProductFilter(state);
    final result = StatisticsService.calculate(
      state: state,
      start: _range.start,
      end: _range.end,
      productFilter: filteredProducts,
    );
    StatisticsResult? comparison;
    if (_comparePrevious) {
      final prevRange = _previousRange(_range);
      comparison = StatisticsService.calculate(
        state: state,
        start: prevRange.start,
        end: prevRange.end,
        productFilter: filteredProducts,
      );
    }
    setState(() {
      _result = result;
      _comparisonResult = comparison;
    });
  }

  DateTimeRange _previousRange(DateTimeRange current) {
    final durationDays = current.end
        .difference(current.start)
        .inDays
        .clamp(0, 365);
    final newEnd = current.start.subtract(const Duration(days: 1));
    final newStart =
        newEnd.subtract(Duration(days: durationDays > 0 ? durationDays : 1));
    return DateTimeRange(start: newStart, end: newEnd);
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customRange ?? _range,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _preset = StatsRangePreset.custom;
        _customRange = picked;
        _range = picked;
      });
      _calculate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: result == null ? null : () => _printStats(result),
          ),
        ],
      ),
      body: result == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildFilters(),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildSummary(result),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Export snapshot'),
                    onPressed: _notifier?.state == null
                        ? null
                        : () => PrintPreviewDialog.show(
                              context,
                              _notifier!.state,
                              PrintSection.statistics,
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildChartsSection(result),
                const SizedBox(height: 16),
                _buildProductTable(result),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    final state = _notifier?.state;
    if (state == null) {
      return const SizedBox.shrink();
    }
    final presets = StatsRangePreset.values;
    final products = state.inventory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date range',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final preset in presets)
              ChoiceChip(
                label: Text(_presetLabel(preset)),
                selected: _preset == preset,
                onSelected: (selected) {
                  if (!selected) return;
                  if (preset == StatsRangePreset.custom) {
                    _selectCustomRange();
                  } else {
                    setState(() {
                      _preset = preset;
                      _range = _initialRange(preset);
                    });
                    _calculate();
                  }
                },
              ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Selected range: ${_formatRange(_range)}',
          ),
          subtitle: _preset == StatsRangePreset.custom && _customRange == null
              ? const Text('Choose custom dates')
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectCustomRange,
          ),
        ),
        const Divider(),
        const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Autocomplete<InventoryItem>(
          displayStringForOption: (item) => item.product.name,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.toLowerCase();
            if (query.isEmpty) {
              return const Iterable<InventoryItem>.empty();
            }
            return products.where(
              (item) => item.product.name.toLowerCase().contains(query),
            );
          },
          onSelected: (item) {
            setState(() {
              _selectedProductIds.add(item.product.id);
            });
            _productSearchController?.clear();
            _calculate();
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
            _productSearchController = textEditingController;
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Search products',
                hintText: 'Type to add products',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        if (_selectedProductIds.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.inventory
                .where((item) => _selectedProductIds.contains(item.product.id))
                .map(
                  (item) => InputChip(
                    label: Text(item.product.name),
                    onDeleted: () {
                      setState(() {
                        _selectedProductIds.remove(item.product.id);
                      });
                      _calculate();
                    },
                  ),
                )
                .toList(),
          ),
        if (_selectedProductIds.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedProductIds.clear();
                });
                _calculate();
              },
              child: const Text('Clear products'),
            ),
          ),
        const Divider(),
        const Text(
          'Groups',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: state.groups
              .map(
                (group) => FilterChip(
                  label: Text(group.name),
                  selected: _selectedGroupNames.contains(group.name),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGroupNames.add(group.name);
                      } else {
                        _selectedGroupNames.remove(group.name);
                      }
                    });
                    _calculate();
                  },
                ),
              )
              .toList(),
        ),
        if (_selectedGroupNames.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedGroupNames.clear();
                });
                _calculate();
              },
              child: const Text('Clear groups'),
            ),
          ),
        const Divider(),
        SwitchListTile(
          value: _comparePrevious,
          title: const Text('Compare with previous period'),
          onChanged: (value) {
            setState(() {
              _comparePrevious = value;
            });
            _calculate();
          },
        ),
      ],
    );
  }

  Widget _buildSummary(StatisticsResult result) {
    final totalStock = result.productStats.fold<double>(
      0,
      (sum, ps) => sum + ps.currentBar + ps.currentWarehouse,
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Ordered',
                value: result.totalOrdered,
                comparison: _comparisonResult?.totalOrdered,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Delivered',
                value: result.totalDelivered,
                comparison: _comparisonResult?.totalDelivered,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Restocked',
                value: result.totalRestocked,
                comparison: _comparisonResult?.totalRestocked,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Used',
                value: result.totalUsed,
                comparison: _comparisonResult?.totalUsed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Current stock',
                value: totalStock,
                comparison: null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsSection(StatisticsResult result) {
    final totals = [
      _ChartValue('Ordered', result.totalOrdered, Colors.blue),
      _ChartValue('Delivered', result.totalDelivered, Colors.green),
      _ChartValue('Restocked', result.totalRestocked, Colors.orange),
      _ChartValue('Used', result.totalUsed, Colors.purple),
    ];
    final totalBar = result.productStats.fold<double>(
      0,
      (sum, ps) => sum + ps.currentBar,
    );
    final totalWarehouse = result.productStats.fold<double>(
      0,
      (sum, ps) => sum + ps.currentWarehouse,
    );
    final stockValues = [
      _ChartValue('Bar stock', totalBar, Colors.deepPurple),
      _ChartValue('Warehouse', totalWarehouse, Colors.teal),
    ];
    final maxValue = totals.fold<double>(
      0,
      (max, value) => value.value > max ? value.value : max,
    );
    final double interval =
        maxValue <= 0 ? 1.0 : math.max(1.0, maxValue / 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Charts',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Card(
          child: SizedBox(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BarChart(
                BarChartData(
                  maxY: (maxValue * 1.2).clamp(1.0, double.infinity),
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = totals[group.x.toInt()].label;
                        return BarTooltipItem(
                          '$label\n${rod.toY.toStringAsFixed(1)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: interval,
                        getTitlesWidget: (value, meta) =>
                            Text(value.toStringAsFixed(0)),
                      ),
                    ),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= totals.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              totals[index].label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: interval,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < totals.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: totals[i].value,
                            width: 14,
                            color: totals[i].color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SizedBox(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 50,
                        sectionsSpace: 2,
                        sections: () {
                          final sections = stockValues
                              .where((value) => value.value > 0)
                              .map(
                                (value) => PieChartSectionData(
                                  color: value.color,
                                  value: value.value,
                                  title:
                                      value.value.toStringAsFixed(1),
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                              .toList();
                          if (sections.isEmpty) {
                            sections.add(
                              PieChartSectionData(
                                color: Colors.grey.shade400,
                                value: 1,
                                title: '0',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return sections;
                        }(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: stockValues
                          .map(
                            (value) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: value.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${value.label}: ${value.value.toStringAsFixed(1)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductTable(StatisticsResult result) {
    final stats = result.productStats.toList()
      ..sort((a, b) => b.used.compareTo(a.used));
    if (stats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Product breakdown',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('No data available for the selected filters.'),
            ],
          ),
        ),
      );
    }
    final rows = stats.take(25).map((stat) {
      return DataRow(
        cells: [
          DataCell(Text(stat.name)),
          DataCell(Text(_formatValue(stat.ordered))),
          DataCell(Text(_formatValue(stat.delivered))),
          DataCell(Text(_formatValue(stat.restocked))),
          DataCell(Text(_formatValue(stat.used))),
          DataCell(Text(_formatValue(stat.currentBar))),
          DataCell(Text(_formatValue(stat.currentWarehouse))),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product breakdown (top 25 by usage)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Ordered')),
                  DataColumn(label: Text('Delivered')),
                  DataColumn(label: Text('Restocked')),
                  DataColumn(label: Text('Used')),
                  DataColumn(label: Text('Bar')),
                  DataColumn(label: Text('Warehouse')),
                ],
                rows: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _printStats(StatisticsResult result) {
    final selectedNames =
        result.productStats.map((stat) => stat.name).toList();
    final buffer = StringBuffer()
      ..writeln('STATISTICS REPORT')
      ..writeln('Range: ${_formatRange(_range)}')
      ..writeln(
        'Products: ${selectedNames.isEmpty ? 'All' : selectedNames.join(', ')}',
      )
      ..writeln()
      ..writeln('Totals:')
      ..writeln('Ordered: ${result.totalOrdered.toStringAsFixed(1)}')
      ..writeln('Delivered: ${result.totalDelivered.toStringAsFixed(1)}')
      ..writeln('Restocked: ${result.totalRestocked.toStringAsFixed(1)}')
      ..writeln('Used: ${result.totalUsed.toStringAsFixed(1)}')
      ..writeln()
      ..writeln('Per product:');
    for (final stat in result.productStats) {
      buffer.writeln(
          '- ${stat.name}: ordered ${stat.ordered.toStringAsFixed(1)}, delivered ${stat.delivered.toStringAsFixed(1)}, restocked ${stat.restocked.toStringAsFixed(1)}, used ${stat.used.toStringAsFixed(1)}, stock ${(stat.currentBar + stat.currentWarehouse).toStringAsFixed(1)}');
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Print preview'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(buffer.toString()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _presetLabel(StatsRangePreset preset) {
    switch (preset) {
      case StatsRangePreset.day:
        return 'Day';
      case StatsRangePreset.week:
        return 'Week';
      case StatsRangePreset.month:
        return 'Month';
      case StatsRangePreset.threeMonths:
        return '3 mo';
      case StatsRangePreset.sixMonths:
        return '6 mo';
      case StatsRangePreset.year:
        return 'Year';
      case StatsRangePreset.custom:
        return 'Custom';
    }
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _formatRange(DateTimeRange range) {
    final start = '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
    final end = '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  Set<String> _effectiveProductFilter(AppState state) {
    final ids = <String>{..._selectedProductIds};
    if (_selectedGroupNames.isEmpty) return ids;
    final inventory = state.inventory;
    for (final groupName in _selectedGroupNames) {
      ids.addAll(
        inventory
            .where((item) => item.groupName == groupName)
            .map((item) => item.product.id),
      );
    }
    return ids;
  }

}

class _ChartValue {
  final String label;
  final double value;
  final Color color;

  _ChartValue(this.label, this.value, this.color);
}

class _StatCard extends StatelessWidget {
  final String title;
  final double value;
  final double? comparison;

  const _StatCard({
    required this.title,
    required this.value,
    this.comparison,
  });

  @override
  Widget build(BuildContext context) {
    double? diff;
    if (comparison != null) {
      diff = value - comparison!;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (diff != null)
              Text(
                '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} vs prev',
                style: TextStyle(
                  color: diff >= 0 ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
