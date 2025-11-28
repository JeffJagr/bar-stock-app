import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_state.dart';
import '../core/error_reporter.dart';
import '../core/models/group.dart';
import '../core/models/history_entry.dart';
import '../core/models/inventory_item.dart';
import '../core/models/order_item.dart';
import '../core/models/product.dart';
import '../core/models/restock_item.dart';
import '../core/models/staff_member.dart';
import 'firebase_service.dart';
import 'remote_repository.dart';

/// Firestore-backed implementation that currently exposes READ operations only.
class FirebaseRemoteRepository implements RemoteRepository {
  FirebaseRemoteRepository({FirebaseService? service})
      : _service = service ?? FirebaseService.instance;

  final FirebaseService _service;

  @override
  Future<AppState> fetchFullStateForCompany(String companyId) async {
    final products = await listProducts(companyId);
    final productCache = {
      for (final product in products) product.id: product,
    };

    final groupsFuture = listGroups(companyId);
    final inventoryFuture =
        _fetchInventory(companyId, productCache: productCache);
    final ordersFuture =
        _fetchOrders(companyId, productCache: productCache);
    final historyFuture = listHistory(companyId);
    final staffFuture = listStaff(companyId);

    final groups = await groupsFuture;
    final inventory = await inventoryFuture;
    final orders = await ordersFuture;
    final history = await historyFuture;
    final staff = await staffFuture;

    return AppState(
      activeCompanyId: companyId,
      inventory: inventory,
      groups: groups,
      restock: <RestockItem>[],
      orders: orders,
      history: history,
      staff: staff,
      activeStaffId: null,
    );
  }

  @override
  Future<AppState> syncFromCloud(String ownerId) =>
      fetchFullStateForCompany(ownerId);

  @override
  Future<void> syncToCloud(String ownerId, AppState state) =>
      _unsupportedWrite('syncToCloud');

