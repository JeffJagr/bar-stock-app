import 'package:cloud_firestore/cloud_firestore.dart';

import 'product.dart';

/// Status of supplier order
enum OrderStatus {
  pending, // we plan / waiting approval
  confirmed, // sent to supplier / approved
  delivered, // delivered to venue
}

class OrderItem {
  final Product product;
  final String? companyId;
  int quantity;
  OrderStatus status;
  final DateTime createdAt;
  final String? performerId;
  final String? performerName;
  final double? total;

  OrderItem({
    required this.product,
    this.companyId,
    required this.quantity,
    required this.status,
    DateTime? createdAt,
    this.performerId,
    this.performerName,
    this.total,
  }) : createdAt = createdAt ?? DateTime.now();

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      companyId: json['companyId'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      createdAt: _parseDate(json['createdAt']),
      performerId: json['performerId'] as String?,
      performerName: json['performerName'] as String?,
      total: (json['total'] as num?)?.toDouble(),
    );
  }

  OrderItem copy() {
    return OrderItem(
      product: product.copy(),
      companyId: companyId,
      quantity: quantity,
      status: status,
      createdAt: createdAt,
      performerId: performerId,
      performerName: performerName,
      total: total,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      if (companyId != null) 'companyId': companyId,
      'quantity': quantity,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      if (performerId != null) 'performerId': performerId,
      if (performerName != null) 'performerName': performerName,
      if (total != null) 'total': total,
    };
  }
}

DateTime _parseDate(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
  if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  if (raw is Timestamp) return raw.toDate();
  try {
    final result = raw?.toDate();
    if (result is DateTime) return result;
  } catch (_) {}
  return DateTime.now();
}
