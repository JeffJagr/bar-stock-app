import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_state.dart';
import '../core/models/group.dart';
import '../core/models/history_entry.dart';
import '../core/models/inventory_item.dart';
import '../core/models/order_item.dart';
import '../core/models/product.dart';
import '../core/models/restock_item.dart';
import '../core/models/staff_member.dart';
import '../core/remote/backend_config.dart';
import 'firebase_service.dart';
import 'remote_repository.dart';

/// Firestore-backed implementation of [RemoteRepository] (read-only for now).
class FirebaseRemoteRepository implements RemoteRepository {
  FirebaseRemoteRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance;

  final FirebaseService _service;

  FirebaseFirestore get _firestore => _service.firestore;

  CollectionReference<Map<String, dynamic>> _ownerCollection(
    String ownerId,
    String child,
  ) {
    return _firestore
        .collection(BackendConfig.barsCollection)
        .doc(ownerId)
        .collection(child);
  }

  @override
  Future<AppState> syncFromCloud(String ownerId) async {
    final groups = await listGroups(ownerId);
    final inventory = await listInventory(ownerId);
    final orders = await listOrders(ownerId);
    final history = await listHistory(ownerId);

    return AppState(
      inventory: inventory,
      groups: groups,
      restock: <RestockItem>[],
      orders: orders,
      history: history,
      staff: <StaffMember>[],
      activeStaffId: null,
    );
  }

  @override
  Future<void> syncToCloud(String ownerId, AppState state) async {
    await _syncCollection(
      ownerId: ownerId,
      path: 'products',
      items: state.inventory.map((item) => item.product),
      toJson: (Product product) => product.toJson(),
      idFor: (Product product) => product.id,
    );
    await _syncCollection(
      ownerId: ownerId,
      path: 'groups',
      items: state.groups,
      toJson: (Group group) => group.toJson(),
      idFor: (Group group) => group.name,
    );
    await _syncCollection(
      ownerId: ownerId,
      path: 'inventory',
      items: state.inventory,
      toJson: (InventoryItem item) => item.toJson(),
      idFor: (InventoryItem item) => item.product.id,
    );
    await _syncCollection(
      ownerId: ownerId,
      path: 'orders',
      items: state.orders,
      toJson: (OrderItem order) => order.toJson(),
      idFor: (OrderItem order) => order.product.id,
    );
    await _syncHistory(ownerId, state.history);
  }

  Future<void> _syncCollection<T>({
    required String ownerId,
    required String path,
    required Iterable<T> items,
    required Map<String, dynamic> Function(T item) toJson,
    required String Function(T item) idFor,
  }) async {
    final batch = _firestore.batch();
    final coll = _ownerCollection(ownerId, path);
    for (final item in items) {
      final doc = coll.doc(idFor(item));
      batch.set(doc, toJson(item), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _syncHistory(
    String ownerId,
    List<HistoryEntry> entries,
  ) async {
    final coll = _ownerCollection(ownerId, 'history');
    final batch = _firestore.batch();
    for (final entry in entries) {
      final doc = coll.doc(entry.timestamp.millisecondsSinceEpoch.toString());
      batch.set(doc, entry.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<List<Product>> listProducts(String ownerId) async {
    final snapshot =
        await _ownerCollection(ownerId, 'products').get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final enriched = {
            ...data,
            'id': data['id'] ?? doc.id,
          };
          return Product.fromJson(enriched);
        })
        .toList();
  }

  @override
  Future<Product?> fetchProduct(String ownerId, String productId) async {
    final doc =
        await _ownerCollection(ownerId, 'products').doc(productId).get();
    final data = doc.data();
    if (data == null) return null;
    final enriched = {
      ...data,
      'id': data['id'] ?? doc.id,
    };
    return Product.fromJson(enriched);
  }

  @override
  Future<void> upsertProduct(String ownerId, Product product) {
    final doc = _ownerCollection(ownerId, 'products').doc(product.id);
    return doc.set(product.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteProduct(String ownerId, String productId) {
    final doc = _ownerCollection(ownerId, 'products').doc(productId);
    return doc.delete();
  }

  @override
  Future<List<Group>> listGroups(String ownerId) async {
    final snapshot =
        await _ownerCollection(ownerId, 'groups').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final enriched = {
        ...data,
        'name': data['name'] ?? doc.id,
      };
      return Group.fromJson(enriched);
    }).toList();
  }

  @override
  Future<void> upsertGroup(String ownerId, Group group) {
    final doc = _ownerCollection(ownerId, 'groups').doc(group.name);
    return doc.set(group.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteGroup(String ownerId, String groupName) {
    final doc = _ownerCollection(ownerId, 'groups').doc(groupName);
    return doc.delete();
  }

  @override
  Future<List<InventoryItem>> listInventory(String ownerId) async {
    final snapshot =
        await _ownerCollection(ownerId, 'inventory').get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      final product = data['product'];
      if (product is Map<String, dynamic>) {
        data['product'] = {
          ...product,
          'id': product['id'] ?? doc.id,
        };
      }
      return InventoryItem.fromJson(data);
    }).toList();
  }

  @override
  Future<void> upsertInventoryItem(String ownerId, InventoryItem item) {
    final doc = _ownerCollection(ownerId, 'inventory').doc(item.product.id);
    return doc.set(item.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteInventoryItem(String ownerId, String itemId) {
    final doc = _ownerCollection(ownerId, 'inventory').doc(itemId);
    return doc.delete();
  }

  @override
  Future<List<OrderItem>> listOrders(String ownerId) async {
    final snapshot =
        await _ownerCollection(ownerId, 'orders').get();
    return snapshot.docs
        .map((doc) => OrderItem.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> upsertOrder(String ownerId, OrderItem order) {
    final doc =
        _ownerCollection(ownerId, 'orders').doc(order.product.id);
    return doc.set(order.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteOrder(String ownerId, String orderId) {
    final doc = _ownerCollection(ownerId, 'orders').doc(orderId);
    return doc.delete();
  }

  @override
  Future<List<HistoryEntry>> listHistory(String ownerId) async {
    final snapshot =
        await _ownerCollection(ownerId, 'history').get();
    return snapshot.docs
        .map((doc) => HistoryEntry.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> addHistoryEntry(String ownerId, HistoryEntry entry) {
    final doc = _ownerCollection(ownerId, 'history').doc();
    return doc.set(entry.toJson());
  }

  @override
  Future<void> deleteHistoryEntry(String ownerId, String entryId) {
    final doc = _ownerCollection(ownerId, 'history').doc(entryId);
    return doc.delete();
  }

}
