import '../core/app_state.dart';
import '../core/models/group.dart';
import '../core/models/history_entry.dart';
import '../core/models/inventory_item.dart';
import '../core/models/order_item.dart';
import '../core/models/product.dart';
import '../core/models/staff_member.dart';

/// Defines contract for cloud-backed data sources used for syncing.
abstract class RemoteRepository {
  Future<AppState> fetchFullStateForCompany(String companyId);
  Future<AppState> syncFromCloud(String ownerId);
  Future<void> syncToCloud(String ownerId, AppState state);

  // Product CRUD
  Future<List<Product>> listProducts(String ownerId);
  Future<Product?> fetchProduct(String ownerId, String productId);
  Future<void> upsertProduct(String ownerId, Product product);
  Future<void> deleteProduct(String ownerId, String productId);
  Future<void> upsertProductsBatch(String ownerId, List<Product> products);

  // Group CRUD
  Future<List<Group>> listGroups(String ownerId);
  Future<void> upsertGroup(String ownerId, Group group);
  Future<void> deleteGroup(String ownerId, String groupName);

  // Inventory CRUD
  Future<List<InventoryItem>> listInventory(String ownerId);
  Future<void> upsertInventoryItem(String ownerId, InventoryItem item);
  Future<void> upsertInventoryBatch(String ownerId, List<InventoryItem> items);
  Future<void> deleteInventoryItem(String ownerId, String itemId);

  // Order CRUD
  Future<List<OrderItem>> listOrders(String ownerId);
  Future<void> upsertOrder(String ownerId, OrderItem order);
  Future<String> createOrder(String ownerId, OrderItem order);
  Future<void> updateOrderStatus(
    String ownerId,
    String orderId,
    OrderStatus status,
  );
  Future<void> deleteOrder(String ownerId, String orderId);

  // History CRUD
  Future<List<HistoryEntry>> listHistory(String ownerId);
  Future<void> addHistoryEntry(String ownerId, HistoryEntry entry);
  Future<void> deleteHistoryEntry(String ownerId, String entryId);

  // Staff
  Future<List<StaffMember>> listStaff(String ownerId);

  // Live streams
  Stream<List<InventoryItem>> streamInventory(String ownerId);
  Stream<List<OrderItem>> streamOrders(String ownerId);
  Stream<List<HistoryEntry>> streamHistory(String ownerId);
  Stream<List<OrderItem>> streamOrderHistory(String ownerId);

  // Writes
  Future<void> saveInventoryItem(String ownerId, InventoryItem item);
  Future<void> saveInventoryBatch(String ownerId, List<InventoryItem> items);
  Future<void> appendHistoryEntry(String ownerId, HistoryEntry entry);
}
