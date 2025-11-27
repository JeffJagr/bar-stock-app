import 'product.dart';

/// Status of supplier order
enum OrderStatus {
  pending,    // we plan / waiting approval
  confirmed,  // sent to supplier / approved
  delivered,  // delivered to venue
}

class OrderItem {
  final Product product;
  final String? companyId;
  int quantity;
  OrderStatus status;

  OrderItem({
    required this.product,
    this.companyId,
    required this.quantity,
    required this.status,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      companyId: json['companyId'] as String?,
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
      companyId: companyId,
      quantity: quantity,
      status: status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      if (companyId != null) 'companyId': companyId,
      'quantity': quantity,
      'status': status.name,
    };
  }
}
