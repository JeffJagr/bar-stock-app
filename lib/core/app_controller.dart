import 'app_logic.dart';
import 'app_state.dart';
import 'app_storage.dart';
import 'models/history_entry.dart';
import 'models/order_item.dart';
import 'models/staff_member.dart';
import 'undo_manager.dart';

typedef PersistCallback = Future<void> Function(AppState state);

/// Centralized coordinator for mutating [AppState] and persisting changes.
class AppController {
  AppController({
    required AppState initialState,
    required this.undoManager,
    PersistCallback? persistCallback,
  }) : state = initialState,
       _persistCallback = persistCallback ?? AppStorage.saveState;

  AppState state;
  final UndoManager undoManager;
  final PersistCallback _persistCallback;

  void persistState() => _persistCallback(state);

  void changeFillPercent(String productId, double percent) {
    undoManager.pushSnapshot(state, UndoActionKind.stockChange);
    AppLogic.setFillPercent(state, productId, percent);
    _persist();
  }

  void changeMaxQty(String productId, int maxQty) {
    AppLogic.setMaxQty(state, productId, maxQty);
    _persist();
  }

  void addToRestock(String productId) {
    undoManager.pushSnapshot(state, UndoActionKind.stockChange);
    AppLogic.addToRestock(state, productId);
    _persist();
  }

  bool applyCustomRestock(Map<String, double> amounts) {
    if (amounts.isEmpty) return false;
    undoManager.pushSnapshot(state, UndoActionKind.stockChange);
    AppLogic.applyCustomRestock(state, amounts);
    _persist();
    return true;
  }

  bool addAllLowItemsToRestock() {
    final lowItems = AppLogic.lowItems(state);
    if (lowItems.isEmpty) return false;
    undoManager.pushSnapshot(state, UndoActionKind.stockChange);
    for (final item in lowItems) {
      AppLogic.addToRestock(state, item.product.id);
    }
    _persist();
    return true;
  }

  void changeWarehouseQty(String productId, int newQty) {
    undoManager.pushSnapshot(state, UndoActionKind.stockChange);
    AppLogic.setWarehouseQty(state, productId, newQty);
    _persist();
  }

  void addToOrder(String productId) {
    undoManager.pushSnapshot(state, UndoActionKind.orderChange);
    AppLogic.addToOrders(state, productId);
    _persist();
  }

  void changeOrderQty(String productId, int newQty) {
    undoManager.pushSnapshot(state, UndoActionKind.orderChange);
    AppLogic.setOrderQty(state, productId, newQty);
    _persist();
  }

  void changeOrderStatus(String productId, OrderStatus status) {
    if (status != OrderStatus.delivered) {
      undoManager.pushSnapshot(state, UndoActionKind.orderChange);
    }
    AppLogic.setOrderStatus(state, productId, status);
    _persist();
  }

  void markOrderDelivered(String productId) {
    AppLogic.markOrderDelivered(state, productId);
    _persist();
  }

  void addGroup(String name) {
    AppLogic.addGroup(state, name);
    _persist();
  }

  void renameGroup(String oldName, String newName) {
    AppLogic.renameGroup(state, oldName, newName);
    _persist();
  }

  void deleteGroup(String name) {
    AppLogic.deleteGroup(state, name);
    _persist();
  }

  void addProduct({
    required String groupName,
    required String name,
    required bool isAlcohol,
    required int maxQty,
    required int warehouseQty,
  }) {
    AppLogic.addProduct(
      state,
      groupName: groupName,
      name: name,
      isAlcohol: isAlcohol,
      maxQty: maxQty,
      warehouseQty: warehouseQty,
    );
    _persist();
  }

  void editProduct({
    required String productId,
    String? name,
    bool? isAlcohol,
    String? groupName,
    int? maxQty,
    int? warehouseQty,
  }) {
    AppLogic.editProduct(
      state,
      productId: productId,
      name: name,
      isAlcohol: isAlcohol,
      groupName: groupName,
      maxQty: maxQty,
      warehouseQty: warehouseQty,
    );
    _persist();
  }

  void deleteProduct(String productId) {
    AppLogic.deleteProduct(state, productId);
    _persist();
  }

  void toggleTrackWarehouse(String productId, bool track) {
    AppLogic.setTrackWarehouse(state, productId, track);
    _persist();
  }

  String? createStaffAccount(
    String login,
    String displayName,
    StaffRole role,
    String password,
  ) {
    final normalized = login.trim().toLowerCase();
    if (state.staff.any((s) => s.login == normalized)) {
      return 'Login already exists';
    }
    if (password.length < 4) {
      return 'Password must be at least 4 characters';
    }
    final staff = StaffMember.create(
      login: normalized,
      displayName: displayName.trim(),
      role: role,
      password: password,
    );
    state.staff.add(staff);
    AppLogic.logCustomAction(
      state,
      action: 'Created staff ${staff.displayName} (${role.name})',
      kind: HistoryKind.auth,
      actionType: HistoryActionType.create,
    );
    _persist();
    return null;
  }

  String? updateStaffAccount(
    String staffId, {
    String? displayName,
    StaffRole? role,
    String? password,
  }) {
    final index = state.staff.indexWhere((s) => s.id == staffId);
    if (index < 0) {
      return 'Staff account not found';
    }
    final staff = state.staff[index];
    var changed = false;
    if (displayName != null) {
      final trimmed = displayName.trim();
      if (trimmed.isEmpty) {
        return 'Display name is required';
      }
      if (staff.displayName != trimmed) {
        staff.displayName = trimmed;
        changed = true;
      }
    }
    if (role != null && staff.role != role) {
      staff.role = role;
      changed = true;
    }
    if (password != null && password.isNotEmpty) {
      final updated = staff.withPassword(password);
      staff
        ..salt = updated.salt
        ..passwordHash = updated.passwordHash;
      changed = true;
    }
    if (!changed) {
      return null;
    }
    AppLogic.logCustomAction(
      state,
      action: 'Updated staff ${staff.displayName} (${staff.role.name})',
      kind: HistoryKind.auth,
      actionType: HistoryActionType.update,
    );
    _persist();
    return null;
  }

  String? deleteStaffAccount(String staffId) {
    final index = state.staff.indexWhere((s) => s.id == staffId);
    if (index < 0) {
      return 'Staff account not found';
    }
    final removed = state.staff.removeAt(index);
    if (state.activeStaffId == removed.id) {
      state.activeStaffId = null;
    }
    AppLogic.logCustomAction(
      state,
      action: 'Deleted staff ${removed.displayName} (${removed.role.name})',
      kind: HistoryKind.auth,
      actionType: HistoryActionType.delete,
    );
    _persist();
    return null;
  }

  void _persist() {
    _persistCallback(state);
  }
}
