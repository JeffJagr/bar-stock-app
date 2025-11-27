import 'product.dart';

/// Level of bar fill
enum Level { green, yellow, red }

class InventoryItem {
  final Product product;
  final String? companyId;

  /// Group name (e.g. "Wine", "Cocktails", "Beer fridge")
  String groupName;

  /// Sort order inside group
  int sortIndex;

  /// Max quantity that fits in bar (bottles, cans, etc.)
  int maxQty;

  /// Approximate quantity currently in bar (can be fractional)
  double approxQty;

  /// Quantity on warehouse (integer)
  int warehouseQty;

  /// Visual level indicator
  Level level;

  /// Whether warehouse tracking is enabled for this item
  bool trackWarehouseLevel;

  InventoryItem({
    required this.product,
    this.companyId,
    required this.groupName,
    required this.sortIndex,
    required this.maxQty,
    required this.approxQty,
    required this.warehouseQty,
    required this.level,
    this.trackWarehouseLevel = true,
  });

  InventoryItem copy() {
    return InventoryItem(
      product: product.copy(),
      companyId: companyId,
      groupName: groupName,
      sortIndex: sortIndex,
      maxQty: maxQty,
      approxQty: approxQty,
      warehouseQty: warehouseQty,
      level: level,
      trackWarehouseLevel: trackWarehouseLevel,
    );
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      companyId: json['companyId'] as String?,
      groupName: json['groupName'] as String? ?? '',
      sortIndex: json['sortIndex'] as int? ?? 0,
      maxQty: json['maxQty'] as int? ?? 0,
      approxQty: (json['approxQty'] as num?)?.toDouble() ?? 0.0,
      warehouseQty: json['warehouseQty'] as int? ?? 0,
      level: Level.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => Level.red,
      ),
      trackWarehouseLevel: json['trackWarehouseLevel'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      if (companyId != null) 'companyId': companyId,
      'groupName': groupName,
      'sortIndex': sortIndex,
      'maxQty': maxQty,
      'approxQty': approxQty,
      'warehouseQty': warehouseQty,
      'level': level.name,
      'trackWarehouseLevel': trackWarehouseLevel,
    };
  }
}
