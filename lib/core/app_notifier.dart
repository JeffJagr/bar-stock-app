import 'package:flutter/foundation.dart';

import '../data/firebase_remote_repository.dart';
import '../data/remote_repository.dart' as cloud;
import '../models/cloud_user_role.dart';
import '../models/company_member.dart';
import 'app_controller.dart';
import 'app_state.dart';
import 'error_reporter.dart';
import 'models/inventory_item.dart';
import 'models/history_entry.dart';
import 'models/order_item.dart';
import 'models/staff_member.dart';
import 'undo_manager.dart';

/// Bridges [AppController] with Flutter widgets via [ChangeNotifier].
class AppNotifier extends ChangeNotifier {
  AppNotifier({
    required AppState initialState,
    required UndoManager undoManager,
    PersistCallback? persistCallback,
    cloud.RemoteRepository? remoteRepository,
  }) : _state = initialState,
       _controller = AppController(
         initialState: initialState,
         undoManager: undoManager,
         persistCallback: persistCallback,
       ),
       _remoteRepository = remoteRepository ?? FirebaseRemoteRepository();

  AppState _state;
  final AppController _controller;
  final cloud.RemoteRepository _remoteRepository;
  String? _currentUserId;
  CloudUserRole? _cloudUserRole;
  CompanyMember? _currentCompanyMember;

  AppState get state => _state;
  AppController get controller => _controller;
  String? get currentUserId => _currentUserId;
  CloudUserRole? get cloudUserRole => _cloudUserRole;
  String? get activeCompanyId => _state.activeCompanyId;
  CompanyMember? get currentStaffMember => _currentCompanyMember;

  void replaceState(AppState newState) {
    _state = newState;
    _controller.state = newState;
    notifyListeners();
  }

  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  void setCloudUserRole(CloudUserRole? role) {
    _cloudUserRole = role;
    notifyListeners();
  }

  void setCurrentStaffMember(CompanyMember? member) {
    _currentCompanyMember = member;
    notifyListeners();
  }

  void setActiveStaffId(String? staffId) {
    _state.activeStaffId = staffId;
    notifyListeners();
  }

  void setActiveCompanyId(String? companyId) {
    _state.activeCompanyId = companyId;
    notifyListeners();
  }

  void persistState() {
    _controller.persistState();
  }

