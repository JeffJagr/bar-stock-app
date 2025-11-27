import '../core/app_state.dart';
import '../core/models/group.dart';
import '../core/models/history_entry.dart';
import '../core/models/inventory_item.dart';
import '../core/models/order_item.dart';
import '../core/models/product.dart';

/// Defines contract for cloud-backed data sources used for syncing.
abstract class RemoteRepository {
  Future<AppState> syncFromCloud(String ownerId);
  Future<void> syncToCloud(String ownerId, AppState state);

  // Product CRUD
  Future<List<Product>> listProducts(String ownerId);
  Future<Product?> fetchProduct(String ownerId, String productId);
  Future<void> upsertProduct(String ownerId, Product product);
  Future<void> deleteProduct(String ownerId, String productId);

  // Group CRUD
  Future<List<Group>> listGroups(String ownerId);
  Future<void> upsertGroup(String ownerId, Group group);
  Future<void> deleteGroup(String ownerId, String groupName);

  // Inventory CRUD
  Future<List<InventoryItem>> listInventory(String ownerId);
  Future<void> upsertInventoryItem(String ownerId, InventoryItem item);
  Future<void> deleteInventoryItem(String ownerId, String itemId);

  // Order CRUD
  Future<List<OrderItem>> listOrders(String ownerId);
  Future<void> upsertOrder(String ownerId, OrderItem order);
  Future<void> deleteOrder(String ownerId, String orderId);

  // History CRUD
  Future<List<HistoryEntry>> listHistory(String ownerId);
  Future<void> addHistoryEntry(String ownerId, HistoryEntry entry);
  Future<void> deleteHistoryEntry(String ownerId, String entryId);
}
