import 'package:flutter/foundation.dart';

import '../data/firebase_remote_repository.dart';
import '../data/remote_repository.dart' as cloud;
import 'app_controller.dart';
import 'app_state.dart';
import 'error_reporter.dart';
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

  AppState get state => _state;
  AppController get controller => _controller;
  String? get currentUserId => _currentUserId;
  String? get activeCompanyId => _state.activeCompanyId;

  void replaceState(AppState newState) {
    _state = newState;
    _controller.state = newState;
    notifyListeners();
  }

  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
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
    final actor = _currentStaffMember();
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
    final actor = _currentStaffMember();
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
    final actor = _currentStaffMember();
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

  StaffMember? _currentStaffMember() {
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
