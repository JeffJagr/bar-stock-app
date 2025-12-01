import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_notifier.dart';
import '../../../core/models/order_item.dart';
import '../../widgets/empty_state.dart';

enum _DatePreset { all, today, week, custom }

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final companyId = notifier.state.activeCompanyId;
    if (companyId == null) {
      return const Scaffold(
        body: Center(child: Text('Select a company to view order history')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order history'),
      ),
      body: _OrderHistoryBody(companyId: companyId),
    );
  }

}

class _OrderHistoryBody extends StatefulWidget {
  const _OrderHistoryBody({required this.companyId});

  final String companyId;

  @override
  State<_OrderHistoryBody> createState() => _OrderHistoryBodyState();
}

class _OrderHistoryBodyState extends State<_OrderHistoryBody> {
  final TextEditingController _searchController = TextEditingController();
  _DatePreset _preset = _DatePreset.all;
  DateTimeRange? _customRange;
  final Set<OrderStatus> _statuses = {};
  String? _staffFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    return Column(
      children: [
        _buildFilters(context, notifier),
        Expanded(
          child: StreamBuilder<List<OrderItem>>(
            stream: notifier.orderHistoryStream(widget.companyId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data ?? [];
              final filtered = _applyFilters(orders);
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.history,
                  title: 'No matching orders',
                  message: 'Adjust search or filters to see results.',
                );
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final order = filtered[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: _statusIcon(order.status),
                      title: Text(order.product.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Qty: ${order.quantity} • ${order.status.name.toUpperCase()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _formatTimestamp(order.createdAt),
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (order.performerName != null)
                            Text(
                              'By ${order.performerName}',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(BuildContext context, AppNotifier notifier) {
    final staffNames = notifier.state.history
        .map((h) => h.actorName)
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search orders',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _exportCurrent(context, notifier),
                icon: const Icon(Icons.download),
                label: const Text('Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip('All dates', _preset == _DatePreset.all, () {
                setState(() {
                  _preset = _DatePreset.all;
                  _customRange = null;
                });
              }),
              _chip('Today', _preset == _DatePreset.today, () {
                setState(() {
                  _preset = _DatePreset.today;
                  _customRange = null;
                });
              }),
              _chip('This week', _preset == _DatePreset.week, () {
                setState(() {
                  _preset = _DatePreset.week;
                  _customRange = null;
                });
              }),
              _chip(
                _customRangeLabel(),
                _preset == _DatePreset.custom,
                () async {
                  final now = DateTime.now();
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 1),
                    initialDateRange: _customRange ??
                        DateTimeRange(
                          start: now.subtract(const Duration(days: 7)),
                          end: now,
                        ),
                  );
                  if (range != null) {
                    setState(() {
                      _preset = _DatePreset.custom;
                      _customRange = range;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: OrderStatus.values.map((status) {
              final selected = _statuses.contains(status);
              return FilterChip(
                label: Text(status.name),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _statuses.add(status);
                    } else {
                      _statuses.remove(status);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Staff',
              border: OutlineInputBorder(),
            ),
            value: _staffFilter ?? '',
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Any'),
              ),
              ...staffNames.map(
                (name) => DropdownMenuItem(
                  value: name,
                  child: Text(name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _staffFilter = value ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  List<OrderItem> _applyFilters(List<OrderItem> orders) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    DateTimeRange? range;
    switch (_preset) {
      case _DatePreset.today:
        final start = DateTime(now.year, now.month, now.day);
        range = DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
        break;
      case _DatePreset.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        range = DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
        break;
      case _DatePreset.custom:
        range = _customRange;
        break;
      case _DatePreset.all:
        range = null;
        break;
    }

    return orders.where((order) {
      if (query.isNotEmpty) {
        final haystack = '${order.product.name} ${order.performerName ?? ''} ${order.product.id}'
            .toLowerCase();
        if (!haystack.contains(query)) {
          return false;
        }
      }
      if (_statuses.isNotEmpty && !_statuses.contains(order.status)) {
        return false;
      }
      if (_staffFilter != null && _staffFilter!.isNotEmpty) {
        if ((order.performerName ?? '').toLowerCase() != _staffFilter!.toLowerCase()) {
          return false;
        }
      }
      if (range != null) {
        final ts = order.createdAt;
        if (ts.isBefore(range.start) || ts.isAfter(range.end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _exportCurrent(
    BuildContext context,
    AppNotifier notifier,
  ) async {
    final orders = _applyFilters(
      notifier.state.orders,
    );
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to export for current filters')),
      );
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('date,orderId,staff,status,quantity,product,total');
    for (final order in orders) {
      final date = _formatTimestamp(order.createdAt);
      final staff = order.performerName ?? '';
      final id = order.product.id;
      final status = order.status.name;
      final qty = order.quantity;
      final product = order.product.name.replaceAll(',', ' ');
      final total = order.total?.toStringAsFixed(2) ?? '';
      buffer.writeln(
        '$date,$id,$staff,$status,$qty,$product,$total',
      );
    }
    final content = buffer.toString();
    try {
      await Share.share(
        content,
        subject: 'Order history export',
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share export on this platform')),
      );
    }
  }

  Widget _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange);
      case OrderStatus.confirmed:
        return const Icon(Icons.check_circle, color: Colors.blue);
      case OrderStatus.delivered:
        return const Icon(Icons.local_shipping, color: Colors.green);
    }
  }

  String _formatTimestamp(DateTime ts) {
    final date =
        '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _customRangeLabel() {
    if (_customRange == null) return 'Custom range';
    return '${_customRange!.start.month}/${_customRange!.start.day} - ${_customRange!.end.month}/${_customRange!.end.day}';
  }
}
