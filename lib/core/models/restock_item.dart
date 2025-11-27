import 'product.dart';

class RestockItem {
  final Product product;

  /// How much approximately we need to bring to bar
  double approxNeed;

  /// Approximate current quantity in bar at the moment of planning restock
  double approxCurrent;

  RestockItem({
    required this.product,
    required this.approxNeed,
    required this.approxCurrent,
  });

  factory RestockItem.fromJson(Map<String, dynamic> json) {
    return RestockItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      approxNeed: (json['approxNeed'] as num?)?.toDouble() ?? 0.0,
      approxCurrent: (json['approxCurrent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  RestockItem copy() {
    return RestockItem(
      product: product.copy(),
      approxNeed: approxNeed,
      approxCurrent: approxCurrent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'approxNeed': approxNeed,
      'approxCurrent': approxCurrent,
    };
  }
}