  @override
  Future<List<Product>> listProducts(String ownerId) async {
    try {
      final snapshot = await _service.productsCollection(ownerId).get();
      return snapshot.docs
          .map((doc) => _productFromData(doc.data(), doc.id, ownerId))
          .toList();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'Load products failed');
      return const [];
    }
  }

  @override
  Future<Product?> fetchProduct(String ownerId, String productId) async {
    try {
      final doc =
          await _service.productsCollection(ownerId).doc(productId).get();
      final data = doc.data();
      if (data == null) return null;
      return _productFromData(data, doc.id, ownerId);
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'Fetch product failed');
      return null;
    }
  }

  @override
  Future<void> upsertProduct(String ownerId, Product product) async {
    try {
      final payload = {
        ...product.toJson(),
        'companyId': product.companyId ?? ownerId,
      };
      await _service
          .productsCollection(ownerId)
          .doc(product.id)
          .set(payload, SetOptions(merge: true));
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'upsertProduct failed');
    }
  }

  @override
  Future<void> upsertProductsBatch(
    String ownerId,
    List<Product> products,
  ) async {
    if (products.isEmpty) return;
    try {
      final batch = _service.firestore.batch();
      for (final product in products) {
        final payload = {
          ...product.toJson(),
          'companyId': product.companyId ?? ownerId,
        };
        batch.set(
          _service.productsCollection(ownerId).doc(product.id),
          payload,
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'upsertProductsBatch failed',
      );
    }
  }

  @override
  Future<void> deleteProduct(String ownerId, String productId) async {
    try {
      await _service.productsCollection(ownerId).doc(productId).delete();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'deleteProduct failed');
    }
  }

  @override
  Future<List<Group>> listGroups(String ownerId) async {
    try {
      final snapshot = await _service.groupsCollection(ownerId).get();
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['name'] = data['name'] ?? doc.id;
        data['companyId'] = data['companyId'] ?? ownerId;
        return Group.fromJson(data);
      }).toList();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'Load groups failed');
      return const [];
    }
  }

  @override
  Future<void> upsertGroup(String ownerId, Group group) async {
    try {
      final payload = {
        ...group.toJson(),
        'companyId': group.companyId ?? ownerId,
      };
      await _service
          .groupsCollection(ownerId)
          .doc(group.name)
          .set(payload, SetOptions(merge: true));
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'upsertGroup failed');
    }
  }

  @override
  Future<void> deleteGroup(String ownerId, String groupName) async {
    try {
      await _service.groupsCollection(ownerId).doc(groupName).delete();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'deleteGroup failed');
    }
  }

  @override
  Future<List<InventoryItem>> listInventory(String ownerId) =>
      _fetchInventory(ownerId);

  Future<List<InventoryItem>> _fetchInventory(
    String companyId, {
    Map<String, Product>? productCache,
  }) async {
    try {
      final snapshot = await _service.inventoryCollection(companyId).get();
      return snapshot.docs
          .map(
            (doc) => _decodeInventory(
              doc,
              companyId: companyId,
              productCache: productCache,
            ),
          )
          .toList();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'Load inventory failed');
      return const [];
    }
  }

  @override
  Future<void> upsertInventoryItem(String ownerId, InventoryItem item) async {
    try {
      final payload = {
        ...item.toJson(),
        'companyId': item.companyId ?? ownerId,
      };
      await _service
          .inventoryCollection(ownerId)
          .doc(item.product.id)
          .set(payload, SetOptions(merge: true));
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'upsertInventoryItem failed',
      );
    }
  }

  @override
  Future<void> upsertInventoryBatch(
    String ownerId,
    List<InventoryItem> items,
  ) async {
    if (items.isEmpty) return;
    try {
      final batch = _service.firestore.batch();
      for (final item in items) {
        final payload = {
          ...item.toJson(),
          'companyId': item.companyId ?? ownerId,
        };
        batch.set(
          _service.inventoryCollection(ownerId).doc(item.product.id),
          payload,
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'upsertInventoryBatch failed',
      );
    }
  }

  @override
  Future<void> deleteInventoryItem(String ownerId, String itemId) async {
    try {
      await _service.inventoryCollection(ownerId).doc(itemId).delete();
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'deleteInventoryItem failed',
      );
    }
  }

  @override
  Future<List<OrderItem>> listOrders(String ownerId) =>
      _fetchOrders(ownerId);

  Future<List<OrderItem>> _fetchOrders(
    String companyId, {
    Map<String, Product>? productCache,
  }) async {
    try {
      final snapshot = await _service.ordersCollection(companyId).get();
      return snapshot.docs
          .map(
            (doc) => _decodeOrder(
              doc,
              companyId: companyId,
              productCache: productCache,
            ),
          )
          .toList();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'Load orders failed');
      return const [];
    }
  }

  @override
  Future<void> upsertOrder(String ownerId, OrderItem order) async {
    try {
      final payload = {
        ...order.toJson(),
        'companyId': order.companyId ?? ownerId,
      };
      await _service
          .ordersCollection(ownerId)
          .doc(order.product.id)
          .set(payload, SetOptions(merge: true));
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'upsertOrder failed');
    }
  }

  @override
  Future<String> createOrder(String ownerId, OrderItem order) async {
    try {
      await upsertOrder(ownerId, order);
      return order.product.id;
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'createOrder failed');
      rethrow;
    }
  }

  @override
  Future<void> updateOrderStatus(
    String ownerId,
    String orderId,
    OrderStatus status,
  ) async {
    try {
      await _service.ordersCollection(ownerId).doc(orderId).set(
            {'status': status.name},
            SetOptions(merge: true),
          );
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'updateOrderStatus failed',
      );
    }
  }

  @override
  Future<void> deleteOrder(String ownerId, String orderId) async {
    try {
      await _service.ordersCollection(ownerId).doc(orderId).delete();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'deleteOrder failed');
    }
  }

  @override
  Future<List<HistoryEntry>> listHistory(String ownerId) async {
    try {
      final snapshot = await _service.historyCollection(ownerId).get();
      return snapshot.docs.map((doc) {
        final data = _normalizeTimestampField(
          Map<String, dynamic>.from(doc.data()),
          'timestamp',
        );
        data['companyId'] = data['companyId'] ?? ownerId;
        return HistoryEntry.fromJson(data);
      }).toList();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'Load history failed');
      return const [];
    }
  }

  @override
  Future<void> addHistoryEntry(String ownerId, HistoryEntry entry) async {
    try {
      await _service.historyCollection(ownerId).add(entry.toJson());
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'addHistoryEntry failed');
    }
  }

  @override
  Future<void> deleteHistoryEntry(String ownerId, String entryId) async {
    try {
      await _service.historyCollection(ownerId).doc(entryId).delete();
    } catch (err, stack) {
      ErrorReporter.logException(
        err,
        stack,
        reason: 'deleteHistoryEntry failed',
      );
    }
  }

  @override
  Future<List<StaffMember>> listStaff(String ownerId) async {
    try {
      final snapshot = await _service.staffCollection(ownerId).get();
      return snapshot.docs.map((doc) {
        final data = _normalizeTimestampField(
          Map<String, dynamic>.from(doc.data()),
          'createdAt',
        );
        data['id'] = data['id'] ?? doc.id;
        data['companyId'] = data['companyId'] ?? ownerId;
        return StaffMember.fromJson(data);
      }).toList();
    } catch (err, stack) {
      ErrorReporter.logException(err, stack, reason: 'Load staff failed');
      return const [];
    }
  }

  Product _productFromData(
    Map<String, dynamic> data,
    String fallbackId,
    String companyId,
  ) {
    return Product.fromJson({
      ...data,
      'id': data['id'] ?? fallbackId,
      'companyId': data['companyId'] ?? companyId,
    });
  }

  InventoryItem _decodeInventory(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String companyId,
    Map<String, Product>? productCache,
  }) {
    final data = Map<String, dynamic>.from(doc.data());
    data['product'] = _resolveProductData(
      data,
      doc.id,
      companyId: companyId,
      productCache: productCache,
    );
    data['companyId'] = data['companyId'] ?? companyId;
    return InventoryItem.fromJson(data);
  }

  OrderItem _decodeOrder(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String companyId,
    Map<String, Product>? productCache,
  }) {
    final data = Map<String, dynamic>.from(doc.data());
    data['product'] = _resolveProductData(
      data,
      doc.id,
      companyId: companyId,
      productCache: productCache,
    );
    data['companyId'] = data['companyId'] ?? companyId;
    return OrderItem.fromJson(data);
  }

  Map<String, dynamic> _resolveProductData(
    Map<String, dynamic> container,
    String fallbackId, {
    String? companyId,
    Map<String, Product>? productCache,
  }) {
    final rawProduct = container['product'];
    if (rawProduct is Map<String, dynamic>) {
      return {
        ...rawProduct,
        'id': rawProduct['id'] ?? fallbackId,
        'companyId': rawProduct['companyId'] ?? companyId,
      };
    }

    final productId = rawProduct is String
        ? rawProduct
        : container['productId'] as String? ?? fallbackId;
    final cached = productCache?[productId];
    if (cached != null) {
      final cachedJson = cached.toJson();
      return {
        ...cachedJson,
        'companyId': cachedJson['companyId'] ?? companyId,
      };
    }

    return {
      'id': productId,
      'name': container['productName'] as String? ?? productId,
      'isAlcohol': container['isAlcohol'] as bool? ?? true,
      if (companyId != null) 'companyId': companyId,
    };
  }

  Map<String, dynamic> _normalizeTimestampField(
    Map<String, dynamic> data,
    String field,
  ) {
    final value = data[field];
    if (value is Timestamp) {
      data[field] = value.toDate().toIso8601String();
    } else if (value is DateTime) {
      data[field] = value.toIso8601String();
    } else if (value is num) {
      data[field] =
          DateTime.fromMillisecondsSinceEpoch(value.toInt()).toIso8601String();
    }
    return data;
  }

  Future<void> _unsupportedWrite(String operation) async {
    // Writes will be added in Phase D (Steps 11+). For now this is a no-op.
  }
}
