import 'dart:math';

import 'app_state.dart';
import 'constants.dart';
import 'models/inventory_item.dart';
import 'models/restock_item.dart';
import 'models/order_item.dart';
import 'models/history_entry.dart';
import 'models/product.dart';
import 'models/group.dart';
import 'models/staff_member.dart';

class AppLogic {
  static StaffMember? _currentStaff;

  static void setCurrentStaff(StaffMember? staff) {
    _currentStaff = staff;
  }

  static StaffMember? get currentStaff => _currentStaff;
  /// Convert ratio (0.0 – 1.0) into Level
  static Level _levelFromRatio(double ratio) {
    if (ratio >= AppConstants.barGreenThreshold) return Level.green; // almost full
    if (ratio >= AppConstants.barYellowThreshold) return Level.yellow; // mid threshold
    return Level.red; // below warning threshold
  }

  /// Helper: write line to history
  static void _log(
    AppState state,
    String action, {
    HistoryKind kind = HistoryKind.general,
    HistoryActionType actionType = HistoryActionType.general,
    StaffMember? actorOverride,
    Map<String, dynamic>? meta,
  }) {
    final actor = actorOverride ?? _currentStaff;
    state.history.add(
      HistoryEntry(
        timestamp: DateTime.now(),
        action: action,
        kind: kind,
        actionType: actionType,
        actorId: actor?.id ?? 'system',
        actorName: actor?.displayName ?? 'System',
        companyId: state.activeCompanyId,
        meta: meta,
      ),
    );
    if (state.history.length > AppConstants.historyMaxEntries) {
      state.history.removeAt(0); // limit history
    }
  }

