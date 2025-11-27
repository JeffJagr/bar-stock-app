import 'package:flutter/foundation.dart';

import 'app_controller.dart';
import 'app_state.dart';
import 'models/order_item.dart';
import 'models/staff_member.dart';
import 'undo_manager.dart';

/// Bridges [AppController] with Flutter widgets via [ChangeNotifier].
class AppNotifier extends ChangeNotifier {
  AppNotifier({
    required AppState initialState,
    required UndoManager undoManager,
    PersistCallback? persistCallback,
  })  : _state = initialState,
        _controller = AppController(
          initialState: initialState,
          undoManager: undoManager,
          persistCallback: persistCallback,
        );

  AppState _state;
  final AppController _controller;

  AppState get state => _state;
  AppController get controller => _controller;

  void replaceState(AppState newState) {
    _state = newState;
    _controller.state = newState;
    notifyListeners();
  }

  void setActiveStaffId(String? staffId) {
    _state.activeStaffId = staffId;
    notifyListeners();
  }

  void persistState() {
    _controller.persistState();
  }

  bool restoreLatestUndo() {
    final restored = _controller.undoManager.restoreLatest();
    if (restored == null) {
      return false;
    }
    replaceState(restored);
    return true;
  }

  void changeFillPercent(String productId, double percent) {
    _controller.changeFillPercent(productId, percent);
    notifyListeners();
  }

  void changeMaxQty(String productId, int maxQty) {
    _controller.changeMaxQty(productId, maxQty);
    notifyListeners();
  }

  void addToRestock(String productId) {
    _controller.addToRestock(productId);
    notifyListeners();
  }

  bool applyCustomRestock(Map<String, double> amounts) {
    final applied = _controller.applyCustomRestock(amounts);
    if (applied) {
      notifyListeners();
    }
    return applied;
  }

  bool addAllLowItemsToRestock() {
    final added = _controller.addAllLowItemsToRestock();
    if (added) {
      notifyListeners();
    }
    return added;
  }

  void changeWarehouseQty(String productId, int newQty) {
    _controller.changeWarehouseQty(productId, newQty);
    notifyListeners();
  }

  void addToOrder(String productId) {
    _controller.addToOrder(productId);
    notifyListeners();
  }

  void changeOrderQty(String productId, int newQty) {
    _controller.changeOrderQty(productId, newQty);
    notifyListeners();
  }

  void changeOrderStatus(String productId, OrderStatus status) {
    _controller.changeOrderStatus(productId, status);
    notifyListeners();
  }

  void markOrderDelivered(String productId) {
    _controller.markOrderDelivered(productId);
    notifyListeners();
  }

  void addGroup(String name) {
    _controller.addGroup(name);
    notifyListeners();
  }

  void renameGroup(String oldName, String newName) {
    _controller.renameGroup(oldName, newName);
    notifyListeners();
  }

  void deleteGroup(String name) {
    _controller.deleteGroup(name);
    notifyListeners();
  }

  void addProduct({
    required String groupName,
    required String name,
    required bool isAlcohol,
    required int maxQty,
    required int warehouseQty,
  }) {
    _controller.addProduct(
      groupName: groupName,
      name: name,
      isAlcohol: isAlcohol,
      maxQty: maxQty,
      warehouseQty: warehouseQty,
    );
    notifyListeners();
  }

  void editProduct({
    required String productId,
    String? name,
    bool? isAlcohol,
    String? groupName,
    int? maxQty,
    int? warehouseQty,
  }) {
    _controller.editProduct(
      productId: productId,
      name: name,
      isAlcohol: isAlcohol,
      groupName: groupName,
      maxQty: maxQty,
      warehouseQty: warehouseQty,
    );
    notifyListeners();
  }

  void deleteProduct(String productId) {
    _controller.deleteProduct(productId);
    notifyListeners();
  }

  void toggleTrackWarehouse(String productId, bool track) {
    _controller.toggleTrackWarehouse(productId, track);
    notifyListeners();
  }

  String? createStaffAccount(
    String login,
    String displayName,
    StaffRole role,
    String password,
  ) {
    final result =
        _controller.createStaffAccount(login, displayName, role, password);
    if (result == null) {
      notifyListeners();
    }
    return result;
  }
}
