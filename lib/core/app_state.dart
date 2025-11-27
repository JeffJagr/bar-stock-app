import 'models/inventory_item.dart';
import 'models/group.dart';
import 'models/restock_item.dart';
import 'models/order_item.dart';
import 'models/history_entry.dart';
import 'models/product.dart';
import 'models/staff_member.dart';
import 'security/security_config.dart';

/// Firestore sync plan (MVP)
///
/// To keep cloud storage simple, we'll mirror the existing AppStorage snapshot
/// and store a single `AppState.toJson()` blob per bar/venue. Structure:
///
/// Collection: `bars`
///   Document ID: bar identifier such as `default_bar` or the owner/staff UID.
///   Fields:
///     - `state`: `Map<String, dynamic>` produced by [AppState.toJson].
///     - optional metadata (e.g. `updatedAt`, `schemaVersion`) if needed later.
///
/// This lets us write/read one document:
///   `FirebaseFirestore.instance.collection('bars').doc(barId).set({
///       'state': appState.toJson(),
///       'updatedAt': FieldValue.serverTimestamp(),
///     })`
///
/// Once we need finer-grained sync, we can normalize into subcollections
/// (inventory, orders, history) but this snapshot model matches the current
/// local persistence and minimizes Firestore reads/writes for the MVP.
class AppState {
  List<InventoryItem> inventory;
  List<Group> groups;
  List<RestockItem> restock;
  List<OrderItem> orders;
  List<HistoryEntry> history;
  List<StaffMember> staff;
  String? activeStaffId;

  AppState({
    required this.inventory,
    required this.groups,
    required this.restock,
    required this.orders,
    required this.history,
    required this.staff,
    required this.activeStaffId,
  });

  /// Initial demo data
  factory AppState.initial() {
    // simple demo products
    final gin = Product(id: 'gin', name: 'Gin', isAlcohol: true);
    final tonic = Product(id: 'tonic', name: 'Tonic Water', isAlcohol: false);
    final redWine = Product(id: 'red_wine', name: 'Red Wine', isAlcohol: true);
    final beer = Product(id: 'beer', name: 'Lager Beer', isAlcohol: true);

    final groups = <Group>[
      Group(name: 'Cocktails', sortIndex: 0),
      Group(name: 'Wine', sortIndex: 1),
      Group(name: 'Beer & Soft', sortIndex: 2),
    ];

    final inventory = <InventoryItem>[
      InventoryItem(
        product: gin,
        groupName: 'Cocktails',
        sortIndex: 0,
        maxQty: 4,
        approxQty: 3.0,
        warehouseQty: 8,
        level: Level.green,
      ),
      InventoryItem(
        product: tonic,
        groupName: 'Cocktails',
        sortIndex: 1,
        maxQty: 20,
        approxQty: 10.0,
        warehouseQty: 30,
        level: Level.yellow,
      ),
      InventoryItem(
        product: redWine,
        groupName: 'Wine',
        sortIndex: 0,
        maxQty: 10,
        approxQty: 5.0,
        warehouseQty: 15,
        level: Level.yellow,
      ),
      InventoryItem(
        product: beer,
        groupName: 'Beer & Soft',
        sortIndex: 0,
        maxQty: 24,
        approxQty: 8.0,
        warehouseQty: 48,
        level: Level.red,
      ),
    ];

    return AppState(
      inventory: inventory,
      groups: groups,
      restock: <RestockItem>[],
      orders: <OrderItem>[],
      history: <HistoryEntry>[],
      staff: <StaffMember>[_defaultAdmin()],
      activeStaffId: null,
    );
  }

  /// Deep copy of whole state for Undo
  AppState copy() {
    return AppState(
      inventory: inventory.map((i) => i.copy()).toList(),
      groups: groups.map((g) => g.copy()).toList(),
      restock: restock.map((r) => r.copy()).toList(),
      orders: orders.map((o) => o.copy()).toList(),
      history: history.map((h) => h.copy()).toList(),
      staff: staff.map((s) => s.copy()).toList(),
      activeStaffId: activeStaffId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inventory': inventory.map((i) => i.toJson()).toList(),
      'groups': groups.map((g) => g.toJson()).toList(),
      'restock': restock.map((r) => r.toJson()).toList(),
      'orders': orders.map((o) => o.toJson()).toList(),
      'history': history.map((h) => h.toJson()).toList(),
      'staff': staff.map((s) => s.toJson()).toList(),
      'activeStaffId': activeStaffId,
    };
  }

  factory AppState.fromJson(Map<String, dynamic> json) {
    try {
      var staffList = (json['staff'] as List<dynamic>? ?? [])
          .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!staffList.any((member) => member.role == StaffRole.admin)) {
        staffList = List<StaffMember>.from(staffList)..add(_defaultAdmin());
      }
      final activeId = json['activeStaffId'] as String?;
      final hasActive =
          staffList.any((staff) => staff.id == activeId);

      return AppState(
        inventory: (json['inventory'] as List<dynamic>? ?? [])
            .map((e) => InventoryItem.fromJson(
                  e as Map<String, dynamic>,
                ))
            .toList(),
        groups: (json['groups'] as List<dynamic>? ?? [])
            .map((e) => Group.fromJson(e as Map<String, dynamic>))
            .toList(),
        restock: (json['restock'] as List<dynamic>? ?? [])
            .map((e) => RestockItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        orders: (json['orders'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        staff: staffList,
        activeStaffId: hasActive ? activeId : null,
      );
    } catch (_) {
      return AppState.initial();
    }
  }

  static StaffMember _defaultAdmin() {
    return StaffMember.create(
      login: 'admin',
      displayName: 'Admin',
      role: StaffRole.admin,
      password: defaultAdminPin,
    );
  }
}