  static T? _firstOrNull<T>(
    Iterable<T> items,
    bool Function(T item) test,
  ) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }

  static InventoryItem? _findInventoryItem(
    AppState state,
    String productId,
  ) {
    return _firstOrNull<InventoryItem>(
      state.inventory,
      (item) => item.product.id == productId,
    );
  }

  static OrderItem? _findOpenOrder(AppState state, String productId) {
    return _firstOrNull<OrderItem>(
      state.orders,
      (order) =>
          order.product.id == productId && order.status != OrderStatus.delivered,
    );
  }

  // ---------- GROUPS & PRODUCTS MANAGEMENT ----------

  static void addGroup(AppState state, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final exists = state.groups.any(
      (g) => g.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) return;

    int sortIndex = 0;
    if (state.groups.isNotEmpty) {
      sortIndex = state.groups
              .map((g) => g.sortIndex)
              .reduce((a, b) => max(a, b)) +
          1;
    }

    state.groups.add(
      Group(
        name: trimmed,
        sortIndex: sortIndex,
        companyId: state.activeCompanyId,
      ),
    );
    _log(
      state,
      'Added group "$trimmed"',
      kind: HistoryKind.bar,
      actionType: HistoryActionType.create,
    );
  }

  static void renameGroup(
      AppState state, String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final group = state.groups.firstWhere(
      (g) => g.name == oldName,
      orElse: () => Group(name: '', sortIndex: 0),
    );
    if (group.name.isEmpty) return;

    final old = group.name;
    group.name = trimmed;

    for (final item in state.inventory) {
      if (item.groupName == old) {
        item.groupName = trimmed;
      }
    }

    _log(
      state,
      'Renamed group "$old" to "$trimmed"',
      kind: HistoryKind.bar,
      actionType: HistoryActionType.update,
    );
  }

  static void logCustomAction(
    AppState state, {
    required String action,
    HistoryKind kind = HistoryKind.general,
    HistoryActionType actionType = HistoryActionType.general,
    StaffMember? actor,
  }) {
    _log(
      state,
      action,
      kind: kind,
      actionType: actionType,
      actorOverride: actor,
    );
  }

  /// Delete a group and all its items (orders/restock tied to those products).
  static void deleteGroup(AppState state, String groupName) {
    state.groups.removeWhere((g) => g.name == groupName);

    final idsToRemove = state.inventory
        .where((i) => i.groupName == groupName)
        .map((i) => i.product.id)
        .toSet();

    state.inventory.removeWhere((i) => idsToRemove.contains(i.product.id));
    state.restock.removeWhere((r) => idsToRemove.contains(r.product.id));
    state.orders.removeWhere((o) => idsToRemove.contains(o.product.id));

    _log(
      state,
      'Deleted group "$groupName" and ${idsToRemove.length} products',
      kind: HistoryKind.bar,
      actionType: HistoryActionType.delete,
    );
  }

  static void addProduct(
    AppState state, {
    required String groupName,
    required String name,
    required bool isAlcohol,
    required int maxQty,
    required int warehouseQty,
  }) {
    final trimmedName = name.trim();
    final trimmedGroup = groupName.trim();
    if (trimmedName.isEmpty || trimmedGroup.isEmpty) return;

    // ensure group exists
    if (!state.groups.any((g) => g.name == trimmedGroup)) {
      addGroup(state, trimmedGroup);
    }

    // generate unique id
    final baseId = trimmedName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final id = '${baseId}_${DateTime.now().millisecondsSinceEpoch}';

    final product = Product(
      id: id,
      name: trimmedName,
      isAlcohol: isAlcohol,
      companyId: state.activeCompanyId,
    );

    // sort index at end of this group
    final groupItems =
        state.inventory.where((i) => i.groupName == trimmedGroup);
    int sortIndex = 0;
    if (groupItems.isNotEmpty) {
      sortIndex = groupItems
              .map((i) => i.sortIndex)
              .reduce((a, b) => max(a, b)) +
          1;
    }

    final maxQ = max(0, maxQty);
    final whQ = max(0, warehouseQty);
    final approx = maxQ.toDouble();
    final level = maxQ > 0 ? _levelFromRatio(1.0) : Level.red;

    state.inventory.add(
      InventoryItem(
        product: product,
        companyId: state.activeCompanyId,
        groupName: trimmedGroup,
        sortIndex: sortIndex,
        maxQty: maxQ,
        approxQty: approx,
        warehouseQty: whQ,
        level: level,
      ),
    );

    _log(
      state,
      'Added product "$trimmedName" to group "$trimmedGroup" (bar max=$maxQ, warehouse=$whQ)',
      kind: HistoryKind.bar,
      actionType: HistoryActionType.create,
    );
  }

  /// Edit basic product fields and optionally move to another group.
  static void editProduct(
    AppState state, {
    required String productId,
    String? name,
    bool? isAlcohol,
    String? groupName,
    int? maxQty,
    int? warehouseQty,
  }) {
    final item = _findInventoryItem(state, productId);
    if (item == null) return;

    final oldGroup = item.groupName;
    final targetGroup = groupName?.trim().isNotEmpty == true
        ? groupName!.trim()
        : oldGroup;

    if (!state.groups.any((g) => g.name == targetGroup)) {
      addGroup(state, targetGroup);
    }

    if (item.groupName != targetGroup) {
      item.groupName = targetGroup;
      // move to end of target group
      final maxSortInGroup = state.inventory
          .where((i) => i.groupName == targetGroup)
          .fold<int>(0, (prev, e) => e.sortIndex > prev ? e.sortIndex : prev);
      item.sortIndex = maxSortInGroup + 1;
    }

    if (name != null && name.trim().isNotEmpty) {
      item.product.name = name.trim();
    }
    if (isAlcohol != null) {
      item.product.isAlcohol = isAlcohol;
    }
    if (maxQty != null) {
      setMaxQty(state, productId, maxQty);
    }
    if (warehouseQty != null) {
      setWarehouseQty(state, productId, warehouseQty);
    }

    _log(
      state,
      'Edited product "${item.product.name}" (group: $oldGroup -> $targetGroup)',
      kind: HistoryKind.bar,
      actionType: HistoryActionType.update,
    );
  }

  /// Remove product and its references.
  static void deleteProduct(AppState state, String productId) {
    final removed = state.inventory
        .where((i) => i.product.id == productId)
        .map((i) => i.product.name)
        .toList();
    state.inventory.removeWhere((i) => i.product.id == productId);
    state.restock.removeWhere((r) => r.product.id == productId);
    state.orders.removeWhere((o) => o.product.id == productId);

    if (removed.isNotEmpty) {
      _log(
        state,
        'Deleted product "${removed.first}"',
        kind: HistoryKind.bar,
        actionType: HistoryActionType.delete,
      );
    }
  }

  // ---------- BAR LOGIC ----------

  /// Update max quantity, keep the same fill ratio if possible
  static void setMaxQty(AppState state, String productId, int maxQty) {
    final item = _findInventoryItem(state, productId);
    if (item == null) return;

    final oldMax = item.maxQty;
    final oldApprox = item.approxQty;

    if (maxQty <= 0) {
      item.maxQty = 0;
      item.approxQty = 0;
      item.level = Level.red;
      _log(
        state,
        'Set max qty of ${item.product.name} to 0',
        kind: HistoryKind.bar,
        actionType: HistoryActionType.update,
      );
      return;
    }

    double ratio;
    if (oldMax > 0) {
      ratio = (oldApprox / oldMax).clamp(0.0, 1.0);
    } else {
      ratio = 1.0;
    }

    item.maxQty = maxQty;
    item.approxQty = maxQty * ratio;
    item.level = _levelFromRatio(ratio);

    _log(
      state,
      'Changed max qty of ${item.product.name} from $oldMax to $maxQty',
      kind: HistoryKind.bar,
      actionType: HistoryActionType.update,
    );
  }

  /// Slider: set fill percent (0–100), recalc approxQty and level
  static void setFillPercent(
      AppState state, String productId, double percent) {
    final item = _findInventoryItem(state, productId);
    if (item == null) return;

    final clamped = percent.clamp(0.0, 100.0);
    if (item.maxQty <= 0) {
      item.approxQty = 0;
      item.level = Level.red;
      _log(
        state,
        'Tried to change bar level of ${item.product.name}, but max qty is 0',
        kind: HistoryKind.bar,
      );
      return;
    }

    final prevApprox = item.approxQty;
    final ratio = clamped / 100.0;
    item.approxQty = item.maxQty * ratio;
    item.level = _levelFromRatio(ratio);

    _log(
      state,
      'Set bar level of ${item.product.name} to ${clamped.toStringAsFixed(0)}%',
      kind: HistoryKind.bar,
      actionType: HistoryActionType.update,
      meta: {
        'productId': item.product.id,
        'productName': item.product.name,
        'delta': (item.approxQty - prevApprox),
        'newValue': item.approxQty,
      },
    );
  }

  /// All groups sorted by sortIndex
  static List<String> groupNames(AppState state) {
    final names = state.groups.toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return names.map((g) => g.name).toList();
  }

  /// Items of a group sorted by sortIndex
  static List<InventoryItem> itemsForGroup(
      AppState state, String groupName) {
    final items = state.inventory
        .where((i) => i.groupName == groupName)
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return items;
  }

  /// Items below bar-level threshold (LOW tab uses bar levels)
  static List<InventoryItem> lowItems(AppState state) {
    return state.inventory.where(isBarLow).toList();
  }

  /// Determine if a bar item should be marked as low.
  static bool isBarLow(InventoryItem item) {
    if (!item.trackWarehouseLevel) return false;
    if (item.maxQty <= 0) return true;
    final ratio = (item.approxQty / item.maxQty).clamp(0.0, 1.0);
    return ratio < AppConstants.barLowThreshold;
  }

  /// Determine if storage level is below threshold.
  static bool isLowStock(InventoryItem item) {
    if (!AppConstants.warehouseTrackingEnabled) return false;
    if (!item.trackWarehouseLevel) return false;
    if (item.maxQty <= 0) return true;
    final ratio = (item.warehouseQty / item.maxQty).clamp(0.0, 1.0);
    return ratio < AppConstants.warehouseLowThreshold;
  }

  /// Whether group contains at least one low-stock storage item.
  static bool isGroupLow(AppState state, String groupName) {
    return lowStockCountForGroup(state, groupName) > 0;
  }

  static int lowStockCountForGroup(AppState state, String groupName) {
    final items = itemsForGroup(state, groupName);
    return items.where(isLowStock).length;
  }

  static int barLowCountForGroup(AppState state, String groupName) {
    final items = itemsForGroup(state, groupName);
    return items.where(isBarLow).length;
  }

  // ---------- WAREHOUSE LOGIC ----------

  /// Change warehouse quantity, never below 0
  static void setWarehouseQty(
      AppState state, String productId, int newQty) {
    final item = _findInventoryItem(state, productId);
    if (item == null) return;
    final old = item.warehouseQty;
    if (newQty < 0) newQty = 0;
    item.warehouseQty = newQty;
    _log(
      state,
      'Warehouse qty of ${item.product.name} changed from $old to $newQty',
      kind: HistoryKind.warehouse,
      actionType: HistoryActionType.update,
    );
  }

  static void setTrackWarehouse(
      AppState state, String productId, bool track) {
    if (!AppConstants.warehouseTrackingEnabled) {
      return;
    }
    final item = _findInventoryItem(state, productId);
    if (item == null) {
      return;
    }
    if (item.trackWarehouseLevel == track) return;
    item.trackWarehouseLevel = track;
    _log(
      state,
      '${track ? 'Enabled' : 'Disabled'} tracking for ${item.product.name}',
      kind: HistoryKind.warehouse,
      actionType: HistoryActionType.update,
      meta: {
        'productId': item.product.id,
        'productName': item.product.name,
        'tracking': track,
      },
    );
  }

  // ---------- RESTOCK LOGIC ----------

  /// Add or update item in Restock list (approx to fill bar to max)
  static void addToRestock(AppState state, String productId) {
    final item = _findInventoryItem(state, productId);
    if (item == null) return;

    if (item.maxQty <= 0) {
      _log(
        state,
        'Skip restock for ${item.product.name}: max qty is 0',
        kind: HistoryKind.restock,
      );
      return;
    }

    final need =
        (item.maxQty.toDouble() - item.approxQty).clamp(0.0, AppConstants.restockClampMax);
    final current = item.approxQty;

    if (need <= 0) {
      _log(
        state,
        'Skip restock for ${item.product.name}: already full',
        kind: HistoryKind.restock,
      );
      return; // already full
    }

    final existingIndex = state.restock.indexWhere(
      (r) => r.product.id == productId,
    );

    if (existingIndex >= 0) {
      final r = state.restock[existingIndex];
      r.approxCurrent = current;
      r.approxNeed = need;
      _log(
        state,
        'Updated restock for ${item.product.name}: need ≈ ${need.toStringAsFixed(1)}',
        kind: HistoryKind.restock,
      );
    } else {
      state.restock.add(
        RestockItem(
          product: item.product,
          approxNeed: need,
          approxCurrent: current,
        ),
      );
      _log(
        state,
        'Added to restock: ${item.product.name}, need ≈ ${need.toStringAsFixed(1)}',
        kind: HistoryKind.restock,
      );
    }
  }

  /// Helper: apply restock amount for a single RestockItem
  static double _applyRestockAmount(
    AppState state,
    RestockItem restockItem,
    double requestedAmount,
  ) {
    final item = _findInventoryItem(state, restockItem.product.id);
    if (item == null) {
      return 0;
    }

    if (requestedAmount <= 0) {
      return 0;
    }

    final availableWarehouse = item.warehouseQty.toDouble();
    if (availableWarehouse <= 0) {
      _log(
        state,
        'Cannot restock ${item.product.name}: warehouse is empty',
        kind: HistoryKind.restock,
      );
      return 0;
    }

    final maxBar = item.maxQty > 0 ? item.maxQty.toDouble() : 0.0;
    final capacity =
        maxBar > 0 ? (maxBar - item.approxQty).clamp(0.0, double.infinity) : 0.0;
    if (capacity <= 0) {
      _log(
        state,
        '${item.product.name} already at max capacity',
        kind: HistoryKind.restock,
      );
      return 0;
    }

    double amount = requestedAmount;
    if (amount > capacity) amount = capacity;
    if (amount > availableWarehouse) amount = availableWarehouse;

    final movedInt = amount.round().clamp(0, item.warehouseQty);
    if (movedInt <= 0) {
      return 0;
    }

    final moved = movedInt.toDouble();
    final prev = item.approxQty;

    item.warehouseQty -= movedInt;
    item.approxQty =
        (item.approxQty + moved).clamp(0.0, maxBar > 0 ? maxBar : item.approxQty + moved);

    final ratio = item.maxQty > 0 ? (item.approxQty / item.maxQty) : 0.0;
    item.level = _levelFromRatio(ratio);

    _log(
      state,
      'Restocked ${item.product.name}: prev ${prev.toStringAsFixed(1)}, '
          '+${moved.toStringAsFixed(1)}, new ${item.approxQty.toStringAsFixed(1)}',
      kind: HistoryKind.restock,
      actionType: HistoryActionType.update,
      meta: {
        'productId': item.product.id,
        'productName': item.product.name,
        'restocked': moved,
      },
    );

    return moved;
  }

  static void _applyRestockAmounts(
    AppState state,
    Map<String, double> amountByProduct, {
    required String summaryLabel,
  }) {
    if (amountByProduct.isEmpty) return;

    final appliedIds = <String>{};
    for (final entry in amountByProduct.entries) {
      final restockItemIndex = state.restock.indexWhere(
        (r) => r.product.id == entry.key,
      );
      if (restockItemIndex < 0) continue;

      final restockItem = state.restock[restockItemIndex];
      final moved =
          _applyRestockAmount(state, restockItem, entry.value);
      if (moved > 0) {
        appliedIds.add(entry.key);
      }
    }

    if (appliedIds.isEmpty) return;

    state.restock.removeWhere((r) => appliedIds.contains(r.product.id));
    _log(
      state,
      'Applied restock for ${appliedIds.length} items ($summaryLabel)',
      kind: HistoryKind.restock,
      actionType: HistoryActionType.update,
    );
  }

  /// Apply ALL restock items
  static void applyRestock(AppState state) {
    final amounts = {
      for (final r in state.restock) r.product.id: r.approxNeed,
    };
    _applyRestockAmounts(state, amounts, summaryLabel: 'all');
  }

  /// Apply only selected restock items (by product id)
  static void applySelectedRestock(AppState state, List<String> productIds) {
    if (productIds.isEmpty) return;
    final idsSet = productIds.toSet();
    final amounts = <String, double>{};
    for (final r in state.restock) {
      if (idsSet.contains(r.product.id)) {
        amounts[r.product.id] = r.approxNeed;
      }
    }
    _applyRestockAmounts(state, amounts, summaryLabel: 'selected');
  }

  /// Apply restock using explicit custom amounts per product.
  static void applyCustomRestock(
    AppState state,
    Map<String, double> amountByProduct,
  ) {
    _applyRestockAmounts(state, amountByProduct, summaryLabel: 'custom');
  }

  // ---------- ORDERS LOGIC ----------

  /// Add item to orders (from Warehouse or later from Bar)
  /// If order already exists and is still pending/confirmed -> increase quantity.
  static void addToOrders(AppState state, String productId) {
    final item = _findInventoryItem(state, productId);
    if (item == null) return;

    final defaultQty = item.maxQty > 0 ? item.maxQty : 1;

    final existingOrder = _findOpenOrder(state, productId);

    if (existingOrder != null) {
      final order = existingOrder;
      order.quantity += defaultQty;
      _log(
        state,
        'Increased order for ${item.product.name} by $defaultQty (total ${order.quantity})',
        kind: HistoryKind.order,
        actionType: HistoryActionType.update,
        meta: {
          'productId': item.product.id,
          'productName': item.product.name,
          'quantity': defaultQty.toDouble(),
        },
      );
    } else {
      state.orders.add(
        OrderItem(
          product: item.product,
          companyId: state.activeCompanyId,
          quantity: defaultQty,
          status: OrderStatus.pending,
        ),
      );
      _log(
        state,
        'Created new order for ${item.product.name}: qty $defaultQty',
        kind: HistoryKind.order,
        actionType: HistoryActionType.create,
        meta: {
          'productId': item.product.id,
          'productName': item.product.name,
          'quantity': defaultQty.toDouble(),
        },
      );
    }
  }

  static void setOrderQty(
      AppState state, String productId, int newQty) {
    final order = _findOpenOrder(state, productId);
    if (order == null) return;
    final old = order.quantity;
    if (newQty < 0) newQty = 0;
    order.quantity = newQty;
    _log(
      state,
      'Changed order qty for ${order.product.name} from $old to $newQty',
      kind: HistoryKind.order,
      actionType: HistoryActionType.update,
      meta: {
        'productId': order.product.id,
        'productName': order.product.name,
        'quantity': (newQty - old).toDouble(),
      },
    );
  }

  static void setOrderStatus(
      AppState state, String productId, OrderStatus status) {
    final order = _findOpenOrder(state, productId);
    if (order == null) return;
    final old = order.status;
    order.status = status;
    _log(
      state,
      'Status of order for ${order.product.name} changed from $old to $status',
      kind: HistoryKind.order,
      actionType: HistoryActionType.update,
    );
  }

  /// Mark order as delivered: add to warehouse and remove order
  static void markOrderDelivered(AppState state, String productId) {
    final order = _findOpenOrder(state, productId);
    if (order == null) return;

    final item = _findInventoryItem(state, productId);
    if (item == null) return;

    item.warehouseQty += order.quantity;

    _log(
      state,
      'Order delivered for ${item.product.name}: +${order.quantity} to warehouse',
      kind: HistoryKind.warehouse,
      actionType: HistoryActionType.update,
      meta: {
        'productId': item.product.id,
        'productName': item.product.name,
        'quantity': order.quantity.toDouble(),
      },
    );
    state.orders.remove(order);
  }
}
