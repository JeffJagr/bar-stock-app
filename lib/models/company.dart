import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a tenant/company/bar entity containing all scoped data.
class Company {
  final String companyId;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String joinCode;
  final String businessId;

  const Company({
    required this.companyId,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.joinCode,
    required this.businessId,
  });

  Company copyWith({
    String? companyId,
    String? name,
    String? ownerUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? joinCode,
    String? businessId,
  }) {
    return Company(
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      joinCode: joinCode ?? this.joinCode,
      businessId: businessId ?? this.businessId,
    );
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    final dynamic created = json['createdAt'];
    DateTime createdAt = DateTime.now();
    final dynamic updated = json['updatedAt'];
    DateTime updatedAt = createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is String) {
      createdAt = DateTime.tryParse(created) ?? DateTime.now();
    } else if (created is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(created);
    }
    if (updated is Timestamp) {
      updatedAt = updated.toDate();
    } else if (updated is String) {
      updatedAt = DateTime.tryParse(updated) ?? createdAt;
    } else if (updated is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(updated);
    }
    return Company(
      companyId: json['companyId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ownerUserId: json['ownerUserId'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      joinCode: json['joinCode'] as String? ?? '',
      businessId: (json['businessId'] as String? ??
              json['companyCode'] as String? ??
              '')
          .toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'name': name,
      'ownerUserId': ownerUserId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'joinCode': joinCode,
      'businessId': businessId,
    };
  }
}
