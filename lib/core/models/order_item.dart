import 'product.dart';

/// Status of supplier order
enum OrderStatus {
  pending,    // we plan / waiting approval
  confirmed,  // sent to supplier / approved
  delivered,  // delivered to venue
}

class OrderItem {
  final Product product;
  int quantity;
  OrderStatus status;

  OrderItem({
    required this.product,
    required this.quantity,
    required this.status,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 0,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.pending,
      ),
    );
  }

  OrderItem copy() {
    return OrderItem(
      product: product.copy(),
      quantity: quantity,
      status: status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'status': status.name,
    };
  }
}
