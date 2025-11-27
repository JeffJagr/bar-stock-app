import 'app_logic.dart';
import 'app_state.dart';
import 'analytics/statistics_service.dart';
import 'history_formatter.dart';
import 'models/inventory_item.dart';

enum PrintSection {
  bar,
  warehouse,
  restock,
  orders,
  history,
  statistics,
}

/// Builds printable text snippets for specific sections of the application.
class PrintService {
  const PrintService();

  static String sectionLabel(PrintSection section) {
    switch (section) {
      case PrintSection.bar:
        return 'Bar';
      case PrintSection.warehouse:
        return 'Warehouse';
      case PrintSection.restock:
        return 'Restock';
      case PrintSection.orders:
        return 'Orders';
      case PrintSection.history:
        return 'History';
      case PrintSection.statistics:
        return 'Statistics';
    }
  }

  /// Provides backwards compatibility with existing navigation tabs.
  PrintSection? sectionForTab(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
      case 1:
        return PrintSection.bar;
      case 2:
        return PrintSection.restock;
      case 3:
        return PrintSection.warehouse;
      case 4:
        return PrintSection.orders;
      default:
        return null;
    }
  }

  String? buildSection(AppState state, PrintSection section) {
    switch (section) {
      case PrintSection.bar:
        return _buildBarPreview(state);
      case PrintSection.warehouse:
        return _buildWarehousePreview(state);
      case PrintSection.restock:
        return _buildRestockPreview(state);
      case PrintSection.orders:
        return _buildOrdersPreview(state);
      case PrintSection.history:
        return _buildHistoryPreview(state);
      case PrintSection.statistics:
        return _buildStatisticsPreview(state);
    }
  }

  String? buildPrintText(AppState state, int selectedIndex) {
    final section = sectionForTab(selectedIndex);
    if (section == null) return null;
    return buildSection(state, section);
  }

  String? _buildBarPreview(AppState state) {
    final groups = AppLogic.groupNames(state)..sort();
    if (groups.isEmpty) return null;

    final buffer = StringBuffer()
      ..writeln('SMART BAR STOCK :: BAR')
      ..writeln('======================')
      ..writeln('Generated at: ${DateTime.now()}')
      ..writeln();

    for (final group in groups) {
      final items = AppLogic.itemsForGroup(state, group)
          .where((i) => i.maxQty > 0)
          .toList();
      if (items.isEmpty) continue;

      _sortItems(items);
      buffer
        ..writeln('[$group]')
        ..writeln(_barLines(items));
    }
    return buffer.toString();
  }

  String _barLines(List<InventoryItem> items) {
    final buffer = StringBuffer();
    for (final item in items) {
      buffer
        ..writeln('- ${item.product.name}')
        ..writeln('    Bar: ${item.approxQty.toStringAsFixed(1)} / '
            '${item.maxQty} (${_percent(item.approxQty, item.maxQty)})')
        ..writeln('    Status: ${_barStatus(item)}')
        ..writeln('    Warehouse: ${item.warehouseQty}');
    }
    buffer.writeln();
    return buffer.toString();
  }

  String? _buildWarehousePreview(AppState state) {
    final groups = AppLogic.groupNames(state)..sort();
    if (groups.isEmpty) return null;

    final buffer = StringBuffer()
      ..writeln('SMART BAR STOCK :: WAREHOUSE')
      ..writeln('===========================')
      ..writeln('Generated at: ${DateTime.now()}')
      ..writeln();
    for (final group in groups) {
      final items = AppLogic.itemsForGroup(state, group).toList();
      if (items.isEmpty) continue;
      _sortItems(items);
      buffer
        ..writeln('[$group]')
        ..writeln(_warehouseLines(items));
    }
    return buffer.toString();
  }

  String _warehouseLines(List<InventoryItem> items) {
    final buffer = StringBuffer();
    for (final item in items) {
      buffer
        ..writeln('- ${item.product.name}')
        ..writeln('    Warehouse: ${item.warehouseQty} '
            '(${_warehouseStatus(item)})')
        ..writeln('    Bar: ${item.approxQty.toStringAsFixed(1)} / '
            '${item.maxQty}');
    }
    buffer.writeln();
    return buffer.toString();
  }

  String _buildRestockPreview(AppState state) {
    final items = state.restock.toList();
    final buffer = StringBuffer()
      ..writeln('SMART BAR STOCK :: RESTOCK')
      ..writeln('=========================')
      ..writeln('Generated at: ${DateTime.now()}')
      ..writeln();
    if (items.isEmpty) {
      buffer.writeln('No pending restock items.');
      return buffer.toString();
    }
    items.sort((a, b) => a.product.name.compareTo(b.product.name));
    for (final item in items) {
      buffer
        ..writeln('- ${item.product.name}')
        ..writeln('    Bar current: ${item.approxCurrent.toStringAsFixed(1)}')
        ..writeln('    Needed: ${item.approxNeed.toStringAsFixed(1)}');
    }
    return buffer.toString();
  }

  String _buildOrdersPreview(AppState state) {
    final orders = state.orders.toList();
    final buffer = StringBuffer()
      ..writeln('SMART BAR STOCK :: ORDERS')
      ..writeln('========================')
      ..writeln('Generated at: ${DateTime.now()}')
      ..writeln();
    if (orders.isEmpty) {
      buffer.writeln('No active supplier orders.');
      return buffer.toString();
    }
    orders.sort((a, b) => a.product.name.compareTo(b.product.name));
    for (final order in orders) {
      buffer
        ..writeln('- ${order.product.name}')
        ..writeln('    Status: ${order.status.name.toUpperCase()}')
        ..writeln('    Quantity: ${order.quantity}');
    }
    return buffer.toString();
  }

  String _buildHistoryPreview(AppState state) {
    final entries = state.history.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final buffer = StringBuffer()
      ..writeln('SMART BAR STOCK :: HISTORY SNAPSHOT')
      ..writeln('===================================')
      ..writeln('Generated at: ${DateTime.now()}')
      ..writeln();
    if (entries.isEmpty) {
      buffer.writeln('History log is empty.');
      return buffer.toString();
    }
    for (final entry in entries.take(25)) {
      final message = HistoryFormatter.describe(entry);
      buffer
        ..writeln('- ${entry.timestamp.toIso8601String()}')
        ..writeln('    ${message.title}')
        ..writeln('    ${message.detail ?? entry.action}')
        ..writeln('    Actor: ${entry.actorName} '
            '(${entry.actionType.name.toUpperCase()})');
    }
    return buffer.toString();
  }

  String _buildStatisticsPreview(AppState state) {
    final inventory = state.inventory.toList()
      ..sort((a, b) => a.product.name.compareTo(b.product.name));
    final buffer = StringBuffer()
      ..writeln('SMART BAR STOCK :: INVENTORY SUMMARY')
      ..writeln('====================================')
      ..writeln('Generated at: ${DateTime.now()}')
      ..writeln()
      ..writeln('Total products: ${inventory.length}')
      ..writeln('Bar low items: ${inventory.where(AppLogic.isBarLow).length}')
      ..writeln('Warehouse low items: '
          '${inventory.where(AppLogic.isLowStock).length}')
      ..writeln();
    for (final item in inventory.take(100)) {
      buffer
        ..writeln('- ${item.product.name} (${item.groupName})')
        ..writeln('    Bar: ${item.approxQty.toStringAsFixed(1)} / '
            '${item.maxQty} (${_percent(item.approxQty, item.maxQty)})')
        ..writeln('    Warehouse: ${item.warehouseQty}');
    }
    if (inventory.length > 100) {
      buffer.writeln('...and ${inventory.length - 100} more items.');
    }
    return buffer.toString();
  }

  String buildStatisticsReport({
    required StatisticsResult result,
    required String rangeLabel,
    String productFocus = 'All',
    String groupFocus = 'All',
  }) {
    final buffer = StringBuffer()
      ..writeln('STATISTICS REPORT')
      ..writeln('================')
      ..writeln('Range: $rangeLabel')
      ..writeln('Product focus: $productFocus')
      ..writeln('Group focus: $groupFocus')
      ..writeln()
      ..writeln('Totals:')
      ..writeln('  Ordered: ${_formatValue(result.totalOrdered)}')
      ..writeln('  Delivered: ${_formatValue(result.totalDelivered)}')
      ..writeln('  Restocked: ${_formatValue(result.totalRestocked)}')
      ..writeln('  Used: ${_formatValue(result.totalUsed)}')
      ..writeln();

    if (result.productStats.isEmpty) {
      buffer.writeln('No product statistics available for this range.');
      return buffer.toString();
    }

    buffer.writeln('Per product:');
    for (final stat in result.productStats) {
      buffer
        ..writeln('- ${stat.name}')
        ..writeln('    Ordered: ${_formatValue(stat.ordered)}')
        ..writeln('    Delivered: ${_formatValue(stat.delivered)}')
        ..writeln('    Restocked: ${_formatValue(stat.restocked)}')
        ..writeln('    Used: ${_formatValue(stat.used)}')
        ..writeln('    Stock: '
            '${_formatValue(stat.currentBar + stat.currentWarehouse)}');
    }
    return buffer.toString();
  }

  void _sortItems(List<InventoryItem> items) {
    items.sort((a, b) {
      final at = a.product.name.toLowerCase();
      final bt = b.product.name.toLowerCase();
      return at.compareTo(bt);
    });
  }

  String _percent(double value, int max) {
    if (max <= 0) return '0%';
    final pct = ((value / max) * 100).clamp(0, 100).toStringAsFixed(0);
    return '$pct%';
  }

  String _barStatus(InventoryItem item) {
    switch (item.level) {
      case Level.green:
        return 'OK';
      case Level.yellow:
        return 'Low';
      case Level.red:
        return 'Critical';
    }
  }

  String _warehouseStatus(InventoryItem item) {
    final wh = item.warehouseQty;
    final max = item.maxQty;
    final base = max > 0 ? max.toDouble() : 100.0;
    final ratio = base > 0 ? (wh / base).clamp(0.0, 1.0) : 0.0;
    if (wh == 0 || ratio < 0.3) {
      return 'Critical';
    }
    if (ratio < 0.7) {
      return 'Low';
    }
    return 'OK';
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
