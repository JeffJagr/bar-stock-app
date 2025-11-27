import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_logic.dart';
import '../../../core/app_notifier.dart';
import '../../../core/app_state.dart';
import '../../../core/history_formatter.dart';
import '../../../core/models/history_entry.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/models/order_item.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final String _itemsQuery = '';
  final String _historyQuery = '';
  final TextEditingController _itemSearchController = TextEditingController();
  final TextEditingController _historySearchController =
      TextEditingController();
  final bool _onlyBarLow = false;
  final bool _onlyWarehouseLow = false;

  @override
  void dispose() {
    _itemSearchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Search'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.search), text: 'Items'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ItemsTab(),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _ItemsTab extends StatefulWidget {
  const _ItemsTab();

  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  String _query = '';
  bool _onlyBarLow = false;
  bool _onlyWarehouseLow = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppNotifier>();
    final state = notifier.state;
    final items = state.inventory.toList()
      ..sort((a, b) => a.product.name.compareTo(b.product.name));
    final query = _query.toLowerCase();
    final filtered = items.where((item) {
      if (query.isNotEmpty &&
          !item.product.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_onlyBarLow && !AppLogic.isBarLow(item)) return false;
      if (_onlyWarehouseLow && !AppLogic.isLowStock(item)) return false;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search products',
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
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Bar low only'),
                    selected: _onlyBarLow,
                    onSelected: (value) {
                      setState(() {
                        _onlyBarLow = value;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Warehouse low only'),
                    selected: _onlyWarehouseLow,
                    onSelected: (value) {
                      setState(() {
                        _onlyWarehouseLow = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No items found'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _ItemCard(
                      item: item,
                      state: state,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  final InventoryItem item;
  final AppState state;

  const _ItemCard({
    required this.item,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final restock = state.restock
        .where((r) => r.product.id == item.product.id)
        .toList();
    final orders = state.orders
        .where((o) => o.product.id == item.product.id)
        .toList();

    final max = item.maxQty;
    final approx = item.approxQty;
    final percent =
        (max > 0) ? ((approx / max) * 100).clamp(0, 100) : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _levelColor(item.level),
                  child: Icon(
                    item.product.isAlcohol
                        ? Icons.local_bar
                        : Icons.local_drink,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  item.groupName,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: max > 0 ? approx / max : 0,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              color: _levelColor(item.level),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bar: ~ ${approx.toStringAsFixed(1)} / $max '
                    '(${percent.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppLogic.isBarLow(item)
                          ? Colors.orange.shade700
                          : null,
                    ),
                  ),
                ),
                Text(
                  'Warehouse: ${item.warehouseQty}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppLogic.isLowStock(item)
                        ? Colors.red.shade600
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (AppLogic.isBarLow(item))
                  Chip(
                    label: const Text('Bar low'),
                    backgroundColor: Colors.orange.shade50,
                    labelStyle: TextStyle(color: Colors.orange.shade700),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                  ),
                if (AppLogic.isLowStock(item))
                  Chip(
                    label: const Text('Warehouse low'),
                    backgroundColor: Colors.red.shade50,
                    labelStyle: TextStyle(color: Colors.red.shade700),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                  ),
                if (restock.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.playlist_add_check, size: 16),
                    label: Text(
                      'Restock: ${restock.first.approxNeed.toStringAsFixed(1)}',
                    ),
                  ),
                if (orders.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.shopping_cart, size: 16),
                    label: Text('Orders: ${_ordersSummary(orders)}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ordersSummary(List<OrderItem> orders) {
    return orders
        .map((o) => '${o.quantity} (${_statusName(o.status)})')
        .join(', ');
  }

  String _statusName(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.delivered:
        return 'delivered';
    }
  }

  Color _levelColor(Level level) {
    switch (level) {
      case Level.green:
        return Colors.green;
      case Level.yellow:
        return Colors.amber;
      case Level.red:
        return Colors.red;
    }
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppNotifier>().state.history.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final filtered = history.where((entry) {
      if (_query.isEmpty) return true;
      return entry.action
          .toLowerCase()
          .contains(_query.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
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
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No history entries'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final message = HistoryFormatter.describe(entry);
                    return Card(
                      color: _historyColor(entry.kind),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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
                              '${entry.actorName} - '
                              '${entry.actionType.name.toUpperCase()} - '
                              '${_formatTimestamp(entry.timestamp)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
      default:
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
      default:
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
      default:
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
}