  Future<bool> syncFromCloud(String companyId) async {
    try {
      final remoteState =
          await _remoteRepository.fetchFullStateForCompany(companyId);
      remoteState.activeCompanyId ??= companyId;
      replaceState(remoteState);
      return true;
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Cloud fetch failed',
      );
      return false;
    }
  }

  bool restoreLatestUndo(StaffRole? role) {
    final restored = _controller.undoManager.restoreLatestForRole(role);
    if (restored == null) {
      return false;
    }
    replaceState(restored);
    _recordHistory(
      'Undo last action',
      HistoryKind.general,
      HistoryActionType.update,
    );
    return true;
  }

  bool canUndoEntry(HistoryEntry entry) {
    if (_state.history.isEmpty) return false;
    final latest = _state.history.last;
    if (!identical(entry, latest)) return false;
    if (!_undoableKinds.contains(entry.kind)) return false;
    if (!_undoableActions.contains(entry.actionType)) return false;
    final age = DateTime.now().difference(entry.timestamp);
    if (age > const Duration(minutes: 15)) return false;
    return _controller.undoManager.hasUndoForRole(null);
  }

  bool undoEntry(HistoryEntry entry) {
    if (!canUndoEntry(entry)) return false;
    final restored = _controller.undoManager.restoreLatestForRole(null);
    if (restored == null) return false;
    replaceState(restored);
    _recordHistory(
      'Undo: ${entry.action}',
      HistoryKind.general,
      HistoryActionType.update,
      meta: {
        'undoOf': entry.action,
        'kind': entry.kind.name,
        'actionType': entry.actionType.name,
      },
    );
    return true;
  }

  bool canUndoForRole(StaffRole? role) =>
      _controller.undoManager.hasUndoForRole(role);

  Future<AppState?> fetchCloudState(String ownerId) async {
    try {
      return await _remoteRepository.fetchFullStateForCompany(ownerId);
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Cloud sync failed',
      );
      return null;
    }
  }

  Future<bool> syncToCloud(String ownerId) async {
    try {
      await _remoteRepository.syncToCloud(ownerId, _state);
      return true;
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'Cloud push failed',
      );
      return false;
    }
  }

  void applyRemoteState(AppState remoteState) {
    final mergedState = _state.copy();
    mergedState.inventory = remoteState.inventory;
    mergedState.groups = remoteState.groups;
    mergedState.orders = remoteState.orders;
    mergedState.history = remoteState.history;
    mergedState.activeCompanyId =
        remoteState.activeCompanyId ?? mergedState.activeCompanyId;
    replaceState(mergedState);
  }

  void changeFillPercent(String productId, double percent) {
    _controller.changeFillPercent(productId, percent);
    _syncInventoryItem(productId);
    _recordHistory(
      'Adjusted bar level for $productId',
      HistoryKind.bar,
      HistoryActionType.update,
      meta: {'productId': productId, 'percent': percent},
    );
    notifyListeners();
  }

  void changeMaxQty(String productId, int maxQty) {
    _controller.changeMaxQty(productId, maxQty);
    _syncInventoryItem(productId);
    notifyListeners();
  }

  void addToRestock(String productId) {
    _controller.addToRestock(productId);
    _recordHistory(
      'Added $productId to restock list',
      HistoryKind.restock,
      HistoryActionType.create,
      meta: {'productId': productId},
    );
    notifyListeners();
  }

  bool applyCustomRestock(Map<String, double> amounts) {
    final applied = _controller.applyCustomRestock(amounts);
    if (applied) {
      _recordHistory(
        'Applied custom restock',
        HistoryKind.restock,
        HistoryActionType.update,
        meta: amounts.map((k, v) => MapEntry(k, v)),
      );
      notifyListeners();
    }
    return applied;
  }

  bool addAllLowItemsToRestock() {
    final added = _controller.addAllLowItemsToRestock();
    if (added) {
      _recordHistory(
        'Added low items to restock',
        HistoryKind.restock,
        HistoryActionType.create,
      );
      notifyListeners();
    }
    return added;
  }

  void changeWarehouseQty(String productId, int newQty) {
    _controller.changeWarehouseQty(productId, newQty);
    _syncInventoryItem(productId);
    _recordHistory(
      'Updated warehouse qty for $productId',
      HistoryKind.warehouse,
      HistoryActionType.update,
      meta: {'productId': productId, 'quantity': newQty},
    );
    notifyListeners();
  }

  void addToOrder(String productId) {
    _controller.addToOrder(productId);
    _syncOrder(productId);
    _recordHistory(
      'Added $productId to order',
      HistoryKind.order,
      HistoryActionType.create,
      meta: {'productId': productId},
    );
    notifyListeners();
  }

  void changeOrderQty(String productId, int newQty) {
    _controller.changeOrderQty(productId, newQty);
    _syncOrder(productId);
    _recordHistory(
      'Order qty for $productId -> $newQty',
      HistoryKind.order,
      HistoryActionType.update,
      meta: {'productId': productId, 'quantity': newQty},
    );
    notifyListeners();
  }

  void changeOrderStatus(String productId, OrderStatus status) {
    if (_state.activeCompanyId == null) {
      _controller.changeOrderStatus(productId, status);
      notifyListeners();
      return;
    }
    _controller.changeOrderStatus(productId, status);
    _remoteRepository.updateOrderStatus(
      _state.activeCompanyId ?? '',
      productId,
      status,
    );
    _recordHistory(
      'Order $productId status -> ${status.name}',
      HistoryKind.order,
      HistoryActionType.update,
      meta: {'productId': productId, 'status': status.name},
    );
    notifyListeners();
  }

  void markOrderDelivered(String productId) {
    if (_state.activeCompanyId == null) {
      _controller.markOrderDelivered(productId);
      notifyListeners();
      return;
    }
    _controller.markOrderDelivered(productId);
    _remoteRepository.updateOrderStatus(
      _state.activeCompanyId ?? '',
      productId,
      OrderStatus.delivered,
    );
    _recordHistory(
      'Order $productId delivered',
      HistoryKind.order,
      HistoryActionType.update,
      meta: {'productId': productId, 'status': OrderStatus.delivered.name},
    );
    notifyListeners();
  }

  void addGroup(String name) {
    _controller.addGroup(name);
    _syncGroups();
    _recordHistory(
      'Created group $name',
      HistoryKind.bar,
      HistoryActionType.create,
      meta: {'group': name},
    );
    notifyListeners();
  }

  void renameGroup(String oldName, String newName) {
    _controller.renameGroup(oldName, newName);
    _syncGroups();
    _recordHistory(
      'Renamed group $oldName -> $newName',
      HistoryKind.bar,
      HistoryActionType.update,
      meta: {'old': oldName, 'new': newName},
    );
    notifyListeners();
  }

  void deleteGroup(String name) {
    _controller.deleteGroup(name);
    final companyId = _state.activeCompanyId;
    if (companyId != null) {
      _remoteRepository.deleteGroup(companyId, name);
    }
    _recordHistory(
      'Deleted group $name',
      HistoryKind.bar,
      HistoryActionType.delete,
      meta: {'group': name},
    );
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
    _syncProducts();
    _recordHistory(
      'Added product $name',
      HistoryKind.bar,
      HistoryActionType.create,
      meta: {'group': groupName},
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
    _syncProducts();
    _syncInventoryItem(productId);
    _recordHistory(
      'Updated product $productId',
      HistoryKind.bar,
      HistoryActionType.update,
      meta: {
        'productId': productId,
        if (name != null) 'name': name,
        if (groupName != null) 'group': groupName,
        if (maxQty != null) 'maxQty': maxQty,
        if (warehouseQty != null) 'warehouseQty': warehouseQty,
      },
    );
    notifyListeners();
  }

  void deleteProduct(String productId) {
    _controller.deleteProduct(productId);
    final companyId = _state.activeCompanyId;
    if (companyId != null) {
      _remoteRepository.deleteProduct(companyId, productId);
      _remoteRepository.deleteInventoryItem(companyId, productId);
    }
    _recordHistory(
      'Deleted product $productId',
      HistoryKind.bar,
      HistoryActionType.delete,
      meta: {'productId': productId},
    );
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
    final actor = _currentStateStaffMember();
    if (!_canAssignRole(actor, role)) {
      return 'Insufficient permissions to create this role';
    }
    final result = _controller.createStaffAccount(
      login,
      displayName,
      role,
      password,
    );
    if (result == null) {
      notifyListeners();
    }
    return result;
  }

  String? updateStaffAccount(
    String staffId, {
    String? displayName,
    StaffRole? role,
    String? password,
  }) {
    final actor = _currentStateStaffMember();
    final target = _staffById(staffId);
    if (actor == null || target == null) {
      return 'Staff account not found';
    }
    if (!_canManageStaff(actor, target)) {
      return 'You cannot modify this account';
    }
    if (role != null && !_canAssignRole(actor, role, target: target)) {
      return 'You cannot assign this role';
    }
    final result = _controller.updateStaffAccount(
      staffId,
      displayName: displayName,
      role: role,
      password: password,
    );
    if (result == null) {
      notifyListeners();
    }
    return result;
  }

  String? deleteStaffAccount(String staffId) {
    final actor = _currentStateStaffMember();
    final target = _staffById(staffId);
    if (actor == null || target == null) {
      return 'Staff account not found';
    }
    if (!_canDeleteStaff(actor, target)) {
      return 'You cannot delete this account';
    }
    final result = _controller.deleteStaffAccount(staffId);
    if (result == null) {
      notifyListeners();
    }
    return result;
  }

  StaffMember? _currentStateStaffMember() {
    final id = _state.activeStaffId;
    if (id == null) return null;
    for (final staff in _state.staff) {
      if (staff.id == id) {
        return staff;
      }
    }
    return null;
  }

  StaffMember? _staffById(String staffId) {
    for (final staff in _state.staff) {
      if (staff.id == staffId) {
        return staff;
      }
    }
    return null;
  }

  InventoryItem? _inventoryByProduct(String productId) {
    for (final item in _state.inventory) {
      if (item.product.id == productId) {
        return item;
      }
    }
    return null;
  }

  OrderItem? _orderByProduct(String productId) {
    for (final order in _state.orders) {
      if (order.product.id == productId) {
        return order;
      }
    }
    return null;
  }

  void _syncInventoryItem(String productId) {
    final companyId = _state.activeCompanyId;
    if (companyId == null) return;
    final item = _inventoryByProduct(productId);
    if (item == null) return;
    _remoteRepository.upsertInventoryItem(companyId, item);
  }

  void _syncOrder(String productId) {
    final companyId = _state.activeCompanyId;
    if (companyId == null) return;
    final order = _orderByProduct(productId);
    if (order == null) return;
    _remoteRepository.upsertOrder(companyId, order);
  }

  void _syncGroups() {
    final companyId = _state.activeCompanyId;
    if (companyId == null) return;
    for (final group in _state.groups) {
      _remoteRepository.upsertGroup(companyId, group);
    }
  }

  void _syncProducts() {
    final companyId = _state.activeCompanyId;
    if (companyId == null) return;
    final products = _state.inventory.map((inv) => inv.product).toList();
    _remoteRepository.upsertProductsBatch(companyId, products);
  }

  void _recordHistory(
    String action,
    HistoryKind kind,
    HistoryActionType actionType, {
    Map<String, dynamic>? meta,
  }) {
    final companyId = _state.activeCompanyId;
    if (companyId == null) return;
    final actor = _currentCompanyMember;
    final entry = HistoryEntry(
      timestamp: DateTime.now(),
      action: action,
      kind: kind,
      actionType: actionType,
      actorId: actor?.memberId ?? _currentUserId ?? 'system',
      actorName: actor?.displayName ?? 'System',
      companyId: companyId,
      meta: meta,
    );
    _state.history.add(entry);
    if (_state.history.length > 500) {
      _state.history.removeAt(0);
    }
    _remoteRepository.addHistoryEntry(companyId, entry);
  }

  static const Set<HistoryKind> _undoableKinds = {
    HistoryKind.bar,
    HistoryKind.restock,
    HistoryKind.warehouse,
    HistoryKind.order,
  };

  static const Set<HistoryActionType> _undoableActions = {
    HistoryActionType.create,
    HistoryActionType.update,
  };

  bool _canAssignRole(
    StaffMember? actor,
    StaffRole role, {
    StaffMember? target,
  }) {
    if (actor == null) return false;
    switch (actor.role) {
      case StaffRole.admin:
        return true;
      case StaffRole.owner:
        if (target != null &&
            target.id == actor.id &&
            role == StaffRole.owner) {
          return true;
        }
        return role == StaffRole.manager || role == StaffRole.worker;
      case StaffRole.manager:
        if (target != null && target.id == actor.id) {
          return role == StaffRole.manager;
        }
        return role == StaffRole.worker;
      case StaffRole.worker:
        return false;
    }
  }

  bool _canManageStaff(StaffMember actor, StaffMember target) {
    if (actor.id == target.id) return true;
    switch (actor.role) {
      case StaffRole.admin:
        return true;
      case StaffRole.owner:
        if (target.role == StaffRole.admin) return false;
        if (target.role == StaffRole.owner) return false;
        return true;
      case StaffRole.manager:
        return target.role == StaffRole.worker;
      case StaffRole.worker:
        return false;
    }
  }

  bool _canDeleteStaff(StaffMember actor, StaffMember target) {
    if (actor.id == target.id) return false;
    return _canManageStaff(actor, target);
  }
}
