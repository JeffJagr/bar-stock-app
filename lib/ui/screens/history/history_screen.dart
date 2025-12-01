import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_notifier.dart';
import '../../../core/history_formatter.dart';
import '../../../core/models/history_entry.dart';
import '../../../core/print_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/print_preview_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();
  String _query = '';
  String _productFilter = '';
  String _groupFilter = '';
  final Set<HistoryKind> _selectedKinds = {};
  final Set<HistoryActionType> _selectedActions = {};
  DateTimeRange? _range;
  String _activePreset = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    _productController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final state = notifier.state;
    final entries = state.history;
    final sorted = entries.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final filtered = sorted.where((entry) {
      final matchesQuery = _query.isEmpty ||
          entry.action.toLowerCase().contains(_query.toLowerCase()) ||
          entry.actorName.toLowerCase().contains(_query.toLowerCase());
      final matchesProduct = _productFilter.isEmpty ||
          (entry.meta?['productName'] as String? ?? '')
              .toLowerCase()
              .contains(_productFilter.toLowerCase());
      final matchesGroup = _groupFilter.isEmpty ||
          (entry.meta?['groupName'] as String? ?? '')
              .toLowerCase()
              .contains(_groupFilter.toLowerCase());
      final matchesKind =
          _selectedKinds.isEmpty || _selectedKinds.contains(entry.kind);
      final matchesAction = _selectedActions.isEmpty ||
          _selectedActions.contains(entry.actionType);
      final matchesRange = _range == null ||
          (!entry.timestamp.isBefore(_range!.start) &&
              !entry.timestamp.isAfter(_range!.end));
      return matchesQuery &&
          matchesProduct &&
          matchesGroup &&
          matchesKind &&
          matchesAction &&
          matchesRange;
    }).toList();
    final hasFilters = _query.isNotEmpty ||
        _selectedKinds.isNotEmpty ||
        _selectedActions.isNotEmpty ||
        _range != null ||
        _activePreset != 'ALL';

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search history',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                              });
                            },
                          ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Export / Print'),
                    onPressed: () => PrintPreviewDialog.show(
                      context,
                      state,
                      PrintSection.history,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _productController,
                  decoration: InputDecoration(
                    labelText: 'Filter by product',
                    prefixIcon: const Icon(Icons.local_bar),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _productFilter.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _productController.clear();
                              setState(() {
                                _productFilter = '';
                              });
                            },
                          ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _productFilter = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _groupController,
                  decoration: InputDecoration(
                    labelText: 'Filter by group',
                    prefixIcon: const Icon(Icons.category),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _groupFilter.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _groupController.clear();
                              setState(() {
                                _groupFilter = '';
                              });
                            },
                          ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _groupFilter = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Filter by area',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: HistoryKind.values
                      .map(
                        (kind) => FilterChip(
                          label: Text(kind.name.toUpperCase()),
                          selected: _selectedKinds.contains(kind),
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedKinds.add(kind);
                              } else {
                                _selectedKinds.remove(kind);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Filter by action type',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: HistoryActionType.values
                      .map(
                        (type) => FilterChip(
                          label: Text(type.name.toUpperCase()),
                          selected: _selectedActions.contains(type),
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedActions.add(type);
                              } else {
                                _selectedActions.remove(type);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _RangeChip(
                      label: 'All',
                      selected: _activePreset == 'ALL',
                      onSelected: () => _setRangePreset('ALL', null),
                    ),
                    const SizedBox(width: 8),
                    _RangeChip(
                      label: '7d',
                      selected: _activePreset == '7D',
                      onSelected: () =>
                          _setRangePreset('7D', const Duration(days: 7)),
                    ),
                    const SizedBox(width: 8),
                    _RangeChip(
                      label: '30d',
                      selected: _activePreset == '30D',
                      onSelected: () =>
                          _setRangePreset('30D', const Duration(days: 30)),
                    ),
                    const SizedBox(width: 8),
                    _RangeChip(
                      label: '90d',
                      selected: _activePreset == '90D',
                      onSelected: () =>
                          _setRangePreset('90D', const Duration(days: 90)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: const Text('Custom'),
                      onPressed: _pickCustomRange,
                    ),
                  ],
                ),
                if (_range != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Range: ${_formatRange(_range!)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _setRangePreset('ALL', null),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.history,
                    title: hasFilters
                        ? 'No history matches your filters'
                        : 'No history yet',
                    message: hasFilters
                        ? 'Try clearing the filters or adjust your search.'
                        : 'Completed actions and changes will appear here.',
                    buttonLabel: hasFilters ? 'Reset filters' : null,
                    onButtonPressed: hasFilters ? _resetFilters : null,
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final message = HistoryFormatter.describe(entry);
                      final canUndo =
                          notifier.canUndoEntry(entry);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        color: _historyColor(entry.kind),
                        child: ListTile(
                          leading: Icon(
                            _historyIcon(entry.kind),
                            color: _historyIconColor(entry.kind),
                          ),
                          title: Text(message.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.detail != null)
                                Text(
                                  message.detail!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              Text(
                                '${entry.actorName} - ${entry.actionType.name.toUpperCase()} - ${_formatTimestamp(entry.timestamp)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (entry.meta != null &&
                                  entry.meta!['productName'] != null &&
                                  entry.meta!['oldPercent'] != null &&
                                  entry.meta!['newPercent'] != null)
                                Text(
                                  '${entry.meta!['productName']}: '
                                  '${(entry.meta!['oldPercent'] as num).toStringAsFixed(1)}% → '
                                  '${(entry.meta!['newPercent'] as num).toStringAsFixed(1)}%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: canUndo
                              ? TextButton(
                                  onPressed: () => _onUndoEntry(
                                    context,
                                    notifier,
                                    entry,
                                  ),
                                  child: const Text('Undo'),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _historyColor(HistoryKind kind) {
    switch (kind) {
      case HistoryKind.order:
        return Colors.blue.shade50;
      case HistoryKind.warehouse:
        return Colors.green.shade50;
      case HistoryKind.restock:
        return Colors.orange.shade50;
      case HistoryKind.bar:
        return Colors.purple.shade50;
      case HistoryKind.auth:
        return Colors.teal.shade50;
      case HistoryKind.general:
        return Colors.grey.shade100;
    }
  }

  Color _historyIconColor(HistoryKind kind) {
    switch (kind) {
      case HistoryKind.order:
        return Colors.blue;
      case HistoryKind.warehouse:
        return Colors.green;
      case HistoryKind.restock:
        return Colors.orange;
      case HistoryKind.bar:
        return Colors.purple;
      case HistoryKind.auth:
        return Colors.teal;
      case HistoryKind.general:
        return Colors.grey;
    }
  }

  IconData _historyIcon(HistoryKind kind) {
    switch (kind) {
      case HistoryKind.order:
        return Icons.shopping_cart;
      case HistoryKind.warehouse:
        return Icons.warehouse;
      case HistoryKind.restock:
        return Icons.refresh;
      case HistoryKind.bar:
        return Icons.local_bar;
      case HistoryKind.auth:
        return Icons.lock;
      case HistoryKind.general:
        return Icons.info_outline;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  void _setRangePreset(String preset, Duration? duration) {
    setState(() {
      _activePreset = preset;
      if (duration == null) {
        _range = null;
      } else {
        final now = DateTime.now();
        final start = now.subtract(duration);
        _range = DateTimeRange(start: start, end: now);
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
      initialDateRange: _range ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() {
        _activePreset = 'CUSTOM';
        _range = DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _selectedKinds.clear();
      _selectedActions.clear();
      _range = null;
      _activePreset = 'ALL';
    });
  }

  String _formatRange(DateTimeRange range) {
    return '${_formatDate(range.start)} - ${_formatDate(range.end)}';
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _onUndoEntry(
    BuildContext context,
    AppNotifier notifier,
    HistoryEntry entry,
  ) {
    final success = notifier.undoEntry(entry);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Action undone' : 'Cannot undo this entry',
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
