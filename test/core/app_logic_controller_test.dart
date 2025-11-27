import 'package:flutter_test/flutter_test.dart';

import 'package:bar_stockapp_codexai/core/app_controller.dart';
import 'package:bar_stockapp_codexai/core/app_logic.dart';
import 'package:bar_stockapp_codexai/core/app_state.dart';
import 'package:bar_stockapp_codexai/core/models/group.dart';
import 'package:bar_stockapp_codexai/core/models/inventory_item.dart';
import 'package:bar_stockapp_codexai/core/models/order_item.dart';
import 'package:bar_stockapp_codexai/core/models/product.dart';
import 'package:bar_stockapp_codexai/core/models/restock_item.dart';
import 'package:bar_stockapp_codexai/core/models/staff_member.dart';
import 'package:bar_stockapp_codexai/core/undo_manager.dart';

AppState _buildState({int warehouseQty = 12}) {
  final product = Product(id: 'gin', name: 'Gin', isAlcohol: true);
  return AppState(
    inventory: [
      InventoryItem(
        product: product,
        groupName: 'Bar',
        sortIndex: 0,
        maxQty: 10,
        approxQty: 3,
        warehouseQty: warehouseQty,
        level: Level.red,
      ),
    ],
    groups: [Group(name: 'Bar', sortIndex: 0)],
    restock: [
      RestockItem(product: product, approxNeed: 7, approxCurrent: 3),
    ],
    orders: [
      OrderItem(product: product, quantity: 4, status: OrderStatus.pending),
    ],
    history: [],
    staff: [
      StaffMember.create(
        login: 'admin',
        displayName: 'Admin',
        role: StaffRole.admin,
        password: '1234',
      ),
    ],
    activeStaffId: null,
  );
}

UndoManager _undoManager() => UndoManager(timeLimit: const Duration(hours: 1));

void main() {
  group('AppLogic thresholds', () {
    test('bar low detection respects threshold', () {
      final state = _buildState();
      final item = state.inventory.first;
      expect(AppLogic.isBarLow(item), isTrue);

      AppLogic.setFillPercent(state, item.product.id, 100);
      expect(AppLogic.isBarLow(item), isFalse);

      AppLogic.setFillPercent(state, item.product.id, 10);
      expect(AppLogic.isBarLow(item), isTrue);
    });

    test('warehouse low respects tracking flag', () {
      final state = _buildState(warehouseQty: 2);
      final item = state.inventory.first;
      expect(AppLogic.isLowStock(item), isTrue);

      item.trackWarehouseLevel = false;
      expect(AppLogic.isLowStock(item), isFalse);
    });
  });

  group('Restock integrity', () {
    test('applyCustomRestock clamps to capacity and removes entries', () {
      final state = _buildState();
      final controller = AppController(
        initialState: state,
        undoManager: _undoManager(),
        persistCallback: (_) async {},
      );
      final target = state.restock.first;
      final amount = target.approxNeed + 5;

      controller.applyCustomRestock({target.product.id: amount});

      final item = state.inventory.first;
      expect(item.approxQty, lessThanOrEqualTo(item.maxQty.toDouble()));
      expect(state.restock.any((r) => r.product.id == target.product.id), isFalse);
    });
  });

  group('Order flow', () {
    test('order quantity increase and deliver updates warehouse', () {
      final state = _buildState();
      final controller = AppController(
        initialState: state,
        undoManager: _undoManager(),
        persistCallback: (_) async {},
      );

      final productId = state.inventory.first.product.id;
      controller.addToOrder(productId);
      final firstOrder = state.orders.firstWhere((o) => o.product.id == productId);
      final prevQty = firstOrder.quantity;
      controller.changeOrderQty(productId, prevQty + 3);
      expect(firstOrder.quantity, prevQty + 3);

      controller.changeOrderStatus(productId, OrderStatus.confirmed);
      controller.markOrderDelivered(productId);
      final inventoryItem = state.inventory.first;
      expect(inventoryItem.warehouseQty, greaterThan(12));
      expect(state.orders.any((o) => o.product.id == productId), isFalse);
    });
  });

  group('Undo protection', () {
    test('workers cannot undo order-only snapshots', () {
      final state = _buildState();
      final undo = _undoManager();
      final controller = AppController(
        initialState: state,
        undoManager: undo,
        persistCallback: (_) async {},
      );

      final productId = state.inventory.first.product.id;
      controller.addToOrder(productId);
      expect(undo.hasUndoEntries, isTrue);

      final workerResult = undo.restoreLatestForRole(StaffRole.worker);
      expect(workerResult, isNull);

      controller.addToRestock(productId);
      final managerResult = undo.restoreLatestForRole(StaffRole.manager);
      expect(managerResult, isNotNull);
    });
  });
}
